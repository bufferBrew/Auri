import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auri/speech_api.dart';
import 'package:auri/mp3.dart';

void main() {
  Future<Uint8List> generate(
    SpeechApi api, {
    String text = 'Hello.',
    String endpoint = 'https://example.com/v1/audio/speech',
  }) => api.generate(
    text: text,
    endpoint: endpoint,
    apiKey: 'test-placeholder',
    model: 'tts-1',
    voice: 'alloy',
  );
  test('chunks long text, authenticates and requests MP3', () async {
    var count = 0;
    final api = SpeechApi(
      MockClient((request) async {
        count++;
        expect(request.headers['Authorization'], 'Bearer test-placeholder');
        final body = jsonDecode(request.body) as Map;
        expect(body['response_format'], 'mp3');
        expect((body['input'] as String).length, lessThanOrEqualTo(1200));
        expect(request.followRedirects, false);
        return http.Response.bytes([0xff, 0xfb, 0x90, 0], 200);
      }),
    );
    final audio = await generate(
      api,
      text: List.filled(600, 'Hello.').join(' '),
    );
    expect(count, greaterThan(1));
    expect(audio.length, count * 4);
  });
  test('Kokoro requests timed audio and allows delivery tags', () async {
    final api = SpeechApi(
      MockClient((request) async {
        expect(request.url.path, '/dev/captioned_speech');
        expect(request.headers['Authorization'], 'Bearer test-placeholder');
        expect(request.followRedirects, false);
        final body = jsonDecode(request.body) as Map;
        expect(body['return_timestamps'], true);
        expect(body['allow_voice_tags'], true);
        expect(body['input'], 'Hello [pause:0.5s]');
        return http.Response(
          jsonEncode({
            'audio': base64Encode([0xff, 0xfb, 0x90, 0]),
            'timestamps': [
              {'word': 'Hello', 'start_time': 0.1, 'end_time': 0.4},
              {'word': 'bad', 'start_time': -5, 'end_time': -1},
            ],
          }),
          200,
        );
      }),
    );
    final result = await api.captioned(
      endpoint: 'https://example.com/v1/audio/speech',
      apiKey: 'test-placeholder',
      voice: 'af_heart',
      text: 'Hello [pause:0.5s]',
      useMarkup: true,
    );
    expect(result.audio.length, 4);
    expect(result.timings.single.word, 'Hello');
    expect(result.timings.single.start, const Duration(milliseconds: 100));
  });

  test('Kokoro falls back to standard speech only for unmarked text', () async {
    final requests = <String>[];
    final api = SpeechApi(
      MockClient((request) async {
        requests.add(request.url.path);
        return request.url.path == '/dev/captioned_speech'
            ? http.Response('', 404)
            : http.Response.bytes([0xff, 0xfb, 0x90, 0], 200);
      }),
    );
    Future<void> speak(bool useMarkup) => api.captioned(
      endpoint: 'https://example.com/v1/audio/speech',
      apiKey: 'test-placeholder',
      voice: 'af_heart',
      text: 'Hello',
      useMarkup: useMarkup,
    );
    await speak(false);
    await expectLater(speak(true), throwsA(isA<SpeechException>()));
    expect(requests, [
      '/dev/captioned_speech',
      '/v1/audio/speech',
      '/dev/captioned_speech',
    ]);
  });

  test('rejects insecure endpoints before sending a key', () async {
    final api = SpeechApi(
      MockClient((_) async {
        fail('Must not send credentials');
      }),
    );
    for (final url in [
      'http://example.com',
      'https://user:pass@example.com',
      'https://example.com?key=value',
    ]) {
      await expectLater(
        generate(api, endpoint: url),
        throwsA(isA<SpeechException>()),
      );
    }
  });
  test('does not expose provider response bodies in errors', () async {
    final api = SpeechApi(
      MockClient(
        (_) async => http.Response('sensitive-provider-response', 401),
      ),
    );
    await expectLater(
      generate(api),
      throwsA(
        isA<SpeechException>().having(
          (e) => e.message,
          'message',
          isNot(contains('sensitive')),
        ),
      ),
    );
  });
  test('rejects non-audio success and redirected responses', () async {
    for (final status in [200, 302]) {
      final api = SpeechApi(
        MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(generate(api), throwsA(isA<SpeechException>()));
    }
  });
  test(
    'MP3 concatenation strips later ID3 metadata and sanitizes filenames',
    () {
      final part = Uint8List.fromList([
        0x49,
        0x44,
        0x33,
        4,
        0,
        0,
        0,
        0,
        0,
        0,
        0xff,
        0xfb,
        0x90,
        0,
      ]);
      expect(concatMp3([part, part]).length, 18);
      expect(mp3FileName('A/B: C?'), 'A B C.mp3');
    },
  );
}
