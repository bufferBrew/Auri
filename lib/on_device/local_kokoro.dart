import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../features/read_aloud/domain/text_chunk.dart';

/// Kokoro-82M running on the phone, through sherpa-onnx.
///
/// Two builds of Kokoro v1.0, with the same 54 voices as a Kokoro-FastAPI
/// server ([LocalModel]). Synthesis runs in its own isolate, because one call
/// blocks for as long as the audio takes to make.
///
/// Words missing from the lexicon (names, numbers, rare spellings) go through
/// espeak-ng in `dataDir`. That is why this pins sherpa-onnx 1.13.8: 2.0
/// ignores `dataDir` and skips such words silently.
///
/// Measured on an Apple M1 Pro CPU with sherpa-onnx 2.0.1, 7.2 s of speech
/// took 1.6 s with the full model and 6.1 s with the int8 one (6 threads):
/// int8 is smaller but much slower on ARM, so the full model is the default.

/// The models Voxen can download. Nothing downloads until the user asks.
enum LocalModel {
  full(
    label: 'Kokoro · full quality',
    detail: 'Best voice, and the fastest on recent phones.',
    folder: 'kokoro-multi-lang-v1_0',
    modelFile: 'model.onnx',
    downloadMb: 333,
    diskMb: 395,
  ),
  compact(
    label: 'Kokoro · compact',
    detail: 'A third of the size, about four times slower to speak.',
    folder: 'kokoro-int8-multi-lang-v1_0',
    modelFile: 'model.int8.onnx',
    downloadMb: 126,
    diskMb: 186,
  );

  const LocalModel({
    required this.label,
    required this.detail,
    required this.folder,
    required this.modelFile,
    required this.downloadMb,
    required this.diskMb,
  });

  final String label;
  final String detail;
  final String folder;
  final String modelFile;
  final int downloadMb;
  final int diskMb;

  /// sherpa-onnx's release of the model, as `<folder>.tar.bz2`.
  Uri get url => Uri.parse(
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$folder.tar.bz2',
  );

  /// The files the engine needs, relative to the model folder.
  List<String> get requiredFiles => [
    modelFile,
    'voices.bin',
    'tokens.txt',
    'lexicon-us-en.txt',
    'lexicon-zh.txt',
    'espeak-ng-data/phontab',
  ];
}

/// Speaker names in speaker-id order, read from the model's own metadata
/// (`speaker_names`). `af_heart` is 3.
const localKokoroVoices = <String>[
  'af_alloy', 'af_aoede', 'af_bella', 'af_heart', 'af_jessica', 'af_kore', //
  'af_nicole', 'af_nova', 'af_river', 'af_sarah', 'af_sky', 'am_adam',
  'am_echo', 'am_eric', 'am_fenrir', 'am_liam', 'am_michael', 'am_onyx',
  'am_puck', 'am_santa', 'bf_alice', 'bf_emma', 'bf_isabella', 'bf_lily',
  'bm_daniel', 'bm_fable', 'bm_george', 'bm_lewis', 'ef_dora', 'em_alex',
  'ff_siwis', 'hf_alpha', 'hf_beta', 'hm_omega', 'hm_psi', 'if_sara',
  'im_nicola', 'jf_alpha', 'jf_gongitsune', 'jf_nezumi', 'jf_tebukuro',
  'jm_kumo', 'pf_dora', 'pm_alex', 'pm_santa', 'zf_xiaobei', 'zf_xiaoni',
  'zf_xiaoxiao', 'zf_xiaoyi', 'zm_yunjian', 'zm_yunxi', 'zm_yunxia',
  'zm_yunyang', 'em_santa',
];

/// The speaker id for [voice]; unknown voices (a Kokoro server can offer
/// mixes and newer voices) fall back to `af_heart`.
int localKokoroSpeaker(String voice) {
  final i = localKokoroVoices.indexOf(voice);
  return i < 0 ? 3 : i;
}

/// Smaller pieces than a server gets, and a shorter first one, so the first
/// audio starts within a second or two on a phone.
const localKokoroFirstChars = 160;
const localKokoroChunkChars = 400;

/// [text] in pieces for the phone: a short first one so audio starts
/// quickly, then [localKokoroChunkChars] at a time.
List<TextChunk> phoneChunks(String text) {
  final first = chunkText(text, maxChars: localKokoroFirstChars);
  if (first.isEmpty) return first;
  final head = first.first;
  return [
    head,
    for (final c in chunkText(
      text.substring(head.end),
      maxChars: localKokoroChunkChars,
    ))
      TextChunk(
        index: c.index + 1,
        start: head.end + c.start,
        end: head.end + c.end,
        text: c.text,
      ),
  ];
}

/// 16-bit mono PCM WAV from float samples in [-1, 1].
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final data = samples.length * 2;
  final out = ByteData(44 + data);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + data, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    out.setInt16(44 + i * 2, v, Endian.little);
  }
  return out.buffer.asUint8List();
}

/// Joins WAVs made by [encodeWav] with the same format into one.
Uint8List concatWav(List<Uint8List> parts) {
  if (parts.isEmpty) return Uint8List(0);
  final data = parts.fold<int>(0, (n, p) => n + p.length - 44);
  final out = Uint8List(44 + data)..setRange(0, 44, parts.first);
  final header = ByteData.sublistView(out, 0, 44)
    ..setUint32(4, 36 + data, Endian.little)
    ..setUint32(40, data, Endian.little);
  assert(header.lengthInBytes == 44);
  var at = 44;
  for (final p in parts) {
    out.setRange(at, at + p.length - 44, p, 44);
    at += p.length - 44;
  }
  return out;
}

class LocalKokoroException implements Exception {
  const LocalKokoroException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A worker isolate holding one loaded model. Requests run one at a time.
class LocalKokoroEngine {
  LocalKokoroEngine._(this._isolate, this._requests, this._replies);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final _pending = <int, Completer<Uint8List>>{};
  int _next = 0;
  bool _closed = false;

  /// Loads [model] from [modelDir]. [libraryPath] is only for tests on a
  /// desktop host; on Android the library ships inside the app.
  static Future<LocalKokoroEngine> start(
    String modelDir, {
    LocalModel model = LocalModel.full,
    int threads = 4,
    String? libraryPath,
  }) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    late final LocalKokoroEngine engine;
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is _Failed && message.id == -1) {
        if (!ready.isCompleted) {
          ready.completeError(LocalKokoroException(message.error));
        }
      } else if (message is _Failed) {
        engine._pending
            .remove(message.id)
            ?.completeError(LocalKokoroException(message.error));
      } else if (message is _Done) {
        engine._pending
            .remove(message.id)
            ?.complete(message.wav.materialize().asUint8List());
      }
    });
    final isolate = await Isolate.spawn(
      _worker,
      _Start(replies.sendPort, modelDir, model.modelFile, threads, libraryPath),
      debugName: 'kokoro',
    );
    try {
      final requests = await ready.future;
      engine = LocalKokoroEngine._(isolate, requests, replies);
      return engine;
    } catch (_) {
      isolate.kill();
      replies.close();
      rethrow;
    }
  }

  /// WAV audio for [text] in [voice] at normal speed.
  Future<Uint8List> speak(String text, {required String voice}) {
    if (_closed) {
      return Future.error(const LocalKokoroException('The engine is closed.'));
    }
    final id = _next++;
    final done = Completer<Uint8List>();
    _pending[id] = done;
    _requests.send(_Speak(id, text, localKokoroSpeaker(voice)));
    return done.future;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final p in _pending.values) {
      p.completeError(const LocalKokoroException('The engine was closed.'));
    }
    _pending.clear();
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
  }
}

class _Start {
  const _Start(
    this.reply,
    this.dir,
    this.modelFile,
    this.threads,
    this.libraryPath,
  );
  final SendPort reply;
  final String dir;
  final String modelFile;
  final int threads;
  final String? libraryPath;
}

class _Speak {
  const _Speak(this.id, this.text, this.speaker);
  final int id;
  final String text;
  final int speaker;
}

class _Done {
  const _Done(this.id, this.wav);
  final int id;
  final TransferableTypedData wav;
}

class _Failed {
  const _Failed(this.id, this.error);
  final int id;
  final String error;
}

void _worker(_Start start) {
  final sherpa.OfflineTts tts;
  try {
    sherpa.initBindings(start.libraryPath);
    final d = start.dir;
    tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          kokoro: sherpa.OfflineTtsKokoroModelConfig(
            model: '$d/${start.modelFile}',
            voices: '$d/voices.bin',
            tokens: '$d/tokens.txt',
            dataDir: '$d/espeak-ng-data',
            lexicon: '$d/lexicon-us-en.txt,$d/lexicon-zh.txt',
          ),
          numThreads: start.threads,
        ),
      ),
    );
  } catch (e) {
    start.reply.send(_Failed(-1, 'Could not load the voice model: $e'));
    return;
  }
  final requests = ReceivePort();
  start.reply.send(requests.sendPort);
  requests.listen((message) {
    if (message is! _Speak) return;
    try {
      final audio = tts.generate(text: message.text, sid: message.speaker);
      if (audio.samples.isEmpty) {
        throw const LocalKokoroException('The model made no audio.');
      }
      final wav = encodeWav(audio.samples, audio.sampleRate);
      start.reply.send(
        _Done(message.id, TransferableTypedData.fromList([wav])),
      );
    } catch (e) {
      start.reply.send(_Failed(message.id, 'Speech failed: $e'));
    }
  });
}
