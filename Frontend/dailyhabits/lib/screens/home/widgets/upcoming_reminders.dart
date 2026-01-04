import 'package:flutter/material.dart';
import '../../../models/reminder.dart';

/// ===============================================================
/// UpcomingRemindersWidget
/// ===============================================================
///
/// A widget that displays a vertical list of upcoming habit reminders.
///
/// Parameters:
/// - [reminders]: List of [Reminder] objects to display. If the list is empty,
///   the widget renders nothing.
///
/// UI:
/// - Shows a header "Upcoming Reminders".
/// - Each reminder is displayed in a rounded card with a colored icon,
///   title, time, and a subtle notification icon on the right.
/// - Uses semi-transparent backgrounds and borders for a modern look.
///
/// Usage:
/// ```dart
/// UpcomingRemindersWidget(
///   reminders: homeController.upcomingReminders,
/// )
/// ```
/// ===============================================================
class UpcomingRemindersWidget extends StatelessWidget {
  /// List of reminders to display
  final List<Reminder> reminders;

  const UpcomingRemindersWidget({super.key, required this.reminders});

  @override
  Widget build(BuildContext context) {
    // If no reminders, render empty widget
    if (reminders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            'Upcoming Reminders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        // Reminder list
        ...reminders.map(
          (reminder) => Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Reminder icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: reminder.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(reminder.icon, color: reminder.color, size: 20),
                ),
                const SizedBox(width: 12),
                // Reminder title and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification icon
                Icon(
                  Icons.notifications_outlined,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
