import 'package:flutter/material.dart';

/// The Auri type scale.
///
/// System font only — no asset fonts and no webfont package ship with the app.
/// The identity comes from the scale: tight heavy headings against a
/// deliberately generous reading style.
///
/// [reading] is the important one. Chapter prose is the product, so it gets a
/// larger size and a 1.65 line-height rather than reusing [body]; [body] stays
/// for chrome, cards and list rows.
///
/// [mono] names generic families only (`monospace` plus per-platform
/// fallbacks). That resolves to Menlo/SF Mono on Apple, Roboto Mono on Android
/// and the browser's monospace default on web, without bundling a font.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSmall,
    required this.reading,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.mono,
    required this.numeric,
  });

  /// Screen titles and hero numbers. 34/1.1, w800.
  final TextStyle display;

  /// Chapter titles and section-defining headlines. 26/1.2, w700.
  final TextStyle headline;

  /// Card titles and section headings. 20/1.25, w700.
  final TextStyle title;

  /// Dense titles and list rows. 16/1.3, w600.
  final TextStyle titleSmall;

  /// Long-form chapter prose. 17/1.65 — the reading surface's default.
  final TextStyle reading;

  /// Chrome and card copy. 15/1.5.
  final TextStyle body;

  /// Secondary copy and captions under content. 13.5/1.45.
  final TextStyle bodySmall;

  /// Buttons, tabs and pills. 13/1.2, w600.
  final TextStyle label;

  /// Eyebrows and metadata. 11.5/1.2, w700, wide tracking.
  final TextStyle caption;

  /// Code samples. 13.5/1.55, monospace.
  final TextStyle mono;

  /// Tabular figures for counters ("Chapter 3 of 5") so digits don't jitter.
  final TextStyle numeric;

  /// Monospace families, most specific first. `monospace` is a valid generic
  /// on every target (and a valid CSS generic on web), so the list always
  /// resolves to *something* fixed-pitch.
  static const List<String> monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'DejaVu Sans Mono',
    'monospace',
  ];

  /// Builds the scale with [color] as the default ink.
  factory AppTypography.standard(Color color) {
    return AppTypography(
      display: TextStyle(
        color: color,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      headline: TextStyle(
        color: color,
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      title: TextStyle(
        color: color,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleSmall: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      reading: TextStyle(
        color: color,
        fontSize: 17,
        height: 1.65,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      ),
      body: TextStyle(
        color: color,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: color,
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.05,
      ),
      label: TextStyle(
        color: color,
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      caption: TextStyle(
        color: color,
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
      mono: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontFamilyFallback: monoFallback,
        fontSize: 13.5,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      numeric: TextStyle(
        color: color,
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  /// The Material [TextTheme] equivalent, so stock Material widgets inherit
  /// this scale instead of falling back to Roboto defaults.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display.copyWith(fontSize: 30, letterSpacing: -0.8),
    displaySmall: headline,
    headlineLarge: headline,
    headlineMedium: headline.copyWith(fontSize: 22),
    headlineSmall: title,
    titleLarge: title,
    titleMedium: titleSmall,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? reading,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? mono,
    TextStyle? numeric,
  }) {
    return AppTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      titleSmall: titleSmall ?? this.titleSmall,
      reading: reading ?? this.reading,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      mono: mono ?? this.mono,
      numeric: numeric ?? this.numeric,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      reading: TextStyle.lerp(reading, other.reading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
      numeric: TextStyle.lerp(numeric, other.numeric, t)!,
    );
  }
}
