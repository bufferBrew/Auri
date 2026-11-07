import 'package:flutter/material.dart';

/// Semantic colour tokens for Voxen.
///
/// This is the **only** file in the app allowed to contain a raw hex literal.
/// Widgets and painters read `context.colors.<token>` instead.
///
/// The identity is "study at night": a near-black ink canvas, a violet synapse
/// accent, and an amber "brew" secondary. Dark is the primary reading mode —
/// the reader is a full-bleed surface someone stares at for ten minutes — so
/// the dark set is tuned first and the light set is its daylight equivalent,
/// not an afterthought.
///
/// Contrast notes (WCAG AA, 4.5:1 for body text), all measured against the
/// surface the token actually sits on:
///  * dark [textSecondary] `#A0A7BC` → 8.0:1 on [background]; [textTertiary]
///    `#8B93AB` → 6.3:1. Do not go dimmer than tertiary.
///  * light [accent] `#6D4AE0` is 5.3:1 on [background] so it may carry text,
///    but small text and button fills use [accentStrong] `#5B37D1` (6.8:1 as
///    text, 7.2:1 against white) to keep headroom on tinted surfaces.
///  * light [secondary] `#B45309` is 4.7:1 — it is the amber *text* colour;
///    the brighter fill lives in [secondarySubtle].
///  * in dark mode `accent`/`accentStrong` and `<x>`/`<x>Text` coincide,
///    because the bright variants already clear AA on the ink canvas.
///
/// Code blocks are deliberately dark in **both** themes ([codeSurface]) — a
/// code sample should read as a different material from the prose around it,
/// and inverting it in light mode is a well-worn documentation convention.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSubtle,
    required this.onAccent,
    required this.secondary,
    required this.secondarySubtle,
    required this.onSecondary,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.dangerText,
    required this.divider,
    required this.focusRing,
    required this.scrim,
    required this.codeSurface,
    required this.codeText,
    required this.codeSecondaryText,
    required this.codeBorder,
    required this.diagramSurface,
    required this.diagramNodeFill,
    required this.diagramNodeBorder,
    required this.diagramNodeText,
    required this.diagramAccentFill,
    required this.diagramAccentBorder,
    required this.diagramAccentText,
    required this.diagramEdge,
    required this.diagramEdgeLabel,
    required this.diagramGrid,
  });

  /// Which set this is — lets a widget branch on mode without a second
  /// `Theme.of` lookup.
  final Brightness brightness;

  /// App canvas. Ink at night, cool paper by day.
  final Color background;

  /// Default card / sheet surface.
  final Color surface;

  /// Raised surface: sticky headers, dialogs, the reader's chrome.
  final Color surfaceElevated;

  /// Recessed fill for inputs, chips and inert tracks.
  final Color surfaceMuted;

  /// Brand violet. Fills, icons, large text.
  final Color accent;

  /// AA-safe violet for small text and button fills (with [onAccent]).
  final Color accentStrong;

  /// Tinted violet wash for pills, selected rows and highlight blocks.
  final Color accentSubtle;

  /// Foreground on an [accentStrong] fill.
  final Color onAccent;

  /// Amber "brew" secondary — analogies, the voiceover control.
  final Color secondary;

  /// Tinted amber wash.
  final Color secondarySubtle;

  /// Foreground on a [secondary] fill.
  final Color onSecondary;

  /// Primary body / heading ink.
  final Color text;

  /// Supporting copy. AA-safe on [background], [surface], [surfaceElevated].
  final Color textSecondary;

  /// De-emphasised metadata. Still AA-safe; the dimmest legal ink.
  final Color textTertiary;

  final Color success;
  final Color successText;
  final Color warning;
  final Color warningText;
  final Color danger;
  final Color dangerText;

  /// Hairline separators and card outlines.
  final Color divider;

  /// Keyboard-focus indicator. Deliberately not [accent] — a focus ring has to
  /// stay visible on an accent-filled surface too, so it is high-contrast ink.
  final Color focusRing;

  /// Overlay behind modal content.
  final Color scrim;

  /// Code block ground. Dark in both themes, on purpose.
  final Color codeSurface;

  /// Code block ink.
  final Color codeText;

  /// Code block metadata (language chip, caption) on [codeSurface].
  final Color codeSecondaryText;

  /// Code block outline.
  final Color codeBorder;

  /// Diagram canvas ground.
  final Color diagramSurface;

  /// Default node fill.
  final Color diagramNodeFill;

  /// Default node outline.
  final Color diagramNodeBorder;

  /// Text inside a default node.
  final Color diagramNodeText;

  /// Fill for the emphasised node (flow entry point, hierarchy root,
  /// concept-map hub, comparison header).
  final Color diagramAccentFill;

  /// Outline for the emphasised node.
  final Color diagramAccentBorder;

  /// Text on a [diagramAccentFill].
  final Color diagramAccentText;

  /// Connector strokes and arrowheads.
  final Color diagramEdge;

  /// Text on an edge label chip.
  final Color diagramEdgeLabel;

  /// Table rules, timeline axis, and other structural lines.
  final Color diagramGrid;

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0B0D12),
    surface: Color(0xFF14171F),
    surfaceElevated: Color(0xFF1B1F2A),
    surfaceMuted: Color(0xFF212635),
    accent: Color(0xFFA78BFA),
    accentStrong: Color(0xFFA78BFA),
    accentSubtle: Color(0xFF251E3D),
    onAccent: Color(0xFF0B0D12),
    secondary: Color(0xFFFBBF24),
    secondarySubtle: Color(0xFF33260A),
    onSecondary: Color(0xFF0B0D12),
    text: Color(0xFFE8EAF2),
    textSecondary: Color(0xFFA0A7BC),
    textTertiary: Color(0xFF8B93AB),
    success: Color(0xFF4ADE80),
    successText: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    dangerText: Color(0xFFF87171),
    divider: Color(0xFF242938),
    focusRing: Color(0xFFE8EAF2),
    scrim: Color(0xB3000000),
    codeSurface: Color(0xFF10141C),
    codeText: Color(0xFFD6DEEC),
    codeSecondaryText: Color(0xFF98A2B8),
    codeBorder: Color(0xFF242938),
    diagramSurface: Color(0xFF12151D),
    diagramNodeFill: Color(0xFF1E2331),
    diagramNodeBorder: Color(0xFF333A4E),
    diagramNodeText: Color(0xFFE8EAF2),
    diagramAccentFill: Color(0xFF3A2C6B),
    diagramAccentBorder: Color(0xFFA78BFA),
    diagramAccentText: Color(0xFFDDD3FF),
    diagramEdge: Color(0xFF6B7490),
    diagramEdgeLabel: Color(0xFFA0A7BC),
    diagramGrid: Color(0xFF2A3040),
  );

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDEEF5),
    accent: Color(0xFF6D4AE0),
    accentStrong: Color(0xFF5B37D1),
    accentSubtle: Color(0xFFEDE7FE),
    onAccent: Color(0xFFFFFFFF),
    secondary: Color(0xFFB45309),
    secondarySubtle: Color(0xFFFDF0DC),
    onSecondary: Color(0xFFFFFFFF),
    text: Color(0xFF14161D),
    textSecondary: Color(0xFF545B6E),
    textTertiary: Color(0xFF656C81),
    success: Color(0xFF0E9F6E),
    successText: Color(0xFF077A54),
    warning: Color(0xFFC2620A),
    warningText: Color(0xFF9A4E08),
    danger: Color(0xFFDC2626),
    dangerText: Color(0xFFB91C1C),
    divider: Color(0xFFE3E5EF),
    focusRing: Color(0xFF14161D),
    scrim: Color(0x7314161D),
    codeSurface: Color(0xFF1B1E28),
    codeText: Color(0xFFE4E8F2),
    codeSecondaryText: Color(0xFFA6AEC4),
    codeBorder: Color(0xFF2B3040),
    diagramSurface: Color(0xFFFFFFFF),
    diagramNodeFill: Color(0xFFF2F3FA),
    diagramNodeBorder: Color(0xFFD4D8E8),
    diagramNodeText: Color(0xFF14161D),
    diagramAccentFill: Color(0xFFEDE7FE),
    diagramAccentBorder: Color(0xFF6D4AE0),
    diagramAccentText: Color(0xFF4C2CB8),
    diagramEdge: Color(0xFF7A8199),
    diagramEdgeLabel: Color(0xFF545B6E),
    diagramGrid: Color(0xFFE3E5EF),
  );

  bool get isDark => brightness == Brightness.dark;

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSubtle,
    Color? onAccent,
    Color? secondary,
    Color? secondarySubtle,
    Color? onSecondary,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successText,
    Color? warning,
    Color? warningText,
    Color? danger,
    Color? dangerText,
    Color? divider,
    Color? focusRing,
    Color? scrim,
    Color? codeSurface,
    Color? codeText,
    Color? codeSecondaryText,
    Color? codeBorder,
    Color? diagramSurface,
    Color? diagramNodeFill,
    Color? diagramNodeBorder,
    Color? diagramNodeText,
    Color? diagramAccentFill,
    Color? diagramAccentBorder,
    Color? diagramAccentText,
    Color? diagramEdge,
    Color? diagramEdgeLabel,
    Color? diagramGrid,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      secondary: secondary ?? this.secondary,
      secondarySubtle: secondarySubtle ?? this.secondarySubtle,
      onSecondary: onSecondary ?? this.onSecondary,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      divider: divider ?? this.divider,
      focusRing: focusRing ?? this.focusRing,
      scrim: scrim ?? this.scrim,
      codeSurface: codeSurface ?? this.codeSurface,
      codeText: codeText ?? this.codeText,
      codeSecondaryText: codeSecondaryText ?? this.codeSecondaryText,
      codeBorder: codeBorder ?? this.codeBorder,
      diagramSurface: diagramSurface ?? this.diagramSurface,
      diagramNodeFill: diagramNodeFill ?? this.diagramNodeFill,
      diagramNodeBorder: diagramNodeBorder ?? this.diagramNodeBorder,
      diagramNodeText: diagramNodeText ?? this.diagramNodeText,
      diagramAccentFill: diagramAccentFill ?? this.diagramAccentFill,
      diagramAccentBorder: diagramAccentBorder ?? this.diagramAccentBorder,
      diagramAccentText: diagramAccentText ?? this.diagramAccentText,
      diagramEdge: diagramEdge ?? this.diagramEdge,
      diagramEdgeLabel: diagramEdgeLabel ?? this.diagramEdgeLabel,
      diagramGrid: diagramGrid ?? this.diagramGrid,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondarySubtle: Color.lerp(secondarySubtle, other.secondarySubtle, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      codeSurface: Color.lerp(codeSurface, other.codeSurface, t)!,
      codeText: Color.lerp(codeText, other.codeText, t)!,
      codeSecondaryText: Color.lerp(
        codeSecondaryText,
        other.codeSecondaryText,
        t,
      )!,
      codeBorder: Color.lerp(codeBorder, other.codeBorder, t)!,
      diagramSurface: Color.lerp(diagramSurface, other.diagramSurface, t)!,
      diagramNodeFill: Color.lerp(diagramNodeFill, other.diagramNodeFill, t)!,
      diagramNodeBorder: Color.lerp(
        diagramNodeBorder,
        other.diagramNodeBorder,
        t,
      )!,
      diagramNodeText: Color.lerp(diagramNodeText, other.diagramNodeText, t)!,
      diagramAccentFill: Color.lerp(
        diagramAccentFill,
        other.diagramAccentFill,
        t,
      )!,
      diagramAccentBorder: Color.lerp(
        diagramAccentBorder,
        other.diagramAccentBorder,
        t,
      )!,
      diagramAccentText: Color.lerp(
        diagramAccentText,
        other.diagramAccentText,
        t,
      )!,
      diagramEdge: Color.lerp(diagramEdge, other.diagramEdge, t)!,
      diagramEdgeLabel: Color.lerp(
        diagramEdgeLabel,
        other.diagramEdgeLabel,
        t,
      )!,
      diagramGrid: Color.lerp(diagramGrid, other.diagramGrid, t)!,
    );
  }
}
