import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../on_device/local_kokoro.dart';
import '../../speech_api.dart';
import '../../speech_preset.dart';
import '../../voice_settings.dart';
import 'domain/text_chunk.dart';

/// Reads text selected in another app ("Read aloud" in its selection menu)
/// without Auri's screen. It runs in a background Flutter engine that
/// `ReadAloudService.kt` starts, and talks to it over `voxen/read_aloud`.
///
/// It tries the voices in [VoiceSettings.selectionOrder] (the Kokoro server,
/// Kokoro on this phone, the device voice) and moves to the next when one
/// fails, carrying on from the piece it was on. [useDevice] switches to the
/// device voice mid-reading.
class SelectionReader {
  SelectionReader(
    this.settings, {
    required this.onSource,
    required this.onDone,
    required this.onError,
    this.firstAudioWait = const Duration(seconds: 10),
    Future<void> Function(int session, Engine engine)? speak,
  }) : _speakOverride = speak;

  final VoiceSettings settings;

  /// The voice now reading, and why it isn't the first choice (if not).
  final void Function(Engine engine, String label, String? why) onSource;
  final void Function() onDone;
  final void Function(String message) onError;

  /// How long the first Kokoro audio may take before trying the next voice.
  final Duration firstAudioWait;

  /// Replaces the real voices in tests.
  final Future<void> Function(int session, Engine engine)? _speakOverride;

  int _session = 0;
  String _text = '';

  /// Where the piece being read starts, so a switch carries on from there.
  int _at = 0;
  Engine? _engine;
  http.Client? _client;
  AudioPlayer? _player;
  FlutterTts? _tts;
  LocalKokoroEngine? _local;
  LocalModel? _localModel;

  Engine? get engine => _engine;
  int get position => _at;

  /// Reads [text] from the start, replacing anything being read.
  Future<void> read(String text) async {
    await _halt();
    final session = ++_session;
    _text = text.trim();
    _at = 0;
    if (_text.isEmpty) return onDone();
    await _run(settings.selectionOrder, session, null);
  }

  /// Carries on with the device voice from the piece being read.
  Future<void> useDevice() async {
    if (_text.isEmpty || _engine == Engine.device) return;
    await _halt();
    final session = ++_session;
    await _run(const [Engine.device], session, null);
  }

  Future<void> stop() async {
    _session++;
    _text = '';
    await _halt();
  }

  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
    _player = null;
    _local?.dispose();
    _local = null;
  }

  Future<void> _run(List<Engine> order, int session, String? why) async {
    for (final engine in order) {
      if (session != _session) return;
      _engine = engine;
      onSource(engine, _label(engine), why);
      try {
        await (_speakOverride?.call(session, engine) ??
            _speak(session, engine));
        if (session == _session) {
          _text = '';
          onDone();
        }
        return;
      } catch (e) {
        if (session != _session) return;
        await _halt();
        why = _failed(engine, e);
      }
    }
    if (session == _session) onError(why ?? 'Nothing could read this.');
  }

  Future<void> _speak(int session, Engine engine) => switch (engine) {
    Engine.server => _server(session),
    Engine.phone => _phone(session),
    _ => _device(session),
  };

  String _label(Engine engine) => switch (engine) {
    Engine.server =>
      'Kokoro · ${settings.kokoroVoice} · '
          '${settings.kokoroHost.split('.').first.nonEmptyOr('your server')}',
    Engine.phone => 'Kokoro · $_phoneVoice · on this phone',
    _ => 'Device voice',
  };

  String _failed(Engine engine, Object e) => switch (engine) {
    Engine.server
        when e is SpeechException && (e.status == 401 || e.status == 403) =>
      'The Kokoro server rejected the token',
    Engine.server => 'The Kokoro server didn’t answer',
    Engine.phone => 'Kokoro on this phone couldn’t read it',
    _ => 'The device voice couldn’t start. Install a system voice.',
  };

  String get _phoneVoice => localKokoroVoices.contains(settings.kokoroVoice)
      ? settings.kokoroVoice
      : localKokoroVoices[localKokoroSpeaker(settings.kokoroVoice)];

  Future<void> _halt() async {
    _client?.close();
    _client = null;
    try {
      await _player?.stop();
      await _tts?.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  Future<void> _server(int session) async {
    final client = http.Client();
    _client = client;
    final api = SpeechApi(client);
    final voice = settings.kokoroVoice;
    await _play(session, 'audio/mpeg', (chunk) {
      return api.generate(
        text: chunk.text,
        endpoint: settings.kokoroEndpoint,
        apiKey: settings.kokoroToken,
        model: kokoroModel,
        voice: voice,
      );
    }, firstWait: firstAudioWait);
  }

  Future<void> _phone(int session) async {
    final model = settings.local.installed;
    if (model == null) throw const LocalKokoroException('No model');
    if (_local == null || _localModel != model) {
      _local?.dispose();
      _local = null;
      _local = await LocalKokoroEngine.start(
        await settings.local.dirOf(model),
        model: model,
      );
      _localModel = model;
    }
    if (session != _session) return;
    final engine = _local!;
    final voice = _phoneVoice;
    await _play(
      session,
      'audio/wav',
      (chunk) => engine.speak(chunk.text, voice: voice),
    );
  }

  /// Plays [_text] from [_at] in pieces, making the next while one plays.
  Future<void> _play(
    int session,
    String mimeType,
    Future<Uint8List> Function(TextChunk chunk) make, {
    Duration? firstWait,
  }) async {
    final from = _at;
    final chunks = phoneChunks(_text.substring(from));
    if (chunks.isEmpty) return;
    final player = _player ??= AudioPlayer();
    Future<Uint8List> start(TextChunk chunk) {
      final future = make(chunk);
      future.ignore();
      return future;
    }

    var next = firstWait == null
        ? start(chunks.first)
        : start(chunks.first).timeout(firstWait);
    next.ignore();
    for (var i = 0; i < chunks.length; i++) {
      final bytes = await next;
      if (session != _session) return;
      if (i + 1 < chunks.length) next = start(chunks[i + 1]);
      _at = from + chunks[i].start;
      await player.setUrl(
        Uri.dataFromBytes(bytes, mimeType: mimeType).toString(),
      );
      if (session != _session) return;
      await player.play();
      if (session != _session) return;
    }
  }

  Future<void> _device(int session) async {
    final tts = _tts ??= FlutterTts();
    await tts.awaitSpeakCompletion(true);
    // 0.5 is Android's normal rate in flutter_tts.
    await tts.setSpeechRate(0.5);
    final from = _at;
    for (final chunk in chunkText(_text.substring(from))) {
      if (session != _session) return;
      _at = from + chunk.start;
      final result = await tts.speak(chunk.text);
      if (session != _session) return;
      if (result == 0) throw const SpeechException('Device speech failed');
    }
  }
}

extension on String {
  String nonEmptyOr(String fallback) => isEmpty ? fallback : this;
}

/// The background engine's entry point (see `readAloudMain` in main.dart).
Future<void> runSelectionReader() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel('voxen/read_aloud');
  final settings = VoiceSettings(store: DeviceSettingsStore());
  await settings.load();
  final reader = SelectionReader(
    settings,
    onSource: (engine, label, why) => channel.invokeMethod('source', {
      'label': label,
      'why': why,
      'device': engine == Engine.device,
    }),
    onDone: () => channel.invokeMethod('done'),
    onError: (message) => channel.invokeMethod('error', message),
  );
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'read':
        unawaited(reader.read(call.arguments as String));
      case 'device':
        unawaited(reader.useDevice());
      case 'stop':
        await reader.stop();
    }
  });
  await channel.invokeMethod('ready');
}
