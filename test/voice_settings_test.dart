import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voxen/speech_preset.dart';
import 'package:voxen/voice_settings.dart';

void main() {
  const url = 'https://mac.example.ts.net';

  VoiceSettings make(
    Future<http.Response> Function(http.Request) handler, {
    MemorySettingsStore? store,
  }) => VoiceSettings(
    store: store ?? MemorySettingsStore(),
    client: () => MockClient(handler),
  );

  test('not set up and no token never touch the network', () async {
    final s = make((_) async => fail('Must not call'));
    expect((await s.checkKokoro()).state, KokoroState.notSetUp);
    s.kokoroUrl = url;
    expect((await s.checkKokoro()).state, KokoroState.needsToken);
  });

  test('available, rejected and offline', () async {
    final cases = <Future<http.Response> Function(http.Request), KokoroState>{
      (_) async => http.Response('{"voices":["af_heart"]}', 200):
          KokoroState.available,
      (_) async => http.Response('', 401): KokoroState.rejected,
      (_) async => throw http.ClientException('no route'): KokoroState.offline,
      (_) async => http.Response('', 502): KokoroState.offline,
    };
    for (final MapEntry(key: handler, value: expected) in cases.entries) {
      final s = make(handler)
        ..kokoroUrl = url
        ..kokoroToken = 't';
      final status = await s.checkKokoro();
      expect(status.state, expected);
      expect(
        s.wouldUseKokoro,
        expected == KokoroState.available,
        reason: 'Automatic follows availability',
      );
    }
  });

  test('a fresh result is reused, and editing the token resets it', () async {
    var calls = 0;
    final s =
        make((_) async {
            calls++;
            return http.Response('{"voices":["af_heart","bf_emma"]}', 200);
          })
          ..kokoroUrl = url
          ..kokoroToken = 't';
    await s.checkKokoro();
    await s.checkKokoro();
    expect(calls, 1);
    expect(s.kokoroVoices, ['af_heart', 'bf_emma']);
    s.kokoroToken = 'other';
    expect(s.kokoroStatus.state, KokoroState.unknown);
    expect(s.kokoroVoices, isNull);
    await s.checkKokoro();
    expect(calls, 2);
  });

  test(
    'the token is remembered only when asked, and forgotten after',
    () async {
      final store = MemorySettingsStore();
      final s = make((_) async => http.Response('', 500), store: store)
        ..kokoroUrl = url
        ..kokoroToken = 'secret-token';
      await pumpEventQueue();
      expect(store.secrets, isEmpty);

      s.rememberToken = true;
      s.mode = ReadMode.kokoro;
      s.kokoroVoice = 'bf_emma';
      await pumpEventQueue();
      expect(store.secrets['kokoro_token'], 'secret-token');

      final reopened = make((_) async => http.Response('', 500), store: store);
      await reopened.load();
      expect(reopened.kokoroToken, 'secret-token');
      expect(reopened.kokoroUrl, url);
      expect(reopened.mode, ReadMode.kokoro);
      expect(reopened.kokoroVoice, 'bf_emma');

      reopened.rememberToken = false;
      await pumpEventQueue();
      expect(store.secrets, isEmpty);
      final again = make((_) async => http.Response('', 500), store: store);
      await again.load();
      expect(again.kokoroToken, isEmpty);
    },
  );

  test('switching Other API provider clears its key', () {
    final s = make((_) async => fail('no calls'))..updateApi(key: 'k');
    s.choosePreset(SpeechPreset.custom);
    expect(s.apiKey, isEmpty);
  });
}
