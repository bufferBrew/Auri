import 'package:auri/features/read_aloud/domain/voice_option.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auri/features/read_aloud/domain/text_chunk.dart';
import 'package:auri/features/read_aloud/domain/word_timing.dart';

WordTiming _t(String word, int ms) => WordTiming(
  word: word,
  start: Duration(milliseconds: ms),
  end: Duration(milliseconds: ms + 100),
);

TextChunk _chunk(String body, {int offset = 0}) =>
    TextChunk(index: 0, start: offset, end: offset + body.length, text: body);

String _lit(String body, AlignedWord w, int offset) =>
    body.substring(w.span.start - offset, w.span.end - offset);

void main() {
  group('alignWords', () {
    test('maps each timed word onto the body, offset by the chunk start', () {
      const String text = "Hello, world. It's fine.";
      final List<AlignedWord> words =
          alignWords(_chunk(text, offset: 100), <WordTiming>[
            _t('Hello', 0),
            _t(',', 300),
            _t('world', 400),
            _t('.', 700),
            _t("It's", 800),
            _t('fine', 1000),
          ]);
      expect(words.map((AlignedWord w) => _lit(text, w, 100)), <String>[
        'Hello',
        'world',
        "It's",
        'fine',
      ]);
      expect(words[1].start, const Duration(milliseconds: 400));
    });

    test('normalised words stay on the source word without consuming it', () {
      const String text = 'Pay \$5 today';
      final List<AlignedWord> words = alignWords(_chunk(text), <WordTiming>[
        _t('Pay', 0),
        _t('five', 200),
        _t('dollars', 400),
        _t('today', 600),
      ]);
      expect(words.map((AlignedWord w) => _lit(text, w, 0)), <String>[
        'Pay',
        '5',
        '5',
        'today',
      ]);
    });

    test('nothing matching at all means no word highlighting', () {
      expect(
        alignWords(_chunk('Bonjour le monde'), <WordTiming>[_t('hello', 0)]),
        isEmpty,
      );
    });
  });

  group('activeWordAt', () {
    final List<AlignedWord> words = <AlignedWord>[
      for (int i = 0; i < 5; i++)
        AlignedWord(
          span: BodySpan(i * 2, i * 2 + 1),
          start: Duration(milliseconds: i * 100),
        ),
    ];

    test('is the last word that has started', () {
      expect(activeWordAt(words, const Duration(milliseconds: 250)), 2);
      expect(activeWordAt(words, const Duration(milliseconds: 400)), 4);
      expect(activeWordAt(words, const Duration(seconds: 9)), 4);
    });

    test('is null before the first word and for no words', () {
      expect(
        activeWordAt(<AlignedWord>[
          AlignedWord(
            span: const BodySpan(0, 1),
            start: const Duration(milliseconds: 50),
          ),
        ], Duration.zero),
        isNull,
      );
      expect(activeWordAt(const <AlignedWord>[], Duration.zero), isNull);
    });
  });

  group('WordTiming.fromJson', () {
    test('reads Kokoro seconds and rejects malformed entries', () {
      final WordTiming? t = WordTiming.fromJson(<String, dynamic>{
        'word': 'hi',
        'start_time': 1.25,
        'end_time': 1.5,
      });
      expect(t!.start, const Duration(milliseconds: 1250));
      expect(WordTiming.fromJson(<String, dynamic>{'word': 'x'}), isNull);
      expect(WordTiming.fromJson('nope'), isNull);
    });
  });

  group('VoiceOption', () {
    test('derives a readable label from the Kokoro id', () {
      expect(const VoiceOption('af_heart').label, 'Heart · American female');
      expect(const VoiceOption('bm_george').label, 'George · British male');
      expect(const VoiceOption('jf_alpha').isEnglish, isFalse);
    });
  });
}
