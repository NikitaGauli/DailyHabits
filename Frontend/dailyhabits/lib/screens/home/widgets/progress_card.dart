// **progress_card.dart** — Daily Progress Card Widget
//
// Provides [ProgressCardWidget], a dashboard card that visualises the
// user's daily habit completion rate. Features a circular progress
// indicator, percentage label, and a current-streak badge.
//
// All values are passed in as constructor parameters — the widget is
// purely presentational and carries no business logic.
//
// See also:
//   - [HomeController] for the source of progress metrics.
//   - [HomePage._buildHeroProgressCard] for the inline hero variant.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ===============================================================
/// ProgressCardWidget
/// ===============================================================
///
/// A reusable card widget that displays the user's daily progress
/// including:
/// 1. Overall completion percentage of today's habits
/// 2. Current streak in days
/// 3. Completed vs total habits count
///
/// Parameters:
/// - [todayProgress]: Fraction of completed habits (0.0 to 1.0)
/// - [completedHabits]: Number of habits completed today
/// - [totalHabits]: Total number of habits for today
/// - [currentStreak]: Current streak of consecutive days
///
/// Usage:
/// ```dart
/// ProgressCardWidget(
///   todayProgress: 0.4,
///   completedHabits: 2,
///   totalHabits: 5,
///   currentStreak: 12,
/// )
/// ```
/// ===============================================================
class ProgressCardWidget extends StatelessWidget {
  final double todayProgress;
  final int completedHabits;
  final int totalHabits;
  final int currentStreak;

  const ProgressCardWidget({
    super.key,
    required this.todayProgress,
    required this.completedHabits,
    required this.totalHabits,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tc.card, tc.primary.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tc.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Column: Progress details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Progress",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(todayProgress * 100).toInt()}% Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Current streak badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tc.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: tc.textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tc.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tc.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$currentStreak Days',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tc.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Right Column: Circular progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: todayProgress,
                    strokeWidth: 6,
                    backgroundColor: tc.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      tc.secondary,
                    ),
                  ),
                ),
                Text(
                  '$completedHabits/$totalHabits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tc.textPrimary,
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
