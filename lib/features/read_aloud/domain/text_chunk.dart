import 'package:flutter/foundation.dart';

/// A span of a reading's text: `[start, end)` character offsets into the body.
@immutable
class BodySpan {
  const BodySpan(this.start, this.end);

  final int start;
  final int end;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  bool operator ==(Object other) =>
      other is BodySpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

/// One piece of a reading sent to the voice server in a single request.
///
/// Chunks are synthesised in order and played back to back, so the first one
/// can start while the rest are still being made. [start] and [end] place the
/// chunk in the original body, which is what word highlighting maps back onto.
@immutable
class TextChunk {
  const TextChunk({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  final int index;
  final int start;
  final int end;
  final String text;

  @override
  String toString() => 'TextChunk($index, [$start, $end))';
}

/// The most text sent in one request. Big enough that sentences flow
/// naturally across a chunk, small enough that the first audio arrives in a
/// couple of seconds and one request stays far below the function's timeout.
const int defaultChunkChars = 1200;

/// Splits [body] into chunks of at most [maxChars], breaking at paragraph
/// ends, then sentence ends, then spaces — never inside a word unless a single
/// word is longer than [maxChars].
///
/// Whitespace between chunks belongs to no chunk, so `text` never starts or
/// ends with it, but offsets still point into the untouched body.
List<TextChunk> chunkText(String body, {int maxChars = defaultChunkChars}) {
  final List<TextChunk> chunks = <TextChunk>[];
  int cursor = _skipSpace(body, 0);

  while (cursor < body.length) {
    int end = cursor + maxChars;
    if (end >= body.length) {
      end = body.length;
    } else {
      end = _bestBreak(body, cursor, end);
    }
    final int trimmedEnd = _trimEnd(body, cursor, end);
    if (trimmedEnd > cursor) {
      chunks.add(
        TextChunk(
          index: chunks.length,
          start: cursor,
          end: trimmedEnd,
          text: body.substring(cursor, trimmedEnd),
        ),
      );
    }
    cursor = _skipSpace(body, end);
  }
  return chunks;
}

/// Sentence spans of [body], used for tap-to-seek, skipping by sentence and
/// the highlight fallback when word timings cannot be matched.
List<BodySpan> sentenceRanges(String body) {
  final List<BodySpan> ranges = <BodySpan>[];
  int start = _skipSpace(body, 0);
  for (final RegExpMatch m in _sentenceEnd.allMatches(body)) {
    final int end = _trimEnd(body, start, m.end);
    if (end > start) ranges.add(BodySpan(start, end));
    start = _skipSpace(body, m.end);
  }
  final int end = _trimEnd(body, start, body.length);
  if (end > start) ranges.add(BodySpan(start, end));
  return ranges;
}

/// Paragraph spans of [body] — the text between blank lines. Drawn as one
/// block each on screen, and the unit the player skips and restarts by.
List<BodySpan> paragraphRanges(String body) {
  final List<BodySpan> spans = <BodySpan>[];
  int start = 0;
  for (final RegExpMatch m in RegExp(r'\n\s*\n').allMatches(body)) {
    if (m.start > start) spans.add(BodySpan(start, m.start));
    start = m.end;
  }
  if (start < body.length) spans.add(BodySpan(start, body.length));
  return spans;
}

/// The end of a sentence: terminal punctuation (plus closing quotes or
/// brackets) followed by whitespace, or a paragraph break.
final RegExp _sentenceEnd = RegExp(r'''[.!?…]+["'”’)\]]*\s+|\n\s*\n''');

int _bestBreak(String body, int start, int limit) {
  final String window = body.substring(start, limit);
  final int minUseful = (window.length * 0.4).floor();

  final int paragraph = window.lastIndexOf('\n\n');
  if (paragraph >= minUseful) return start + paragraph;

  int sentence = -1;
  for (final RegExpMatch m in _sentenceEnd.allMatches(window)) {
    sentence = m.end;
  }
  if (sentence >= minUseful) return start + sentence;

  final int space = window.lastIndexOf(RegExp(r'\s'));
  if (space > 0) return start + space;
  return limit;
}

int _skipSpace(String body, int i) {
  while (i < body.length && _isSpace(body.codeUnitAt(i))) {
    i++;
  }
  return i;
}

int _trimEnd(String body, int start, int end) {
  while (end > start && _isSpace(body.codeUnitAt(end - 1))) {
    end--;
  }
  return end;
}

bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09;
