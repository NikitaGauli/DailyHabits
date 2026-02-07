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

class ThemeColors {
  final Brightness brightness;
  const ThemeColors._(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  // ── Brand ──────────────────────────────────────────────────────────────
  Color get primary => isDark ? AppColors.primaryLight : AppColors.primary;
  Color get primaryLight => AppColors.primaryLight;
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

extension ThemeColorsExtension on BuildContext {
  ThemeColors get colors => ThemeColors._(Theme.of(this).brightness);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ═════════════════════════════════════════════════════════════════════════════
//  SPACING TOKENS
// ═════════════════════════════════════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ═════════════════════════════════════════════════════════════════════════════
//  BORDER RADIUS
// ═════════════════════════════════════════════════════════════════════════════

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHADOWS
// ═════════════════════════════════════════════════════════════════════════════

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(BuildContext context) => [
        BoxShadow(
          color: context.isDarkMode
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> card(BuildContext context) => [
        BoxShadow(
          color: context.isDarkMode
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

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

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  THEME DATA
// ═════════════════════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  // ── LIGHT THEME ────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.primary,
      fontFamily: 'Inter',

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
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

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle:
            AppTextStyles.label.copyWith(color: AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: const BorderSide(color: AppColors.lightBorder),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.secondary;
          return AppColors.lightTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary.withValues(alpha: 0.3);
          }
          return AppColors.lightBorder;
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: AppColors.lightSurfaceVariant,
      ),
    );
  }

  // ── DARK THEME ─────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.primary,
      fontFamily: 'Inter',

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
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

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
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
          backgroundColor: AppColors.primaryLight,
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
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
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
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
        labelStyle:
            AppTextStyles.label.copyWith(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: const BorderSide(color: AppColors.darkBorder),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryLight;
          }
          return AppColors.darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryLight.withValues(alpha: 0.3);
          }
          return AppColors.darkBorder;
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondaryLight,
        linearTrackColor: AppColors.darkSurfaceVariant,
      ),
    );
  }
}
