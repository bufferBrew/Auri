// Runs the real on-device engine on a desktop host. Skipped unless pointed at
// an unpacked model and the host's sherpa-onnx library:
//
//   AURI_MODEL_DIR=/path/to/kokoro-multi-lang-v1_0 \
//   AURI_SHERPA_LIB=~/.pub-cache/hosted/pub.dev/sherpa_onnx_macos-1.13.8/macos \
//   flutter test test/local_kokoro_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:auri/on_device/local_kokoro.dart';

void main() {
  final dir = Platform.environment['AURI_MODEL_DIR'];
  final lib = Platform.environment['AURI_SHERPA_LIB'];
  test(
    'the real model speaks',
    () async {
      final model = File('$dir/model.onnx').existsSync()
          ? LocalModel.full
          : LocalModel.compact;
      final engine = await LocalKokoroEngine.start(
        dir!,
        model: model,
        libraryPath: lib,
      );
      addTearDown(engine.dispose);
      final sw = Stopwatch()..start();
      final wav = await engine.speak(
        'Sunlight looks white, but it is a mix of every colour.',
        voice: 'af_heart',
      );
      final seconds = (wav.length - 44) / 2 / 24000;
      // ignore: avoid_print
      print(
        '${model.name}: ${seconds.toStringAsFixed(1)} s of audio in '
        '${sw.elapsedMilliseconds} ms',
      );
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(seconds, greaterThan(1));
    },
    skip: dir == null || lib == null
        ? 'Set AURI_MODEL_DIR and AURI_SHERPA_LIB to run'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
