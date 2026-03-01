// **daily_summary.dart** — Daily Summary Card Widget
//
// Provides [DailySummaryWidget], a side-by-side card layout showing
// the count of completed vs. remaining habits for the current day.
//
// Uses green and accent colour coding to visually distinguish
// completed and pending tallies.
//
// See also:
//   - [HomeController] for the data source.
//   - [ProgressCardWidget] for the circular progress variant.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ===============================================================
/// DailySummaryWidget
/// ===============================================================
///
/// A widget that displays a summary of daily habit progress.
///
/// Parameters:
/// - [completedHabits]: Number of habits completed today.
/// - [totalHabits]: Total number of habits planned for today.
///
/// UI:
/// - Shows a header "Daily Summary".
/// - Displays two cards side by side:
///   1. Completed habits with a green check icon.
///   2. Remaining habits with a purple pending icon.
/// - Each card shows the icon, label, and numeric value.
///
/// Usage:
/// ```dart
/// DailySummaryWidget(
///   completedHabits: homeController.completedHabits,
///   totalHabits: homeController.totalHabits,
/// )
/// ```
/// ===============================================================
class DailySummaryWidget extends StatelessWidget {
  /// Number of habits completed today
  final int completedHabits;

  /// Total number of habits for today
  final int totalHabits;

  const DailySummaryWidget({
    super.key,
    required this.completedHabits,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    // Calculate remaining habits
    final remainingHabits = totalHabits - completedHabits;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Completed & Remaining cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.check_circle,
                  label: 'Completed',
                  value: completedHabits.toString(),
                  color: AppColors.success,
                  tc: tc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.pending_actions,
                  label: 'Remaining',
                  value: remainingHabits.toString(),
                  color: tc.accent,
                  tc: tc,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds an individual summary card for completed or remaining habits
  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeColors tc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
