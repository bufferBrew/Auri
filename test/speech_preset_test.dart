import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voxen/main.dart';
import 'package:voxen/speech_api.dart';
import 'package:voxen/speech_preset.dart';

void main() {
  test('Kokoro speech endpoint from a base URL', () {
    for (final base in [
      'https://mac.example.ts.net',
      'https://mac.example.ts.net/',
      'https://mac.example.ts.net/v1/audio/speech',
    ]) {
      expect(
        kokoroSpeechEndpoint(base),
        'https://mac.example.ts.net/v1/audio/speech',
      );
    }
    final kokoro = presetSettings(SpeechPreset.kokoro);
    expect(kokoro.model, 'kokoro');
    expect(kokoro.voice, 'af_heart');
  });

  group('voices', () {
    const endpoint = 'https://mac.example.ts.net/v1/audio/speech';

    test('reads both Kokoro list formats, sorted, with the key', () async {
      for (final list in [
        ['bf_emma', 'af_heart'],
        [
          {'id': 'bf_emma', 'name': 'bf_emma'},
          {'id': 'af_heart'},
        ],
      ]) {
        final api = SpeechApi(
          MockClient((request) async {
            expect(request.method, 'GET');
            expect(
              request.url.toString(),
              'https://mac.example.ts.net/v1/audio/voices',
            );
            expect(request.headers['Authorization'], 'Bearer test-placeholder');
            return http.Response(jsonEncode({'voices': list}), 200);
          }),
        );
        expect(
          await api.voices(endpoint: endpoint, apiKey: 'test-placeholder'),
          ['af_heart', 'bf_emma'],
        );
      }
    });

    test('never sends the key to an unsafe endpoint', () async {
      final api = SpeechApi(MockClient((_) async => fail('Must not send')));
      await expectLater(
        api.voices(endpoint: 'http://mac.example/v1/audio/speech', apiKey: 'k'),
        throwsA(isA<SpeechException>()),
      );
    });

    test('rejected key and empty lists become plain messages', () async {
      for (final response in [
        http.Response('secret-body', 401),
        http.Response('{"voices":[]}', 200),
        http.Response('not json', 200),
      ]) {
        final api = SpeechApi(MockClient((_) async => response));
        await expectLater(
          api.voices(endpoint: endpoint, apiKey: 'k'),
          throwsA(
            isA<SpeechException>().having(
              (e) => e.message,
              'message',
              isNot(contains('secret')),
            ),
          ),
        );
      }
    });
  });

  testWidgets('choosing Kokoro fills its settings and clears the key', (
    tester,
  ) async {
    await tester.pumpWidget(const VoxenApp());
    await tester.tap(find.byType(DropdownButtonFormField<SpeechMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API voice · MP3 export').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'openai-placeholder',
    );
    await tester.tap(find.byType(DropdownButtonFormField<SpeechPreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kokoro').last);
    await tester.pumpAndSettle();

    final token = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Kokoro token'),
    );
    expect(token.controller!.text, isEmpty);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Model'))
          .controller!
          .text,
      'kokoro',
    );
    await tester.scrollUntilVisible(
      find.text('Load voices'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Voice'))
          .controller!
          .text,
      'af_heart',
    );
    expect(find.text('Load voices'), findsOneWidget);
  });
}
