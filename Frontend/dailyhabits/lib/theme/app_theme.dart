/// DailyHabits – Unified Design System
///
/// ── Productivity Color Palette ──
///   Primary:    #4F46E5  (Deep Indigo)   – AppBar, buttons, active nav
///   Secondary:  #14B8A6  (Soft Teal)     – Progress bars, toggles, highlights
///   Background: #F8FAFC  (Near-White)    – Scaffold background
///   Card:       #FFFFFF  (White)         – Card surfaces
///   Text 1:     #1F2933  (Dark Charcoal) – Primary text
///   Text 2:     #6B7280  (Gray)          – Secondary text
///   Success:    #22C55E  (Green)         – Completed habits, checks, streaks
///   Warning:    #F59E0B  (Amber)         – Warnings, skipped
///   Error:      #EF4444  (Red)           – Errors, missed
///
/// Theme-aware access:  `context.colors.primary`, `context.colors.secondary` …

library;

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  COLOUR CONSTANTS
// ═════════════════════════════════════════════════════════════════════════════

/// Centralized color constants for the DailyHabits design system.
///
/// All color values are defined as static constants so they can be used in
/// `const` contexts (e.g., [ColorScheme] construction).  For theme-aware
/// access at runtime, prefer [ThemeColors] via `context.colors`.
///
/// The palette is organized into logical groups:
/// - **Brand** — primary & secondary brand colors with light/dark variants.
/// - **Surfaces** — background and card fills for each brightness.
/// - **Borders** — subtle dividers and outlines.
/// - **Text** — three tiers of text emphasis per brightness.
/// - **Semantic** — success, warning, error, and info feedback colors.
/// - **Category** — pre-assigned habit-category tints.
/// - **Gradients** — reusable [LinearGradient] definitions.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5); // Deep Indigo
  static const Color primaryLight = Color(0xFF6366F1); // Lighter variant
  static const Color primaryDark = Color(0xFF3730A3); // Darker variant
  static const Color secondary = Color(0xFF14B8A6); // Soft Teal
  static const Color secondaryLight = Color(0xFF2DD4BF);
  static const Color secondaryDark = Color(0xFF0D9488);

  // ── Light Theme Surfaces ──────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);

  // ── Dark Theme Surfaces ───────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);

  // ── Borders ────────────────────────────────────────────────────────────
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color darkBorder = Color(0xFF475569);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF1F2933);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Category Palette ──────────────────────────────────────────────────
  static const Color categoryHealth = Color(0xFF22C55E);
  static const Color categoryFitness = Color(0xFFEF4444);
  static const Color categoryStudy = Color(0xFF3B82F6);
  static const Color categoryMindfulness = Color(0xFF8B5CF6);
  static const Color categoryProductivity = Color(0xFFF59E0B);
  static const Color categoryCreativity = Color(0xFFF97316);
  static const Color categorySocial = Color(0xFF06B6D4);
  static const Color categoryCustom = Color(0xFF6B7280);

  // ── Legacy Compat Aliases ─────────────────────────────────────────────
  static const Color accent = primary;
  static const Color accentLight = primaryLight;
  static const Color accentSecondary = secondary;
  static const Color accentTertiary = warning;
  static const Color accentDark = primaryDark;
  static const Color primaryBg = lightBg;
  static const Color secondaryBg = lightSurface;
  static const Color glassSurface = darkSurface;
  static const Color alert = error;
  static const Color alertDark = Color(0xFFDC2626);
  static const Color alertLight = Color(0xFFFEE2E2);
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = primaryGradient;

  static const LinearGradient lightBgGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradient = lightBgGradient;
}

// ═════════════════════════════════════════════════════════════════════════════
//  THEME-AWARE COLOUR ACCESS — usage: context.colors.primary
// ═════════════════════════════════════════════════════════════════════════════

/// Brightness-aware color accessor that resolves to light or dark variants.
///
/// Instantiated internally via [ThemeColorsExtension]. Consumers should
/// access it through `context.colors` — for example:
///
/// ```dart
/// final bg = context.colors.bg;
/// final text = context.colors.textPrimary;
/// ```
///
/// Every getter selects between the appropriate light/dark constant from
/// [AppColors] based on the current [Brightness].
class ThemeColors {
  /// The current theme brightness used to resolve color variants.
  final Brightness brightness;

  /// The active primary (accent) color injected by [ThemeProvider].
  /// Falls back to [AppColors.primary] when no override is present.
  final Color _primary;

  /// The light variant of the active primary color.
  final Color _primaryLight;

  const ThemeColors._(
    this.brightness, {
    Color? primary,
    Color? primaryLight,
  })  : _primary = primary ?? AppColors.primary,
        _primaryLight = primaryLight ?? AppColors.primaryLight;

  /// Whether the current theme is dark.
  bool get isDark => brightness == Brightness.dark;

  // ── Brand ──────────────────────────────────────────────────────────

  /// Primary brand color - uses the user-selected accent color.
  Color get primary => isDark ? _primaryLight : _primary;
  Color get primaryLight => _primaryLight;
  Color get secondary => isDark ? AppColors.secondaryLight : AppColors.secondary;
  Color get secondaryLight => AppColors.secondaryLight;

  // ── Surfaces ───────────────────────────────────────────────────────────
  Color get bg => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get surfaceVariant =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

  // ── Borders ────────────────────────────────────────────────────────────
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get divider => isDark
      ? AppColors.darkBorder.withValues(alpha: 0.5)
      : AppColors.lightBorder;

  // ── Text ───────────────────────────────────────────────────────────────
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  Color get textOnPrimary => const Color(0xFFFFFFFF);

  // ── Semantic ───────────────────────────────────────────────────────────
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;

  // ── Accent (alias → primary for backward compat) ──────────────────────
  Color get accent => primary;

  // ── Gradients ──────────────────────────────────────────────────────────
  LinearGradient get bgGradient =>
      isDark ? AppColors.darkBgGradient : AppColors.lightBgGradient;

  // ── Input Fields ───────────────────────────────────────────────────────
  Color get inputFill =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
  Color get inputBorder => border;

  // ── Overlays ───────────────────────────────────────────────────────────
  Color get scrim => isDark
      ? Colors.black.withValues(alpha: 0.6)
      : Colors.black.withValues(alpha: 0.3);
  Color get shimmer => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);
}

/// Convenience [BuildContext] extension that exposes theme-aware colors
/// and a quick dark-mode check.
///
/// Usage:
/// ```dart
/// final cardColor = context.colors.card;
/// if (context.isDarkMode) { /* … */ }
/// ```
extension ThemeColorsExtension on BuildContext {
  /// Returns a [ThemeColors] instance matching the current [Brightness]
  /// and the active primary color from [ColorScheme].
  ThemeColors get colors {
    final theme = Theme.of(this);
    final cs = theme.colorScheme;
    return ThemeColors._(
      theme.brightness,
      primary: cs.primary,
      primaryLight: cs.primary, // already light-adjusted in dark theme
    );
  }

  /// `true` when the active theme brightness is [Brightness.dark].
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ═════════════════════════════════════════════════════════════════════════════
//  SPACING TOKENS
// ═════════════════════════════════════════════════════════════════════════════

/// Standardized spacing tokens used for padding, margins, and gaps.
///
/// Based on a 4-px grid to maintain consistent vertical and horizontal
/// rhythm across every screen.
class AppSpacing {
  AppSpacing._();

  /// 4 px — minimal inner padding.
  static const double xs = 4;

  /// 8 px — tight spacing between related elements.
  static const double sm = 8;

  /// 12 px — default compact spacing.
  static const double md = 12;

  /// 16 px — standard content separation.
  static const double lg = 16;

  /// 24 px — generous section spacing.
  static const double xl = 24;

  /// 32 px — large section or screen-level spacing.
  static const double xxl = 32;
}

// ═════════════════════════════════════════════════════════════════════════════
//  BORDER RADIUS
// ═════════════════════════════════════════════════════════════════════════════

/// Uniform border-radius tokens used across cards, buttons, and inputs.
///
/// Raw [double] values are provided for one-off use, along with pre-built
/// [BorderRadius] constants (e.g., [smAll], [mdAll]) for convenience.
class AppRadius {
  AppRadius._();

  /// 8 px — subtle rounding (chips, tags).
  static const double sm = 8;

  /// 12 px — default input / button rounding.
  static const double md = 12;

  /// 16 px — card-level rounding.
  static const double lg = 16;

  /// 24 px — large container rounding.
  static const double xl = 24;

  /// 32 px — pill / sheet rounding.
  static const double xxl = 32;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHADOWS
// ═════════════════════════════════════════════════════════════════════════════

/// Pre-defined elevation shadows for the DailyHabits design system.
///
/// Each factory returns a `List<BoxShadow>` suitable for [BoxDecoration].
/// Context-aware variants automatically adjust opacity for dark mode.
class AppShadows {
  AppShadows._();

  /// A soft, context-aware shadow ideal for floating containers.
  ///
  /// Opacity is automatically reduced in dark mode to avoid
  /// overly harsh elevation on dark surfaces.
  static List<BoxShadow> soft(BuildContext context) => [
        BoxShadow(
          color: context.isDarkMode
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Dark-only variant of [soft] — useful when no [BuildContext] is
  /// available (e.g., static decoration within initState).
  static List<BoxShadow> get softDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Subtle card-level shadow that adapts to the current brightness.
  static List<BoxShadow> card(BuildContext context) => [
        BoxShadow(
          color: context.isDarkMode
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// A colored glow effect using the primary brand color.
  ///
  /// Best suited for CTAs and FABs that need to "pop" off the surface.
  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
      ];
}

// ═════════════════════════════════════════════════════════════════════════════
//  TEXT STYLES (base shapes — colour inherited from ThemeData)
// ═════════════════════════════════════════════════════════════════════════════

/// Base typographic styles for the DailyHabits design system.
///
/// These styles define **shape only** (size, weight, letter-spacing, height).
/// Colors are intentionally omitted so they inherit from the active
/// [ThemeData.textTheme], allowing automatic light/dark adaptation.
class AppTextStyles {
  AppTextStyles._();

  /// Headline 1 — 28 px, bold, tight letter-spacing.
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Headline 2 — 24 px, semi-bold.
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  /// Headline 3 — 20 px, semi-bold.
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  /// Large body text — 16 px, regular weight, relaxed line-height.
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Medium body text — 14 px, regular weight, relaxed line-height.
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Button label — 16 px, semi-bold with subtle letter-spacing.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// Label — 12 px, medium weight, wide letter-spacing (chips, tags).
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  /// Caption — 12 px, regular weight (timestamps, footnotes).
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  THEME DATA
// ═════════════════════════════════════════════════════════════════════════════

/// Application-level [ThemeData] factory for both light and dark modes.
///
/// Each method returns a fully configured [ThemeData] using the tokens
/// defined in [AppColors], [AppTextStyles], and [AppRadius].  These are
/// consumed by [MaterialApp.theme] and [MaterialApp.darkTheme].
///
/// The [accent] / [accentLight] parameters allow the user's chosen color
/// preference to be injected at build-time so that every Material widget
/// (AppBar, buttons, FABs, chips, switches, progress indicators) picks up
/// the selected accent automatically.
class AppTheme {
  AppTheme._();

  // -- LIGHT THEME ----------------------------------------------------------

  /// Returns the complete [ThemeData] for **light** mode.
  ///
  /// [accent] overrides the primary brand color.  Defaults to
  /// [AppColors.primary] (deep indigo) when omitted.
  static ThemeData lightTheme({
    Color accent = AppColors.primary,
    Color accentLight = AppColors.primaryLight,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: accent,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: const Color(0xFFFFFFFF),
        onSecondary: const Color(0xFFFFFFFF),
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.h3.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.lightTextMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle:
            AppTextStyles.bodyMd.copyWith(color: AppColors.lightTextMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: accent.withValues(alpha: 0.12),
        labelStyle:
            AppTextStyles.label.copyWith(color: AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: const BorderSide(color: AppColors.lightBorder),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return AppColors.lightTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return AppColors.lightBorder;
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppColors.lightSurfaceVariant,
      ),
    );
  }

  // -- DARK THEME -----------------------------------------------------------

  /// Returns the complete [ThemeData] for **dark** mode.
  ///
  /// [accent] overrides the primary brand color.  Defaults to
  /// [AppColors.primaryLight] when omitted.
  static ThemeData darkTheme({
    Color accent = AppColors.primaryLight,
    Color accentDark = AppColors.primary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: accent,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: AppColors.secondaryLight,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: const Color(0xFFFFFFFF),
        onSecondary: const Color(0xFFFFFFFF),
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.h3.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.darkTextMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.darkBorder.withValues(alpha: 0.5),
        thickness: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: AppColors.darkBorder.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle:
            AppTextStyles.bodyMd.copyWith(color: AppColors.darkTextMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: accent.withValues(alpha: 0.2),
        labelStyle:
            AppTextStyles.label.copyWith(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: const BorderSide(color: AppColors.darkBorder),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return AppColors.darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return AppColors.darkBorder;
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppColors.darkSurfaceVariant,
      ),
    );
  }
}
