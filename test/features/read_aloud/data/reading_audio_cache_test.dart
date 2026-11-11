import 'dart:io';
import 'dart:typed_data';

import 'package:auri/features/read_aloud/data/audio_cache_storage.dart'
    if (dart.library.io) 'package:auri/features/read_aloud/data/audio_cache_storage_io.dart';
import 'package:auri/features/read_aloud/data/reading_audio_cache.dart';
import 'package:auri/features/read_aloud/domain/word_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reopens cached audio and timings, and deletes only the chosen reading',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'auri-audio-cache-test',
      );
      addTearDown(() => root.delete(recursive: true));
      ReadingAudioCache open() => ReadingAudioCache(
        storage: AudioCacheStorage(cachePath: () async => root.path),
      );
      final speech = (
        audio: Uint8List.fromList([0xff, 0xfb, 0x90, 0]),
        timings: const [
          WordTiming(
            word: 'Hello',
            start: Duration(milliseconds: 125),
            end: Duration(milliseconds: 400),
          ),
        ],
      );
      final cache = open();
      await Future.wait([
        cache.write('first', 'voice-one\nHello', speech),
        cache.write('second', 'voice-one\nHello', speech),
      ]);

      final reopened = open();
      final cached = await reopened.read('first', 'voice-one\nHello');
      expect(cached?.audio, speech.audio);
      expect(cached?.timings.single.word, 'Hello');
      expect(cached?.timings.single.start, const Duration(milliseconds: 125));
      expect(await reopened.read('first', 'voice-two\nHello'), isNull);

      await reopened.deleteReading('first');
      expect(await open().read('first', 'voice-one\nHello'), isNull);
      expect(await open().read('second', 'voice-one\nHello'), isNotNull);
    },
  );
}
