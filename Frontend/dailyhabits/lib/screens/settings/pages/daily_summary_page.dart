// =============================================================================
// File: daily_summary_page.dart
// Project: DailyHabits — Settings Module
//
// Lets the user enable or disable the daily habit-progress summary
// notification and choose the preferred delivery time via a time picker.
//
// Layout:
//   • A master toggle switch for enabling/disabling daily summaries.
//   • A time-picker card (fades out when the feature is disabled).
//   • A preview banner showing what the notification will contain.
//
// Relies on [SettingsController] for state management and backend persistence.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Settings page for configuring the daily habit-progress summary notification.
///
/// When enabled, delivers a recap of completed habits, streaks, and progress
/// at the user’s chosen time. The page uses [AnimatedOpacity] and
/// [IgnorePointer] to visually and functionally disable sub-controls when
/// the master switch is off.
class DailySummaryPage extends StatelessWidget {
  const DailySummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final s = ctrl.appSettings;
    final enabled = s?.dailySummaryEnabled ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Summary'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Toggle ──────────────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile.adaptive(
              title: const Text('Daily Summary',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Receive a daily overview of your habit progress'),
              value: enabled,
              onChanged: (v) => ctrl.setDailySummaryEnabled(v),
              activeTrackColor: colors.primary,
              secondary: Icon(
                Icons.summarize,
                color: enabled ? colors.primary : colors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Time Picker ────────────────────────────────────────
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !enabled,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delivery Time',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'When youʼd like to receive your daily summary',
                        style: TextStyle(
                            fontSize: 13, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: _SummaryTimePicker(
                          value: s?.dailySummaryTime ?? '20:00',
                          onChanged: ctrl.setDailySummaryTime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Preview Banner ─────────────────────────────────────
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.08),
                    colors.primary.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: colors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Daily Recap',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          'Completed habits, streaks, and progress — delivered at ${_formatTime(s?.dailySummaryTime ?? "20:00")}',
                          style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Converts a 24-hour "HH:mm" time string to a 12-hour display format.
  ///
  /// Example: "20:00" becomes "8:00 PM".
  static String _formatTime(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 20;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }
}

// =============================================================================
//  PRIVATE WIDGETS — Time-picker component.
// =============================================================================

/// A tappable time-display widget that opens the system time picker.
///
/// Shows a clock icon, the currently selected time in large text, and a
/// “Tap to change” hint. On selection, propagates the new value via
/// [onChanged] in "HH:mm" format.
class _SummaryTimePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SummaryTimePicker({required this.value, required this.onChanged});

  /// Parses a "HH:mm" string into a [TimeOfDay].
  TimeOfDay _parse(String v) {
    final parts = v.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  /// Formats a [TimeOfDay] back into a zero-padded "HH:mm" string.
  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tod = _parse(value);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: tod,
        );
        if (picked != null) onChanged(_format(picked));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(Icons.schedule, color: colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              tod.format(context),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.primary),
            ),
            const SizedBox(height: 4),
            Text('Tap to change',
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
