import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Auri's theme.
///
/// The real design system lives in the [ThemeExtension]s ([AppColors],
/// [AppTypography]) — widgets read `context.colors.surface` rather than
/// `Theme.of(context).colorScheme.surface`. The [ColorScheme] below exists so
/// stock Material widgets (dialogs, snackbars, text selection) inherit the
/// same palette instead of Material purple.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light => of(AppPalette.auri, Brightness.light);

  static ThemeData get dark => of(AppPalette.auri, Brightness.dark);

  static ThemeData of(AppPalette palette, Brightness brightness) =>
      _build(AppColors.of(palette, brightness));

  static ThemeData _build(AppColors colors) {
    final AppTypography typography = AppTypography.standard(colors.text);
    final ColorScheme scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.accentStrong,
      onPrimary: colors.onAccent,
      primaryContainer: colors.accentSubtle,
      onPrimaryContainer: colors.accentStrong,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.secondarySubtle,
      onSecondaryContainer: colors.secondary,
      surface: colors.surface,
      onSurface: colors.text,
      surfaceContainerHighest: colors.surfaceMuted,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.divider,
      outlineVariant: colors.divider,
      error: colors.danger,
      onError: colors.isDark ? colors.background : const Color(0xFFFFFFFF),
      errorContainer: colors.danger.withValues(alpha: 0.14),
      onErrorContainer: colors.dangerText,
      scrim: colors.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      textTheme: typography.toTextTheme(),
      extensions: <ThemeExtension<Object?>>[colors, typography],
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.title,
        systemOverlayStyle: colors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: typography.title,
        contentTextStyle: typography.body.copyWith(color: colors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.isDark ? colors.surfaceMuted : colors.text,
        contentTextStyle: typography.body.copyWith(
          color: colors.isDark ? colors.text : const Color(0xFFFFFFFF),
        ),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceMuted,
        hintStyle: typography.body.copyWith(color: colors.textTertiary),
        labelStyle: typography.label.copyWith(color: colors.textSecondary),
        floatingLabelStyle: typography.label.copyWith(
          color: colors.accentStrong,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.accentStrong, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
        errorStyle: typography.bodySmall.copyWith(color: colors.dangerText),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        selectedColor: colors.accentSubtle,
        side: BorderSide(color: colors.divider),
        labelStyle: typography.label,
        shape: AppRadius.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentStrong,
        linearTrackColor: colors.surfaceMuted,
        circularTrackColor: colors.surfaceMuted,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentStrong,
        selectionColor: colors.accent.withValues(alpha: 0.3),
        selectionHandleColor: colors.accentStrong,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentStrong,
          textStyle: typography.label,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accentStrong,
          foregroundColor: colors.onAccent,
          elevation: 0,
          textStyle: typography.label,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.pill,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentStrong,
          foregroundColor: colors.onAccent,
          elevation: 0,
          textStyle: typography.label,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.divider),
          textStyle: typography.label,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: AppRadius.pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.text,
        titleTextStyle: typography.titleSmall,
        subtitleTextStyle: typography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: colors.scrim,
        showDragHandle: true,
        dragHandleColor: colors.textTertiary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.accentSubtle,
          selectedForegroundColor: colors.accentStrong,
          foregroundColor: colors.textSecondary,
          side: BorderSide(color: colors.divider),
          textStyle: typography.label,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: colors.divider)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accentStrong,
        inactiveTrackColor: colors.surfaceMuted,
        thumbColor: colors.accentStrong,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.isDark ? colors.surfaceMuted : colors.text,
          borderRadius: AppRadius.xsAll,
        ),
        textStyle: typography.bodySmall.copyWith(
          color: colors.isDark ? colors.text : const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

/// Sugar for reading the design system off the element tree:
/// `context.colors.accent`, `context.typography.reading`.
///
/// Falls back to the **dark** token set when no theme extension is installed
/// (a bare `MaterialApp` in a widget test, say) because dark is Auri's
/// primary mode — nothing ever crashes on a missing extension.
extension AppThemeContext on BuildContext {
  ThemeData get _theme => Theme.of(this);

  AppColors get colors => _theme.extension<AppColors>() ?? AppColors.dark;

  AppTypography get typography =>
      _theme.extension<AppTypography>() ??
      AppTypography.standard(AppColors.dark.text);

  bool get isDarkMode => _theme.brightness == Brightness.dark;

  /// Viewport width — the input to every responsive rule.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isCompact => AppBreakpoints.isCompact(screenWidth);

  /// True when the user has asked the platform to reduce motion.
  bool get reduceMotion => AppMotion.reduced(this);
}
