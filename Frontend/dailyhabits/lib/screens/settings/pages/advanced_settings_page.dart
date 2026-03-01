import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Advanced settings page — language, week start, analytics, AI, haptics,
/// auto-archive, and default habit visibility.
class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'pt': 'Português',
    'ar': 'العربية',
    'hi': 'हिन्दी',
  };

  static const _weekDays = <String, String>{
    'monday': 'Monday',
    'sunday': 'Sunday',
    'saturday': 'Saturday',
  };

  static const _archiveOptions = <int>[0, 7, 14, 30, 60, 90];

  static const _visibilityOptions = <String, String>{
    'private': 'Private',
    'friends': 'Friends Only',
    'public': 'Public',
  };

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final settings = ctrl.appSettings;
    final colors = context.colors;

    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Advanced'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Localization ──────────────────────────────────
          _SectionTitle(icon: Icons.language, title: 'Localization'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DropdownRow(
                    label: 'Language',
                    value: settings.language,
                    items: _languages,
                    onChanged: (v) => ctrl.setLanguage(v!),
                  ),
                  const Divider(height: 24),
                  _DropdownRow(
                    label: 'Week Starts On',
                    value: settings.weekStartDay,
                    items: _weekDays,
                    onChanged: (v) => ctrl.setWeekStartDay(v!),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Data & Privacy ────────────────────────────────
          _SectionTitle(icon: Icons.analytics_outlined, title: 'Data & Privacy'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SwitchRow(
                    label: 'Analytics Consent',
                    subtitle: 'Allow anonymized usage data to improve the app',
                    value: settings.analyticsConsent,
                    onChanged: (v) => ctrl.setAnalyticsConsent(v),
                  ),
                  const Divider(height: 24),
                  _SwitchRow(
                    label: 'AI Personalization',
                    subtitle: 'Use AI to tailor insights and recommendations',
                    value: settings.aiPersonalization,
                    onChanged: (v) => ctrl.setAiPersonalization(v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Interaction ───────────────────────────────────
          _SectionTitle(icon: Icons.touch_app_outlined, title: 'Interaction'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SwitchRow(
                    label: 'Haptic Feedback',
                    subtitle: 'Vibrate on habit completions and actions',
                    value: settings.hapticFeedback,
                    onChanged: (v) => ctrl.setHapticFeedback(v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Habit Defaults ────────────────────────────────
          _SectionTitle(icon: Icons.checklist_outlined, title: 'Habit Defaults'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DropdownRow(
                    label: 'Default Visibility',
                    value: settings.defaultHabitVisibility,
                    items: _visibilityOptions,
                    onChanged: (v) => ctrl.setDefaultHabitVisibility(v!),
                  ),
                  const Divider(height: 24),
                  _AutoArchiveRow(
                    value: settings.autoArchiveDays,
                    onChanged: (v) => ctrl.setAutoArchiveDays(v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Info footer ───────────────────────────────────
          Center(
            child: Text(
              'Changes are saved automatically',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ───────────────────────── Shared widgets ─────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary)),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: colors.textPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: colors.textPrimary)),
        ),
        DropdownButton<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          underline: const SizedBox.shrink(),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AutoArchiveRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AutoArchiveRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Auto-Archive Habits', style: TextStyle(color: colors.textPrimary)),
              Text('Archive inactive habits after a period',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
        ),
        DropdownButton<int>(
          value: AdvancedSettingsPage._archiveOptions.contains(value)
              ? value
              : 0,
          underline: const SizedBox.shrink(),
          items: AdvancedSettingsPage._archiveOptions
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d == 0 ? 'Never' : '$d days'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
