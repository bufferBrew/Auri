import 'dart:async';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'voice_settings.dart';

/// Light, dark or system, and which colour theme. Kept in preferences.
class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings({required this.store});

  final SettingsStore store;

  static const _modeKey = 'theme_mode';
  static const _paletteKey = 'theme_palette';

  ThemeMode _themeMode = ThemeMode.system;
  AppPalette _palette = AppPalette.auri;

  ThemeMode get themeMode => _themeMode;
  AppPalette get palette => _palette;

  Future<void> load() async {
    try {
      final mode = await store.read(_modeKey);
      final palette = await store.read(_paletteKey);
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      );
      _palette = AppPalette.values.firstWhere(
        (p) => p.name == palette,
        orElse: () => AppPalette.auri,
      );
    } catch (_) {
      // Unreadable storage: keep the defaults.
    }
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
    unawaited(store.write(_modeKey, value.name));
  }

  set palette(AppPalette value) {
    if (value == _palette) return;
    _palette = value;
    notifyListeners();
    unawaited(store.write(_paletteKey, value.name));
  }
}
