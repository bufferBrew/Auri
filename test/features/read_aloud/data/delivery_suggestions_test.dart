import 'dart:convert';

import 'package:auri/features/read_aloud/data/delivery_suggestions.dart';
import 'package:auri/features/read_aloud/domain/delivery_hint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'requests suggestions, places the right occurrence and requires opt-in',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url,
          Uri.https('api.openai.com', '/v1/chat/completions'),
        );
        expect(request.headers['Authorization'], 'Bearer test-placeholder');
        expect(request.followRedirects, isFalse);
        final body = jsonDecode(request.body) as Map;
        expect(body['messages'].last['content'], 'Hello. Hello.');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'suggestions': [
                      {
                        'anchor': 'Hello',
                        'occurrence': 2,
                        'kind': 'pause',
                        'amount': 0.5,
                      },
                      {
                        'anchor': 'Absent',
                        'occurrence': 1,
                        'kind': 'slow',
                        'amount': 0.8,
                      },
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final hints = await suggestDelivery(
        client,
        'Hello. Hello.',
        'test-placeholder',
      );
      expect(hints.single.enabled, isFalse);
      expect(hints.single.kind, HintKind.pause);
      expect(placeHints('Hello. Hello.', hints).single.span.start, 7);
    },
  );
}
