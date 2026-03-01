// =============================================================================
// File: appearance_page.dart
// Project: DailyHabits — Settings Module
//
// Provides the user interface for customizing the visual appearance of the
// application. Users can:
//   • Switch between light, dark, and system theme modes.
//   • Choose an accent color from a curated palette of 10 colors.
//   • Toggle UI animations (transitions and micro-interactions) on/off.
//
// Theme changes are coordinated between [ThemeProvider] (for immediate local
// theming) and [SettingsController] (for backend persistence).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_provider.dart';
import '../settings_controller.dart';

/// Settings page for customizing the app’s visual appearance.
///
/// Displays three card sections:
///   1. **Theme** — Light / Dark / System radio-style options.
///   2. **Accent Color** — A color-circle palette selection.
///   3. **Animations** — A single switch toggle.
///
/// Reads state from both [ThemeProvider] and [SettingsController] via Provider.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final themeProvider = context.watch<ThemeProvider>();
    final colors = context.colors;
    final settings = ctrl.appSettings;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme Mode ──────────────────────────────────────────
          _CardSection(
            title: 'Theme',
            child: Column(
              children: [
                _ThemeOption(
                  title: 'Light',
                  icon: Icons.light_mode,
                  selected: themeProvider.themeMode == ThemeMode.light,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.light);
                    ctrl.setTheme('light');
                  },
                ),
                _ThemeOption(
                  title: 'Dark',
                  icon: Icons.dark_mode,
                  selected: themeProvider.themeMode == ThemeMode.dark,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.dark);
                    ctrl.setTheme('dark');
                  },
                ),
                _ThemeOption(
                  title: 'System',
                  icon: Icons.settings_brightness,
                  selected: themeProvider.themeMode == ThemeMode.system,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.system);
                    ctrl.setTheme('system');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Accent Color ────────────────────────────────────────
          _CardSection(
            title: 'Accent Color',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _accentColors.entries.map((entry) {
                final selected =
                    (settings?.accentColor ?? 'indigo') == entry.key;
                return GestureDetector(
                  onTap: () => ctrl.setAccentColor(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: colors.textPrimary, width: 3)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: entry.value.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Animations ──────────────────────────────────────────
          _CardSection(
            title: 'Animations',
            child: SwitchListTile.adaptive(
              title: const Text('Enable animations'),
              subtitle: const Text('Smooth transitions and micro-interactions'),
              value: settings?.animationsEnabled ?? true,
              onChanged: (v) => ctrl.setAnimationsEnabled(v),
              activeTrackColor: colors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Map of accent-color keys to their [Color] values.
  ///
  /// The key is persisted to the backend and used to look up the active color.
  static final Map<String, Color> _accentColors = {
    'indigo': const Color(0xFF4F46E5),
    'blue': const Color(0xFF3B82F6),
    'teal': const Color(0xFF14B8A6),
    'green': const Color(0xFF22C55E),
    'amber': const Color(0xFFF59E0B),
    'orange': const Color(0xFFF97316),
    'rose': const Color(0xFFF43F5E),
    'purple': const Color(0xFF8B5CF6),
    'pink': const Color(0xFFEC4899),
    'cyan': const Color(0xFF06B6D4),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS — Card layout and theme-option row.
// ═════════════════════════════════════════════════════════════════════════

/// A reusable card with a bold title and a child body.
///
/// Used throughout the appearance page to group related controls
/// (theme options, accent colors, animation toggle) inside elevated cards.
class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A single row representing one theme option (Light / Dark / System).
///
/// Shows an icon on the left and the theme name. When [selected] is true,
/// both the text and icon adopt the primary color, and a check-circle icon
/// appears on the trailing edge.
class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? colors.primary : colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? colors.primary : colors.textPrimary,
                  )),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
