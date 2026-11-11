import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/word_timing.dart';
import 'audio_cache_storage.dart'
    if (dart.library.io) 'audio_cache_storage_io.dart';

typedef CachedSpeech = ({Uint8List audio, List<WordTiming> timings});

/// Keeps generated audio for saved readings. Storage failures never interrupt
/// playback. The key includes all synthesis inputs but no credentials.
class ReadingAudioCache {
  ReadingAudioCache({AudioCacheStorage? storage})
    : _storage = storage ?? AudioCacheStorage();

  final AudioCacheStorage _storage;
  Future<void> _pending = Future.value();

  String _key(String id, String input) {
    final reading = sha256.convert(utf8.encode(id));
    final speech = sha256.convert(utf8.encode(input));
    return '$reading-$speech';
  }

  Future<CachedSpeech?> read(String id, String input) async {
    try {
      await _pending;
      final record = await _storage.read(_key(id, input));
      if (record == null) return null;
      final data = jsonDecode(record) as Map;
      return (
        audio: base64Decode(data['audio'] as String),
        timings: [
          for (final word in data['words'] as List) ?WordTiming.fromJson(word),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String id, String input, CachedSpeech speech) {
    _pending = _pending
        .then((_) async {
          await _storage.write(
            _key(id, input),
            jsonEncode({
              'written': DateTime.now().millisecondsSinceEpoch,
              'audio': base64Encode(speech.audio),
              'words': [
                for (final word in speech.timings)
                  {
                    'word': word.word,
                    'start_time': word.start.inMicroseconds / 1e6,
                    'end_time': word.end.inMicroseconds / 1e6,
                  },
              ],
            }),
          );
        })
        .catchError((Object _) {});
    return _pending;
  }

  Future<void> deleteReading(String id) {
    _pending = _pending
        .then(
          (_) => _storage.deleteReading(
            sha256.convert(utf8.encode(id)).toString(),
          ),
        )
        .catchError((Object _) {});
    return _pending;
  }
}
