import 'text_chunk.dart';
import 'word_timing.dart';

/// Measured audio durations where available, with a text-based estimate for
/// chunks that have yet to be synthesised.
class ReadingTimeline {
  ReadingTimeline(this.chunks);

  final List<TextChunk> chunks;
  final _durations = <int, Duration>{};
  final _words = <int, List<AlignedWord>>{};

  bool get estimated => _durations.length < chunks.length;

  void measure(TextChunk chunk, Duration? duration, List<AlignedWord> words) {
    if (duration != null && duration > Duration.zero) {
      _durations[chunk.index] = duration;
    }
    if (words.isNotEmpty) _words[chunk.index] = words;
  }

  Duration duration(TextChunk chunk) =>
      _durations[chunk.index] ?? Duration(milliseconds: chunk.text.length * 65);

  Duration get total =>
      chunks.fold(Duration.zero, (sum, c) => sum + duration(c));

  TextChunk chunkAt(int offset) =>
      chunks.firstWhere((c) => c.end > offset, orElse: () => chunks.last);

  Duration localTime(TextChunk chunk, int offset) {
    if (offset <= chunk.start) return Duration.zero;
    final words = _words[chunk.index];
    if (words != null) {
      return words
          .firstWhere(
            (word) => word.span.end > offset,
            orElse: () => words.last,
          )
          .start;
    }
    return duration(chunk) *
        ((offset - chunk.start) / chunk.text.length).clamp(0, 1);
  }

  int offsetAt(TextChunk chunk, Duration position) {
    final words = _words[chunk.index];
    final word = words == null ? null : activeWordAt(words, position);
    if (words != null) {
      return word == null ? chunk.start : words[word].span.start;
    }
    return chunk.start +
        (chunk.text.length *
                (position.inMicroseconds / duration(chunk).inMicroseconds)
                    .clamp(0, 1))
            .floor()
            .clamp(0, chunk.text.length - 1);
  }

  Duration elapsed(int offset, {TextChunk? active, Duration? position}) {
    final target = active ?? chunkAt(offset);
    var elapsed = Duration.zero;
    for (final chunk in chunks) {
      if (chunk == target) {
        return elapsed + (position ?? localTime(chunk, offset));
      }
      elapsed += duration(chunk);
    }
    return elapsed;
  }

  int seek(Duration time) {
    var remaining = time;
    for (final chunk in chunks) {
      final length = duration(chunk);
      if (remaining < length) return offsetAt(chunk, remaining);
      remaining -= length;
    }
    return chunks.last.end - 1;
  }
}
