// =============================================================================
// File: leaderboard_tile.dart
// Description: List tile widget for a weekly leaderboard entry — rank medal,
//              user name, completions, streak, and XP.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

/// Tile widget for a single leaderboard entry.
class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  const LeaderboardTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTop3 = entry.rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTop3
            ? _rankColor(entry.rank).withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3
              ? _rankColor(entry.rank).withValues(alpha: 0.25)
              : colors.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // ── Rank ───────────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Text(
              entry.medal,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTop3 ? 20 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Avatar ─────────────────────────────────────────────
          CircleAvatar(
            radius: 18,
            backgroundColor: _rankColor(entry.rank).withValues(alpha: 0.15),
            child: Text(
              entry.user.displayName.isNotEmpty
                  ? entry.user.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _rankColor(entry.rank),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Name ───────────────────────────────────────────────
          Expanded(
            child: Text(
              entry.user.displayName,
              style: TextStyle(
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Stats ──────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.xpEarned} XP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.completions} done • ${entry.streakDays}d streak',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade700;
      case 2:
        return Colors.blueGrey.shade400;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.grey;
    }
  }
}
