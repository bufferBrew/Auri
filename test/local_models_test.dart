import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auri/on_device/local_kokoro.dart';
import 'package:auri/on_device/local_models.dart';
import 'package:auri/voice_settings.dart';

/// A tiny stand-in for a model release: the required files, as a .tar.bz2.
Uint8List fakeRelease(LocalModel m, {bool complete = true}) {
  final archive = Archive();
  final files = complete ? m.requiredFiles : m.requiredFiles.skip(1);
  for (final f in files) {
    archive.add(ArchiveFile.bytes('${m.folder}/$f', 'x'.codeUnits));
  }
  return Uint8List.fromList(
    BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive)),
  );
}

void main() {
  late Directory base;
  setUp(() async => base = await Directory.systemTemp.createTemp('auri'));
  tearDown(() => base.delete(recursive: true));

  LocalModels make(Future<http.Response> Function(http.Request) handler) =>
      LocalModels(
        baseDir: () async => base,
        client: () => MockClient(handler),
        verifyModel: (model, path, verifyChecksum) async {
          if (verifyChecksum) {
            expect(
              Directory('${base.path}/${model.folder}').existsSync(),
              false,
            );
          }
          return model.requiredFiles.every(
            (name) => File('$path/$name').existsSync(),
          );
        },
      );

  test('download unpacks, checks the files and cleans up', () async {
    Uri? asked;
    final models = make((r) async {
      asked = r.url;
      return http.Response.bytes(fakeRelease(LocalModel.compact), 200);
    });
    await models.download(LocalModel.compact);
    expect(asked, LocalModel.compact.url);
    expect(models.stateOf(LocalModel.compact).phase, LocalModelPhase.ready);
    expect(models.installed, LocalModel.compact);
    expect(
      base.listSync().map((e) => e.path.split('/').last),
      [LocalModel.compact.folder],
      reason: 'no archive left behind',
    );

    final reopened = make((_) async => fail('no network on refresh'));
    await reopened.refresh();
    expect(reopened.installed, LocalModel.compact);

    await reopened.delete(LocalModel.compact);
    expect(reopened.installed, isNull);
    expect(base.listSync(), isEmpty);
  });

  test('a failed or incomplete download leaves nothing installed', () async {
    for (final response in [
      http.Response('missing', 404),
      http.Response.bytes(fakeRelease(LocalModel.full, complete: false), 200),
    ]) {
      final models = make((_) async => response);
      await models.download(LocalModel.full);
      final st = models.stateOf(LocalModel.full);
      expect(st.phase, LocalModelPhase.failed);
      expect(st.error, isNotEmpty);
      expect(models.installed, isNull);
      expect(base.listSync(), isEmpty);
    }
  });

  test(
    'a previously extracted partial model cannot reach native playback',
    () async {
      final model = LocalModel.full;
      final path = '${base.path}/${model.folder}';
      for (final name in model.requiredFiles) {
        final file = File('$path/$name');
        await file.create(recursive: true);
        await file.writeAsString('truncated');
      }
      final models = LocalModels(baseDir: () async => base);
      await models.refresh();
      expect(models.installed, isNull);
      expect(models.stateOf(model).phase, LocalModelPhase.failed);
      await expectLater(
        LocalKokoroEngine.start(path, model: model),
        throwsA(isA<LocalKokoroException>()),
      );
    },
  );

  test('cancel stops the download and removes it', () async {
    final body = StreamController<List<int>>();
    final models = LocalModels(
      baseDir: () async => base,
      client: () => MockClient.streaming(
        (_, _) async =>
            http.StreamedResponse(body.stream, 200, contentLength: 1000),
      ),
    );
    final done = models.download(LocalModel.full);
    await pumpEventQueue();
    body.add(List.filled(100, 1));
    await pumpEventQueue();
    expect(models.stateOf(LocalModel.full).phase, LocalModelPhase.downloading);
    models.cancel();
    await body.close();
    await done;
    expect(models.stateOf(LocalModel.full).phase, LocalModelPhase.absent);
    expect(models.busy, isFalse);
    expect(base.listSync(), isEmpty);
  });

  test(
    'Automatic: the Mac first by default, the phone first if chosen',
    () async {
      final models = make(
        (_) async => http.Response.bytes(fakeRelease(LocalModel.full), 200),
      );
      await models.download(LocalModel.full);
      final s =
          VoiceSettings(
              store: MemorySettingsStore(),
              local: models,
              client: () => MockClient(
                (_) async => http.Response('{"voices":["af_heart"]}', 200),
              ),
            )
            ..kokoroUrl = 'https://mac.example.ts.net'
            ..kokoroToken = 't';
      expect(s.nextEngine, Engine.phone, reason: 'server not checked yet');
      await s.checkKokoro();
      expect(s.nextEngine, Engine.server);
      s.phoneFirst = true;
      expect(s.nextEngine, Engine.phone);
      expect(s.voiceChoices, ['af_heart'], reason: "the server's list wins");
      await models.delete(LocalModel.full);
      s.phoneFirst = false;
      s.markKokoroOffline();
      expect(s.nextEngine, Engine.device);
    },
  );

  test('voices map to the model speaker ids', () {
    expect(localKokoroVoices, hasLength(54));
    expect(localKokoroSpeaker('af_heart'), 3);
    expect(localKokoroSpeaker('bm_george'), 26);
    expect(localKokoroSpeaker('af_bella(2)+af_sky(1)'), 3);
  });

  test('WAV encoding and joining', () {
    final a = encodeWav(Float32List.fromList([0, 0.5, -1, 2]), 24000);
    expect(String.fromCharCodes(a.sublist(0, 4)), 'RIFF');
    expect(a.length, 44 + 8);
    final data = ByteData.sublistView(a);
    expect(data.getUint32(24, Endian.little), 24000);
    expect(data.getInt16(46, Endian.little), 16384);
    expect(data.getInt16(50, Endian.little), 32767, reason: 'clipped');
    final joined = concatWav([a, a]);
    expect(joined.length, 44 + 16);
    expect(ByteData.sublistView(joined).getUint32(40, Endian.little), 16);
  });
}
