// =============================================================================
// File: streak_card.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: A presentation widget that displays the user's current and best
//              habit streaks side-by-side in a glassy card with fire and trophy
//              icons for visual emphasis.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// A compact card that highlights the user's streak progress.
///
/// Displays two stats separated by a vertical divider:
/// - **Current Streak** — consecutive days with at least one habit completed.
/// - **Best Streak** — the user's all-time longest streak.
///
/// The current streak icon is slightly larger to draw the user's eye.
class StreakCard extends StatelessWidget {
  /// Consecutive days the user has completed habits without interruption.
  final int currentStreak;

  /// All-time longest streak recorded for the user.
  final int bestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tc.border,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStreakItem(
            context,
            label: 'Current Streak',
            value: '$currentStreak',
            icon: Icons.local_fire_department,
            color: tc.accent,
            isMain: true,
          ),
          Container(
            height: 50,
            width: 1,
            color: tc.border,
          ),
          _buildStreakItem(
            context,
            label: 'Best Streak',
            value: '$bestStreak',
            icon: Icons.emoji_events,
            color: tc.warning,
          ),
        ],
      ),
    );
  }

  /// Renders a single streak metric column with an [icon], numeric [value],
  /// and descriptive [label]. When [isMain] is `true`, the icon and value
  /// are rendered at a larger scale for visual emphasis.
  Widget _buildStreakItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isMain = false,
  }) {
    final tc = context.colors;
    return Column(
      children: [
        Icon(icon, color: color, size: isMain ? 32 : 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isMain ? 32 : 24,
            fontWeight: FontWeight.bold,
            color: tc.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tc.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
