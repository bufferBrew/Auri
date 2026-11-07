import 'package:flutter_test/flutter_test.dart';
import 'package:voxen/features/read_aloud/domain/text_chunk.dart';

void main() {
  group('chunkText', () {
    test('short text is one chunk with exact offsets', () {
      const String body = '  Hello there.  ';
      final List<TextChunk> chunks = chunkText(body);
      expect(chunks, hasLength(1));
      expect(chunks.single.text, 'Hello there.');
      expect(
        body.substring(chunks.single.start, chunks.single.end),
        'Hello there.',
      );
    });

    test('breaks at paragraphs, then sentences, never mid-word', () {
      final String para = List<String>.filled(
        8,
        'One sentence here.',
      ).join(' ');
      final String body = '$para\n\n$para\n\n$para';
      final List<TextChunk> chunks = chunkText(body, maxChars: 200);

      expect(chunks.length, greaterThan(1));
      for (final TextChunk c in chunks) {
        expect(c.text.length, lessThanOrEqualTo(200));
        expect(body.substring(c.start, c.end), c.text);
        expect(c.text.trim(), c.text);
        expect(c.text, endsWith('.'));
      }
      expect(
        chunks.map((TextChunk c) => c.index),
        List<int>.generate(chunks.length, (int i) => i),
      );
    });

    test('covers every word exactly once', () {
      final String body = List<String>.generate(
        300,
        (int i) => 'w$i',
      ).join(' ');
      final List<TextChunk> chunks = chunkText(body, maxChars: 97);
      final List<String> words = chunks
          .expand((TextChunk c) => c.text.split(' '))
          .toList();
      expect(words, body.split(' '));
    });

    test('empty or blank text has no chunks', () {
      expect(chunkText(''), isEmpty);
      expect(chunkText(' \n\n '), isEmpty);
    });
  });

  group('sentenceRanges', () {
    test('splits on terminal punctuation and paragraph breaks', () {
      const String body = 'First one. Second? "Third!" said she.\n\nNew para';
      final List<String> sentences = sentenceRanges(
        body,
      ).map((BodySpan s) => body.substring(s.start, s.end)).toList();
      expect(sentences, <String>[
        'First one.',
        'Second?',
        '"Third!"',
        'said she.',
        'New para',
      ]);
    });
  });
}
