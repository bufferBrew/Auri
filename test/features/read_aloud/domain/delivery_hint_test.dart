import 'package:flutter_test/flutter_test.dart';
import 'package:auri/features/read_aloud/domain/delivery_hint.dart';
import 'package:auri/features/read_aloud/domain/text_chunk.dart';

DeliveryHint _h(
  String anchor,
  HintKind kind, {
  int occurrence = 1,
  double amount = 0,
  String ipa = '',
  bool enabled = true,
  String id = 'h',
}) => DeliveryHint(
  id: id,
  anchor: anchor,
  occurrence: occurrence,
  kind: kind,
  amount: amount,
  ipa: ipa,
  reason: 'r',
  enabled: enabled,
);

TextChunk _whole(String body) =>
    TextChunk(index: 0, start: 0, end: body.length, text: body);

String _compile(String body, List<DeliveryHint> hints) =>
    compileChunk(_whole(body), placeHints(body, hints));

void main() {
  group('placeHints', () {
    test('finds the nth occurrence and sorts by position', () {
      const String body = 'the key, the key, the key';
      final List<PlacedHint> placed = placeHints(body, <DeliveryHint>[
        _h('key', HintKind.emphasis, occurrence: 3, id: 'b'),
        _h('key', HintKind.emphasis, occurrence: 2, id: 'a'),
      ]);
      expect(placed.map((PlacedHint p) => p.hint.id), <String>['a', 'b']);
      expect(placed.first.span, const BodySpan(13, 16));
      expect(placed.last.span, const BodySpan(22, 25));
    });

    test('drops hints whose anchor is missing', () {
      expect(
        placeHints('abc', <DeliveryHint>[_h('zzz', HintKind.slow)]),
        isEmpty,
      );
      expect(
        placeHints('key', <DeliveryHint>[
          _h('key', HintKind.slow, occurrence: 2),
        ]),
        isEmpty,
      );
    });
  });

  group('compileChunk', () {
    test('each kind becomes Kokoro markup', () {
      expect(
        _compile('Wait for it. Then go.', <DeliveryHint>[
          _h('Wait for it.', HintKind.pause, amount: 0.6),
        ]),
        'Wait for it. [pause:0.6s]  Then go.',
      );
      expect(
        _compile('It is the key point.', <DeliveryHint>[
          _h('key', HintKind.emphasis),
        ]),
        'It is the [pause:0.15s][rate:0.85]key[rate:1] point.',
      );
      expect(
        _compile('Costs 4,096 bytes.', <DeliveryHint>[
          _h('4,096 bytes', HintKind.slow, amount: 0.75),
        ]),
        'Costs [rate:0.75]4,096 bytes[rate:1].',
      );
      expect(
        _compile('Ask Nguyen.', <DeliveryHint>[
          _h('Nguyen', HintKind.pronounce, ipa: 'wˈɪn'),
        ]),
        'Ask [Nguyen](/wˈɪn/).',
      );
    });

    test('no enabled hints gives back the exact text, so the cache hits', () {
      const String body = 'Plain text.';
      expect(
        _compile(body, <DeliveryHint>[
          _h('Plain', HintKind.emphasis, enabled: false),
        ]),
        body,
      );
    });

    test('overlapping wrappers keep the first; pauses still apply', () {
      expect(
        _compile('one two three', <DeliveryHint>[
          _h('one two', HintKind.slow, amount: 0.8),
          _h('two', HintKind.emphasis),
          _h('two', HintKind.pause, amount: 0.3),
        ]),
        '[rate:0.8]one two[rate:1] [pause:0.3s]  three',
      );
    });

    test('only hints inside the chunk apply, at chunk-local offsets', () {
      const String body = 'First part. Second part.';
      const TextChunk second = TextChunk(
        index: 1,
        start: 12,
        end: 24,
        text: 'Second part.',
      );
      final List<PlacedHint> placed = placeHints(body, <DeliveryHint>[
        _h('First', HintKind.emphasis),
        _h('part', HintKind.slow, occurrence: 2, amount: 0.7),
      ]);
      expect(compileChunk(second, placed), 'Second [rate:0.7]part[rate:1].');
    });
  });

  test('round-trips through JSON and rejects malformed rows', () {
    final DeliveryHint h = _h('Nguyen', HintKind.pronounce, ipa: 'wˈɪn');
    expect(DeliveryHint.fromJson(h.toJson())!.toJson(), h.toJson());
    expect(DeliveryHint.fromJson(<String, Object>{'kind': 'whisper'}), isNull);
    expect(h.summary, 'Say /wˈɪn/');
  });
}
