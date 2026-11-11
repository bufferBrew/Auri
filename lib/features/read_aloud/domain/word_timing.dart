import 'package:flutter/foundation.dart';

import 'text_chunk.dart';

/// One spoken word as the voice server timed it, relative to its chunk's
/// audio.
@immutable
class WordTiming {
  const WordTiming({
    required this.word,
    required this.start,
    required this.end,
  });

  /// Reads Kokoro's `{word, start_time, end_time}` (seconds). Returns null
  /// for anything malformed rather than throwing — one bad entry should cost
  /// one highlighted word, not the whole reading.
  static WordTiming? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? word = json['word'];
    final Object? start = json['start_time'];
    final Object? end = json['end_time'];
    if (word is! String ||
        start is! num ||
        end is! num ||
        !start.isFinite ||
        !end.isFinite ||
        start < 0 ||
        end < start ||
        end > 86400) {
      return null;
    }
    return WordTiming(
      word: word,
      start: Duration(microseconds: (start * 1e6).round()),
      end: Duration(microseconds: (end * 1e6).round()),
    );
  }

  final String word;
  final Duration start;
  final Duration end;
}

/// A [WordTiming] pinned to the characters it highlights in the body.
@immutable
class AlignedWord {
  const AlignedWord({required this.span, required this.start});

  final BodySpan span;

  /// When this word starts in its chunk's audio.
  final Duration start;
}

/// How many words ahead the aligner looks for a match before deciding the
/// voice said something that is not in the text ("$5" read as "five dollars").
const int _lookahead = 6;

final RegExp _wordPattern = RegExp(
  r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*",
  unicode: true,
);

/// Pins each of [timings] to a word of [chunk], walking both in order.
///
/// The voice server normalises text before speaking it — numbers, symbols,
/// abbreviations — so its words do not always appear in the body. A timing
/// that matches nothing within a few words is pinned to the next unmatched
/// body word without consuming it, so "$5" stays lit while "five dollars" is
/// spoken. Timings that are pure punctuation are skipped.
///
/// Returns an empty list when nothing at all matched: the caller then falls
/// back to highlighting whole sentences instead of lighting random words.
List<AlignedWord> alignWords(TextChunk chunk, List<WordTiming> timings) {
  final List<({BodySpan span, String key})> words =
      <({BodySpan span, String key})>[
        for (final RegExpMatch m in _wordPattern.allMatches(chunk.text))
          (
            span: BodySpan(chunk.start + m.start, chunk.start + m.end),
            key: _key(m[0]!),
          ),
      ];
  if (words.isEmpty) return const <AlignedWord>[];

  final List<AlignedWord> aligned = <AlignedWord>[];
  int cursor = 0;
  int matched = 0;

  for (final WordTiming timing in timings) {
    final String key = _key(timing.word);
    if (key.isEmpty) continue;

    int found = -1;
    final int limit = (cursor + _lookahead).clamp(0, words.length);
    for (int i = cursor; i < limit; i++) {
      if (words[i].key == key) {
        found = i;
        break;
      }
    }

    if (found >= 0) {
      aligned.add(AlignedWord(span: words[found].span, start: timing.start));
      cursor = found + 1;
      matched++;
    } else {
      final int at = cursor.clamp(0, words.length - 1);
      aligned.add(AlignedWord(span: words[at].span, start: timing.start));
    }
  }

  return matched == 0 ? const <AlignedWord>[] : aligned;
}

/// The word being spoken at [position]: the last one that has started.
/// Null before the first word.
int? activeWordAt(List<AlignedWord> words, Duration position) {
  int low = 0;
  int high = words.length - 1;
  int? best;
  while (low <= high) {
    final int mid = (low + high) >> 1;
    if (words[mid].start <= position) {
      best = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return best;
}

String _key(String word) => word
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^\p{L}\p{N}']", unicode: true), '');
