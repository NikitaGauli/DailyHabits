import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class StreakCard extends StatelessWidget {
  final int currentStreak;
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
