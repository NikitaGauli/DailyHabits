// DailyHabits — Theme Provider
//
// Manages the application’s light, dark, and system theme modes with
// automatic persistence via [SharedPreferences].  Exposes a [ChangeNotifier]
// so that the entire widget tree rebuilds whenever the user switches themes.
//
// Consumed by [MaterialApp] through [Provider] to drive [ThemeMode].

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages light / dark / system theme selection with persistence.
///
/// On construction the provider immediately loads the user’s previous
/// preference from local storage.  Widgets can listen to this provider
/// (e.g., via `Provider.of<ThemeProvider>(context)`) to reactively
/// rebuild whenever the theme changes.
///
/// ### Public API
/// - [setThemeMode] — explicitly set a mode and persist it.
/// - [cycleTheme]   — rotate through light → dark → system.
/// - [label]        — human-readable mode name.
/// - [icon]         — representative [IconData] for the current mode.
class ThemeProvider extends ChangeNotifier {
  /// SharedPreferences key under which the theme preference is stored.
  static const _key = 'theme_mode'; // 'light', 'dark', 'system'

  /// The currently active [ThemeMode].
  ThemeMode _themeMode = ThemeMode.system;

  /// Returns the current [ThemeMode] (light, dark, or system).
  ThemeMode get themeMode => _themeMode;

  /// Creates a [ThemeProvider] and begins loading the persisted preference.
  ThemeProvider() {
    _load();
  }

  /// Reads the saved theme preference from [SharedPreferences].
  ///
  /// Falls back to [ThemeMode.system] if no value has been stored yet.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      _themeMode = ThemeMode.light;
    } else if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Sets the theme to [mode], notifies listeners, and persists the choice.
  ///
  /// Callers may pass any [ThemeMode] value.  The string representation
  /// (`'light'` / `'dark'` / `'system'`) is written to local storage so
  /// the preference survives app restarts.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
      case ThemeMode.system:
        await prefs.setString(_key, 'system');
    }
  }

  /// Convenience toggle: light → dark → system → light …
  Future<void> cycleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
    }
  }

  /// Human-readable label for the active mode, suitable for UI display.
  String get label {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Material icon representing the current theme mode.
  ///
  /// - Light  → [Icons.light_mode_rounded]
  /// - Dark   → [Icons.dark_mode_rounded]
  /// - System → [Icons.brightness_auto_rounded]
  IconData get icon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }
}
