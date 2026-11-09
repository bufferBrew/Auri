import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxen/features/read_aloud/selection_reader.dart';
import 'package:voxen/on_device/local_kokoro.dart';
import 'package:voxen/on_device/local_models.dart';
import 'package:voxen/voice_settings.dart';

class _Installed extends LocalModels {
  @override
  LocalModel? get installed => LocalModel.full;
}

void main() {
  VoiceSettings settings({bool phone = false, bool server = false}) {
    final s = VoiceSettings(
      store: MemorySettingsStore(),
      local: phone ? _Installed() : null,
    );
    if (server) {
      s
        ..kokoroUrl = 'https://mac.example.ts.net'
        ..kokoroToken = 't'
        ..rememberToken = true;
    }
    return s;
  }

  group('selectionOrder', () {
    test('fastest available: server, then phone, then device', () {
      expect(settings(phone: true, server: true).selectionOrder, [
        Engine.server,
        Engine.phone,
        Engine.device,
      ]);
      expect(settings(phone: true).selectionOrder, [
        Engine.phone,
        Engine.device,
      ]);
      expect(settings().selectionOrder, [Engine.device]);
    });

    test('a token that is not remembered cannot reach the background', () {
      final s = settings(server: true)..rememberToken = false;
      expect(s.selectionCanUseServer, isFalse);
      expect(s.selectionOrder, [Engine.device]);
    });

    test('a chosen voice keeps the device voice as the fallback', () {
      final s = settings(phone: true, server: true);
      s.selectionVoice = SelectionVoice.phone;
      expect(s.selectionOrder, [Engine.phone, Engine.device]);
      s.selectionVoice = SelectionVoice.server;
      expect(s.selectionOrder, [Engine.server, Engine.device]);
      s.selectionVoice = SelectionVoice.device;
      expect(s.selectionOrder, [Engine.device]);
    });

    test('the choice is saved', () async {
      final store = MemorySettingsStore();
      VoiceSettings(store: store).selectionVoice = SelectionVoice.server;
      final reopened = VoiceSettings(store: store);
      await reopened.load();
      expect(reopened.selectionVoice, SelectionVoice.server);
    });
  });

  group('SelectionReader', () {
    late List<(Engine, String?)> sources;
    late List<String> events;

    SelectionReader reader(
      VoiceSettings s,
      Future<void> Function(int, Engine) speak,
    ) => SelectionReader(
      s,
      onSource: (e, label, why) => sources.add((e, why)),
      onDone: () => events.add('done'),
      onError: (m) => events.add('error: $m'),
      speak: speak,
    );

    setUp(() {
      sources = [];
      events = [];
    });

    test('a failing voice falls to the next, and says why', () async {
      final r = reader(settings(phone: true, server: true), (_, e) async {
        if (e == Engine.server) throw Exception('offline');
      });
      await r.read('Hello there.');
      expect(sources, [
        (Engine.server, null),
        (Engine.phone, 'The Kokoro server didn’t answer'),
      ]);
      expect(events, ['done']);
    });

    test('Device voice switches mid-reading and keeps the place', () async {
      final s = settings(server: true);
      final reading = Completer<void>();
      late SelectionReader r;
      r = reader(s, (_, e) async {
        if (e == Engine.server) await reading.future;
      });
      final first = r.read('One. Two. Three.');
      await Future<void>.delayed(Duration.zero);
      expect(r.engine, Engine.server);
      await r.useDevice();
      reading.complete();
      await first;
      expect(sources.map((s) => s.$1), [Engine.server, Engine.device]);
      expect(events, ['done'], reason: 'the replaced reading reports nothing');
    });

    test('new text replaces the reading; stop ends it quietly', () async {
      final hold = Completer<void>();
      final r = reader(settings(), (_, e) => hold.future);
      final first = r.read('First.');
      await Future<void>.delayed(Duration.zero);
      final second = r.read('Second.');
      await Future<void>.delayed(Duration.zero);
      await r.stop();
      hold.complete();
      await Future.wait([first, second]);
      expect(events, isEmpty);
    });
  });

  test('phone pieces start short', () {
    final text = List.filled(60, 'A short sentence here.').join(' ');
    final chunks = phoneChunks(text);
    expect(chunks.first.text.length, lessThanOrEqualTo(localKokoroFirstChars));
    expect(
      chunks.skip(1).every((c) => c.text.length <= localKokoroChunkChars),
      isTrue,
    );
    expect(chunks.last.end, text.length);
  });
}
