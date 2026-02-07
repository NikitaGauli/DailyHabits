import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import '../../../models/habit.dart';

/// ===============================================================
/// HabitCardWidget
/// ===============================================================
///
/// A reusable widget that displays an individual habit in a card
/// format. Shows habit details like title, time, category, icon,
/// and completion status. Also supports tap actions for editing
/// and toggling completion.
///
/// Parameters:
/// - [habit]: The Habit object containing all habit details.
/// - [onTap]: Callback function triggered when the card itself is tapped (e.g., to edit).
/// - [onToggle]: Callback function triggered when the checkbox is tapped to mark completion.
///
/// Usage:
/// ```dart
/// HabitCardWidget(
///   habit: myHabit,
///   onTap: () => editHabit(myHabit),
///   onToggle: () => toggleHabitCompletion(index),
/// )
/// ```
/// ===============================================================
class HabitCardWidget extends StatelessWidget {
  /// Habit data
  final Habit habit;

  /// Action when the card is tapped
  final VoidCallback onTap;

  /// Action when the checkbox is toggled
  final VoidCallback onToggle;

  const HabitCardWidget({
    super.key,
    required this.habit,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tc.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tc.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(habit.icon, color: habit.color, size: 24),
                ),
                const SizedBox(width: 16),

                // Habit details: title and time/category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                          decoration: habit.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${habit.time} · ${habit.category}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: tc.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Completion checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: habit.isCompleted
                          ? AppColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: habit.isCompleted
                            ? AppColors.success
                            : tc.textMuted,
                        width: 2,
                      ),
                    ),
                    child: habit.isCompleted
                        ? Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
