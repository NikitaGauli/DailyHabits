// =============================================================================
// File: quiet_hours_page.dart
// Project: DailyHabits — Settings Module
//
// Configures the “Quiet Hours” feature, which mutes all push notifications
// during a user-defined time window. Supports:
//   • A master toggle to enable or disable quiet hours.
//   • Default start/end time pickers.
//   • Optional separate weekend schedule with its own start/end times.
//   • An emergency-alert override so streak-breaking warnings still arrive.
//
// Sub-controls fade out and become non-interactive when the master toggle
// is off (via [AnimatedOpacity] + [IgnorePointer]).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Settings page for configuring the Quiet Hours notification schedule.
///
/// When enabled, mutes all push notifications between the selected start
/// and end times. Optionally supports separate schedules for weekdays and
/// weekends, plus an emergency-alert bypass for streak-critical warnings.
class QuietHoursPage extends StatelessWidget {
  const QuietHoursPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final s = ctrl.appSettings;
    final enabled = s?.quietHoursEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiet Hours'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Master Toggle ───────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile.adaptive(
              title: const Text('Enable Quiet Hours',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Mute all notifications during specified hours'),
              value: enabled,
              onChanged: (v) => ctrl.setQuietHoursEnabled(v),
              activeTrackColor: colors.primary,
              secondary: Icon(
                enabled
                    ? Icons.do_not_disturb_on
                    : Icons.do_not_disturb_off_outlined,
                color: enabled ? colors.primary : colors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Time Pickers ──────────────────────────────────────
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                children: [
                  // Default / weekday hours
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s?.quietHoursSeparateWeekend == true
                                ? 'Weekday Hours'
                                : 'Quiet Hours',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _TimePicker(
                                  label: 'Start',
                                  value: s?.quietHoursSeparateWeekend == true
                                      ? (s?.quietHoursWeekdayStart ?? '22:00')
                                      : (s?.quietHoursStart ?? '22:00'),
                                  // Dynamically route to weekday-specific or
                                  // general start setter based on the separate-
                                  // weekend toggle.
                                  onChanged: (v) {
                                    if (s?.quietHoursSeparateWeekend == true) {
                                      ctrl.setQuietHoursWeekdayStart(v);
                                    } else {
                                      ctrl.setQuietHoursStart(v);
                                    }
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.arrow_forward,
                                    color: colors.textMuted, size: 20),
                              ),
                              Expanded(
                                child: _TimePicker(
                                  label: 'End',
                                  value: s?.quietHoursSeparateWeekend == true
                                      ? (s?.quietHoursWeekdayEnd ?? '07:00')
                                      : (s?.quietHoursEnd ?? '07:00'),
                                  onChanged: (v) {
                                    if (s?.quietHoursSeparateWeekend == true) {
                                      ctrl.setQuietHoursWeekdayEnd(v);
                                    } else {
                                      ctrl.setQuietHoursEnd(v);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Separate weekend toggle
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: SwitchListTile.adaptive(
                      title: const Text('Separate Weekend Hours'),
                      subtitle: const Text(
                          'Set different quiet hours for weekends'),
                      value: s?.quietHoursSeparateWeekend ?? false,
                      onChanged: (v) => ctrl.setQuietHoursSeparateWeekend(v),
                      activeTrackColor: colors.primary,
                    ),
                  ),

                  // Weekend hours card (only shown when separate-weekend is on)
                  if (s?.quietHoursSeparateWeekend == true) ...[
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weekend Hours',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimePicker(
                                    label: 'Start',
                                    value:
                                        s?.quietHoursWeekendStart ?? '23:00',
                                    onChanged: ctrl.setQuietHoursWeekendStart,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Icon(Icons.arrow_forward,
                                      color: colors.textMuted, size: 20),
                                ),
                                Expanded(
                                  child: _TimePicker(
                                    label: 'End',
                                    value: s?.quietHoursWeekendEnd ?? '09:00',
                                    onChanged: ctrl.setQuietHoursWeekendEnd,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Emergency toggle
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: SwitchListTile.adaptive(
                      title: const Text('Allow Emergency Alerts'),
                      subtitle: const Text(
                          'Streak-breaking warnings still come through'),
                      value: s?.quietHoursAllowEmergency ?? true,
                      onChanged: (v) => ctrl.setQuietHoursAllowEmergency(v),
                      activeTrackColor: colors.primary,
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
}

// =============================================================================
//  PRIVATE WIDGETS — Compact time-picker button.
// =============================================================================

/// A tappable inline time-picker that shows a label and the currently
/// selected time. Tapping it opens the system [showTimePicker] dialog.
///
/// Communicates the selected time back as a zero-padded "HH:mm" string
/// via [onChanged].
class _TimePicker extends StatelessWidget {
  /// Descriptor shown above the time (e.g. "Start" or "End").
  final String label;

  /// The current time value in "HH:mm" format.
  final String value;

  /// Callback invoked when the user selects a new time.
  final ValueChanged<String> onChanged;

  const _TimePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Parses a "HH:mm" string into a [TimeOfDay], defaulting to 22:00.
  TimeOfDay _parse(String v) {
    final parts = v.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 22,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  /// Formats a [TimeOfDay] into a zero-padded "HH:mm" string.
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              tod.format(context),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
