// =============================================================================
// File: notifications_page.dart
// Project: DailyHabits — Settings Module
//
// Detailed push-notification settings page that allows the user to:
//   • Toggle all push notifications on/off with a global master switch.
//   • Individually enable or disable specific notification categories:
//     – Habit reminders, streak alerts, insight notifications, achievements.
//
// When the global switch is off, the individual toggle card fades out and
// becomes non-interactive via [AnimatedOpacity] and [IgnorePointer].
//
// An informational banner at the bottom notes that preferences sync
// across devices.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Push-notification preferences page.
///
/// A master toggle controls whether any notifications are delivered.
/// Below it, individual toggle switches let the user fine-tune which
/// categories are active. All state is read from and written to
/// [SettingsController.notifSettings].
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static String _fmtTime(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay? current,
    ValueChanged<TimeOfDay?> onSelected,
  ) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (chosen != null) {
      onSelected(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final ns = ctrl.notifSettings;

    final globalEnabled = ns?.notificationsEnabled ?? true;
    final deliveryMode = (ns?.deliveryMode == 'digest') ? 'digest' : 'instant';
    final cooldownChoices = [5, 10, 15, 20, 30, 45, 60];
    final cooldownValue = ns?.cooldownMinutes ?? 30;
    final effectiveCooldown = cooldownChoices.contains(cooldownValue)
      ? cooldownValue
      : 30;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'You are here: Profile > Quick Access > Scheduling Preferences',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.home_rounded, size: 16),
                  label: const Text('Dashboard'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Global Toggle ─────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile.adaptive(
              title: const Text('Push Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Enable or disable all notifications'),
              value: globalEnabled,
              onChanged: ctrl.toggleNotifications,
              activeTrackColor: colors.primary,
              secondary: Icon(
                globalEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                color: globalEnabled ? colors.primary : colors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Individual Toggles ────────────────────────────────
          AnimatedOpacity(
            opacity: globalEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !globalEnabled,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    _NotifToggle(
                      icon: Icons.alarm,
                      title: 'Habit Reminders',
                      subtitle: 'Get reminded to complete your habits',
                      value: ns?.habitReminders ?? true,
                      onChanged: ctrl.toggleHabitReminders,
                    ),
                    const Divider(height: 1, indent: 56),
                    _NotifToggle(
                      icon: Icons.local_fire_department,
                      title: 'Streak Alerts',
                      subtitle: 'Warning when you might break a streak',
                      value: ns?.streakAlerts ?? true,
                      onChanged: ctrl.toggleStreakAlerts,
                    ),
                    const Divider(height: 1, indent: 56),
                    _NotifToggle(
                      icon: Icons.insights,
                      title: 'Insight Notifications',
                      subtitle: 'Weekly analytics and habit patterns',
                      value: ns?.insightNotifications ?? true,
                      onChanged: ctrl.toggleInsightNotifications,
                    ),
                    const Divider(height: 1, indent: 56),
                    _NotifToggle(
                      icon: Icons.emoji_objects_outlined,
                      title: 'Achievement Alerts',
                      subtitle: 'Celebrations when you hit milestones',
                      value: ns?.achievementNotifications ?? true,
                      onChanged: ctrl.toggleAchievementNotifications,
                    ),
                    const Divider(height: 1, indent: 56),
                    _NotifToggle(
                      icon: Icons.weekend,
                      title: 'Weekend Reminders',
                      subtitle: 'Allow reminders on Saturday and Sunday',
                      value: ns?.weekendRemindersEnabled ?? true,
                      onChanged: ctrl.toggleWeekendReminders,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          AnimatedOpacity(
            opacity: globalEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !globalEnabled,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduling Preferences',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('delivery-$deliveryMode'),
                        initialValue: deliveryMode,
                        decoration: const InputDecoration(
                          labelText: 'Delivery mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'instant', child: Text('Instant')),
                          DropdownMenuItem(value: 'digest', child: Text('Digest')),
                        ],
                        onChanged: (v) {
                          if (v != null) ctrl.setDeliveryMode(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('cooldown-$effectiveCooldown'),
                        initialValue: effectiveCooldown,
                        decoration: const InputDecoration(
                          labelText: 'Cooldown (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        items: cooldownChoices
                            .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) ctrl.setCooldownMinutes(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: ns?.timezone ?? 'UTC',
                        decoration: const InputDecoration(
                          labelText: 'Timezone',
                          hintText: 'e.g. Asia/Kathmandu',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: ctrl.setTimezone,
                      ),
                      const SizedBox(height: 12),
                      _TimePickerTile(
                        title: 'Reminder window start',
                        valueText: _fmtTime(ns?.reminderWindowStart),
                        icon: Icons.schedule,
                        onTap: () => _pickTime(
                          context,
                          ns?.reminderWindowStart,
                          ctrl.setReminderWindowStart,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TimePickerTile(
                        title: 'Reminder window end',
                        valueText: _fmtTime(ns?.reminderWindowEnd),
                        icon: Icons.schedule_send,
                        onTap: () => _pickTime(
                          context,
                          ns?.reminderWindowEnd,
                          ctrl.setReminderWindowEnd,
                        ),
                      ),
                      if ((ns?.deliveryMode ?? 'instant') == 'digest') ...[
                        const SizedBox(height: 8),
                        _TimePickerTile(
                          title: 'Digest time',
                          valueText: _fmtTime(ns?.digestTime),
                          icon: Icons.notifications,
                          onTap: () => _pickTime(
                            context,
                            ns?.digestTime,
                            ctrl.setDigestTime,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Optional completion notes and reflections are set when you mark a habit done in Habit Details.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Info Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notification preferences sync across all your devices.',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  PRIVATE WIDGETS — Individual notification toggle row.
// =============================================================================

/// A single notification-category toggle rendered as a [SwitchListTile].
///
/// Displays an [icon] that tints primary/muted based on [value], along
/// with a [title] and [subtitle] describing the notification type.
class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SwitchListTile.adaptive(
      secondary: Icon(icon, color: value ? colors.primary : colors.textMuted),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          Text(subtitle, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: colors.primary,
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String title;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.title,
    required this.valueText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border.withValues(alpha: 0.4)),
      ),
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(valueText),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: onTap,
    );
  }
}
