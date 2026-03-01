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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final ns = ctrl.notifSettings;

    final globalEnabled = ns?.notificationsEnabled ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  ],
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
