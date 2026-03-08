// =============================================================================
// DailyHabits - Theme Provider
//
// Manages the application's light/dark/system theme modes AND the user's
// chosen accent (primary) color.  Both preferences are persisted via
// [SharedPreferences] so they survive app restarts.
//
// Consumed by [MaterialApp] through [Provider] to drive [ThemeMode] and
// the dynamically generated [ThemeData].
//
// The accent-color palette mirrors the one in `appearance_page.dart` and
// the Django backend's allowed-color whitelist.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  ACCENT COLOR PALETTE
// =============================================================================

/// Canonical mapping of accent-color **keys** (persisted to backend and
/// SharedPreferences) to their [Color] values along with lighter/darker
/// variants for dark and light theme usage.
///
/// Add or remove entries here to extend the palette everywhere at once.
class AccentPalette {
  AccentPalette._();

  /// Primary shade for each accent key.
  static const Map<String, Color> colors = {
    'indigo': Color(0xFF4F46E5),
    'blue': Color(0xFF3B82F6),
    'teal': Color(0xFF14B8A6),
    'green': Color(0xFF22C55E),
    'amber': Color(0xFFF59E0B),
    'orange': Color(0xFFF97316),
    'rose': Color(0xFFF43F5E),
    'purple': Color(0xFF8B5CF6),
    'pink': Color(0xFFEC4899),
    'cyan': Color(0xFF06B6D4),
  };

  /// Lighter shade used in dark mode for better contrast.
  static const Map<String, Color> lightVariants = {
    'indigo': Color(0xFF6366F1),
    'blue': Color(0xFF60A5FA),
    'teal': Color(0xFF2DD4BF),
    'green': Color(0xFF4ADE80),
    'amber': Color(0xFFFBBF24),
    'orange': Color(0xFFFB923C),
    'rose': Color(0xFFFB7185),
    'purple': Color(0xFFA78BFA),
    'pink': Color(0xFFF472B6),
    'cyan': Color(0xFF22D3EE),
  };

  /// Darker shade for contrast / pressed states.
  static const Map<String, Color> darkVariants = {
    'indigo': Color(0xFF3730A3),
    'blue': Color(0xFF2563EB),
    'teal': Color(0xFF0D9488),
    'green': Color(0xFF16A34A),
    'amber': Color(0xFFD97706),
    'orange': Color(0xFFEA580C),
    'rose': Color(0xFFE11D48),
    'purple': Color(0xFF7C3AED),
    'pink': Color(0xFFDB2777),
    'cyan': Color(0xFF0891B2),
  };

  /// Fallback key used when the stored value is unrecognised.
  static const String defaultKey = 'indigo';

  /// Resolve an accent key to its primary [Color], falling back to indigo.
  static Color resolve(String key) =>
      colors[key] ?? colors[defaultKey]!;

  /// Resolve an accent key to its **light variant** [Color].
  static Color resolveLight(String key) =>
      lightVariants[key] ?? lightVariants[defaultKey]!;

  /// Resolve an accent key to its **dark variant** [Color].
  static Color resolveDark(String key) =>
      darkVariants[key] ?? darkVariants[defaultKey]!;
}

// =============================================================================
//  THEME PROVIDER
// =============================================================================

/// Manages light / dark / system theme selection **and** the user's chosen
/// accent color, with persistence via [SharedPreferences].
///
/// On construction the provider immediately loads the user's previous
/// preferences from local storage.  Widgets can listen to this provider
/// (e.g., via `Provider.of<ThemeProvider>(context)`) to reactively
/// rebuild whenever the theme or accent color changes.
///
/// ### Public API
/// - [setThemeMode]     - explicitly set a mode and persist it.
/// - [setAccentColor]   - set the accent color key and persist it.
/// - [cycleTheme]       - rotate through light -> dark -> system.
/// - [accentColor]      - the current accent [Color] (primary shade).
/// - [accentColorKey]   - the stored string key (e.g. `'blue'`).
/// - [accentColorLight] - lighter variant for dark themes.
/// - [accentColorDark]  - darker variant for emphasis.
/// - [label]            - human-readable mode name.
/// - [icon]             - representative [IconData] for the current mode.
class ThemeProvider extends ChangeNotifier {
  // -- Persistence keys -------------------------------------------------------
  static const _themeKey = 'theme_mode'; // 'light', 'dark', 'system'
  static const _accentKey = 'accent_color'; // e.g. 'blue', 'green'

  // -- Internal state ---------------------------------------------------------
  ThemeMode _themeMode = ThemeMode.system;
  String _accentColorKey = AccentPalette.defaultKey;

  // -- Getters ----------------------------------------------------------------

  /// Returns the current [ThemeMode] (light, dark, or system).
  ThemeMode get themeMode => _themeMode;

  /// The stored accent-color key (e.g. `'blue'`).
  String get accentColorKey => _accentColorKey;

  /// The resolved primary accent [Color].
  Color get accentColor => AccentPalette.resolve(_accentColorKey);

  /// Lighter accent variant - better contrast on dark surfaces.
  Color get accentColorLight => AccentPalette.resolveLight(_accentColorKey);

  /// Darker accent variant - used for active/pressed states.
  Color get accentColorDark => AccentPalette.resolveDark(_accentColorKey);

  // -- Constructor ------------------------------------------------------------

  /// Creates a [ThemeProvider] and begins loading persisted preferences.
  ThemeProvider() {
    _load();
  }

  // -- Persistence ------------------------------------------------------------

  /// Reads saved theme and accent-color preferences from [SharedPreferences].
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme mode
    final storedTheme = prefs.getString(_themeKey);
    if (storedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (storedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Accent color
    final storedColor = prefs.getString(_accentKey);
    if (storedColor != null && AccentPalette.colors.containsKey(storedColor)) {
      _accentColorKey = storedColor;
    }

    notifyListeners();
  }

  // -- Theme Mode -------------------------------------------------------------

  /// Sets the theme to [mode], notifies listeners, and persists the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_themeKey, 'light');
      case ThemeMode.dark:
        await prefs.setString(_themeKey, 'dark');
      case ThemeMode.system:
        await prefs.setString(_themeKey, 'system');
    }
  }

  /// Convenience toggle: light -> dark -> system -> light ...
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

  // -- Accent Color -----------------------------------------------------------

  /// Sets the accent color to [colorKey], notifies listeners, and persists
  /// the preference locally.
  ///
  /// If [colorKey] is not in the palette, the call is silently ignored.
  Future<void> setAccentColor(String colorKey) async {
    if (!AccentPalette.colors.containsKey(colorKey)) return;
    if (_accentColorKey == colorKey) return; // no-op if unchanged

    _accentColorKey = colorKey;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, colorKey);
  }

  // -- Display helpers --------------------------------------------------------

  /// Human-readable label for the active theme mode.
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
