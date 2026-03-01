// **habit_card.dart** — Individual Habit Card Widget
//
// Provides [HabitCardWidget], a reusable card component used on the home
// dashboard to represent a single habit. It renders the habit icon, title,
// time/category metadata, and a toggleable completion checkbox.
//
// This widget is **stateless** — all state (completion, streaks, etc.) is
// owned by the parent controller and communicated through the [Habit] model
// and callback closures.
//
// See also:
//   - [Habit] for the data model.
//   - [HomeController] / [HomePage] for usage context.

// =============================================================================
// Imports
// =============================================================================

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
/// - [habit]: The [Habit] object containing all habit details.
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
  /// The [Habit] data model driving this card's content.
  final Habit habit;

  /// Action when the card body is tapped (typically navigates to detail/edit).
  final VoidCallback onTap;

  /// Action when the trailing checkbox is toggled (marks habit complete/incomplete).
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
                // Icon container — coloured background with habit-specific icon
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

                // Habit details — title (with strikethrough when done)
                // and a secondary line showing time and category
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

                // Animated completion checkbox — transitions between an
                // empty bordered square and a green check icon
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
