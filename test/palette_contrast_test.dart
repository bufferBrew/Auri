import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auri/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final palette in AppPalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.label} ${brightness.name} meets WCAG AA', () {
        final c = AppColors.of(palette, brightness);
        final pairs = <String, (Color, Color)>{
          'text on background': (c.text, c.background),
          'secondary text on background': (c.textSecondary, c.background),
          'tertiary text on background': (c.textTertiary, c.background),
          'tertiary text on muted': (c.textTertiary, c.surfaceMuted),
          'strong accent on background': (c.accentStrong, c.background),
          'strong accent on surface': (c.accentStrong, c.surface),
          'strong accent on its wash': (c.accentStrong, c.accentSubtle),
          'text on accent wash': (c.text, c.accentSubtle),
          'on-accent on strong accent': (c.onAccent, c.accentStrong),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name is ${contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        }
      });
    }
  }
}
