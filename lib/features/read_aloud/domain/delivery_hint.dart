import 'package:flutter/foundation.dart';

import 'text_chunk.dart';

enum HintKind {
  /// Silence after the anchor.
  pause,

  /// Stress the anchor: a short beat before it, then a slower rate on it.
  emphasis,

  /// Read the anchor slower.
  slow,

  /// Say the anchor as the given IPA.
  pronounce;

  static HintKind? parse(Object? value) {
    for (final HintKind k in values) {
      if (k.name == value) return k;
    }
    return null;
  }

  String get label => switch (this) {
    pause => 'Pause',
    emphasis => 'Emphasis',
    slow => 'Slow down',
    pronounce => 'Pronounce',
  };
}

/// One delivery suggestion for a reading.
///
/// It names its place by quoted text and occurrence rather than by offset,
/// so it still lands on the right words if the server's view of the text and
/// the app's ever differ by whitespace.
@immutable
class DeliveryHint {
  const DeliveryHint({
    required this.id,
    required this.anchor,
    required this.occurrence,
    required this.kind,
    required this.amount,
    required this.ipa,
    required this.reason,
    required this.enabled,
  });

  /// Null for anything malformed, which is then simply not shown.
  static DeliveryHint? fromJson(Object? json) {
    if (json is! Map) return null;
    final HintKind? kind = HintKind.parse(json['kind']);
    final Object? id = json['id'];
    final Object? anchor = json['anchor'];
    final Object? occurrence = json['occurrence'];
    if (kind == null ||
        id is! String ||
        anchor is! String ||
        anchor.isEmpty ||
        occurrence is! int ||
        occurrence < 1) {
      return null;
    }
    return DeliveryHint(
      id: id,
      anchor: anchor,
      occurrence: occurrence,
      kind: kind,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0,
      ipa: json['ipa'] is String ? json['ipa'] as String : '',
      reason: json['reason'] is String ? json['reason'] as String : '',
      enabled: json['enabled'] == true,
    );
  }

  final String id;
  final String anchor;
  final int occurrence;
  final HintKind kind;

  /// Seconds for [HintKind.pause], speaking rate for [HintKind.slow].
  final double amount;
  final String ipa;
  final String reason;
  final bool enabled;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'anchor': anchor,
    'occurrence': occurrence,
    'kind': kind.name,
    'amount': amount,
    'ipa': ipa,
    'reason': reason,
    'enabled': enabled,
  };

  DeliveryHint withEnabled(bool value) => DeliveryHint(
    id: id,
    anchor: anchor,
    occurrence: occurrence,
    kind: kind,
    amount: amount,
    ipa: ipa,
    reason: reason,
    enabled: value,
  );

  /// What the hint does, in a few words: "Pause 0.6s", "Say /wˈɪn/".
  String get summary => switch (kind) {
    HintKind.pause => 'Pause ${_trim(amount)}s after',
    HintKind.emphasis => 'Stress',
    HintKind.slow => 'Slow to ${_trim(amount)}×',
    HintKind.pronounce => 'Say /$ipa/',
  };

  static String _trim(double n) =>
      n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A hint pinned to the characters it applies to.
@immutable
class PlacedHint {
  const PlacedHint(this.hint, this.span);

  final DeliveryHint hint;
  final BodySpan span;
}

/// Finds each hint's anchor in [body]. Hints whose anchor is not there (the
/// text was edited, or the server's count disagrees) are left out.
List<PlacedHint> placeHints(String body, List<DeliveryHint> hints) {
  final List<PlacedHint> placed = <PlacedHint>[];
  for (final DeliveryHint h in hints) {
    int at = -1;
    for (int i = 0; i < h.occurrence; i++) {
      at = body.indexOf(h.anchor, at < 0 ? 0 : at + h.anchor.length);
      if (at < 0) break;
    }
    if (at >= 0) placed.add(PlacedHint(h, BodySpan(at, at + h.anchor.length)));
  }
  placed.sort((PlacedHint a, PlacedHint b) => a.span.start - b.span.start);
  return placed;
}

/// The Kokoro input for [chunk] with the enabled hints in [placed] applied.
///
/// - pause → `[pause:Xs]` after the anchor
/// - slow → `[rate:X]anchor[rate:1]`
/// - emphasis → `[pause:0.15s][rate:0.85]anchor[rate:1]`; Kokoro has no
///   stress tag, so a beat before and a slower word is the closest it gets
/// - pronounce → `[anchor](/ipa/)`
///
/// Span hints that overlap an earlier one are skipped: rate tags do not nest,
/// and two wrappers on one word would cancel each other out. A hint that
/// crosses the chunk's edge is skipped too.
///
/// With no enabled hints this returns `chunk.text` unchanged, so turning
/// every hint off brings back exactly the audio that was cached before.
String compileChunk(TextChunk chunk, List<PlacedHint> placed) {
  final List<PlacedHint> inChunk = <PlacedHint>[
    for (final PlacedHint p in placed)
      if (p.hint.enabled &&
          p.span.start >= chunk.start &&
          p.span.end <= chunk.end)
        p,
  ];
  if (inChunk.isEmpty) return chunk.text;

  // Insertions keyed by chunk-local offset. At one offset, closing tags go
  // before pauses, which go before opening tags.
  final Map<int, List<String>> closes = <int, List<String>>{};
  final Map<int, List<String>> pauses = <int, List<String>>{};
  final Map<int, List<String>> opens = <int, List<String>>{};
  final Map<int, ({int end, String text})> replacements =
      <int, ({int end, String text})>{};
  int wrappedUntil = -1;

  void add(Map<int, List<String>> to, int at, String s) =>
      (to[at] ??= <String>[]).add(s);

  for (final PlacedHint p in inChunk) {
    final int start = p.span.start - chunk.start;
    final int end = p.span.end - chunk.start;
    final DeliveryHint h = p.hint;
    if (h.kind == HintKind.pronounce &&
        (h.ipa.isEmpty || RegExp(r'[/()\[\]\n\r]').hasMatch(h.ipa))) {
      continue;
    }

    if (h.kind == HintKind.pause) {
      add(pauses, end, ' [pause:${_num(h.amount.clamp(0.1, 2))}s] ');
      continue;
    }
    if (start < wrappedUntil) continue;
    wrappedUntil = end;

    switch (h.kind) {
      case HintKind.slow:
        add(opens, start, '[rate:${_num(h.amount.clamp(0.5, 0.99))}]');
        add(closes, end, '[rate:1]');
      case HintKind.emphasis:
        add(opens, start, '[pause:0.15s][rate:0.85]');
        add(closes, end, '[rate:1]');
      case HintKind.pronounce:
        replacements[start] = (
          end: end,
          text: '[${chunk.text.substring(start, end)}](/${h.ipa}/)',
        );
      case HintKind.pause:
        break;
    }
  }

  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i <= chunk.text.length) {
    out
      ..writeAll(closes[i] ?? const <String>[])
      ..writeAll(pauses[i] ?? const <String>[])
      ..writeAll(opens[i] ?? const <String>[]);
    if (i == chunk.text.length) break;
    final ({int end, String text})? replace = replacements[i];
    if (replace != null) {
      out.write(replace.text);
      // Tags that fall inside a replaced word would split it; drop them.
      i = replace.end;
      continue;
    }
    out.write(chunk.text[i]);
    i++;
  }
  return out.toString();
}

String _num(double n) =>
    n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
