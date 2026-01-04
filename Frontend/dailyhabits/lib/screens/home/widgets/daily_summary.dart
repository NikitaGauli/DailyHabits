import 'package:flutter/material.dart';

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
    // Calculate remaining habits
    final remainingHabits = totalHabits - completedHabits;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.pending_actions,
                  label: 'Remaining',
                  value: remainingHabits.toString(),
                  color: const Color(0xFF8B5CF6),
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
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
