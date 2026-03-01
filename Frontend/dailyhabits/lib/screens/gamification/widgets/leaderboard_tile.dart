// =============================================================================
// File: leaderboard_tile.dart
// Description: Single row in the leaderboard list showing rank, avatar,
//              name, score, streak, and rank change indicator.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/gamification_models.dart';

/// A list tile representing one entry in the leaderboard ranking.
class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int index;

  const LeaderboardTile({
    super.key,
    required this.entry,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final isTop3 = entry.rank <= 3;
    final isSelf = entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelf
            ? tc.primary.withValues(alpha: 0.06)
            : tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelf
              ? tc.primary.withValues(alpha: 0.2)
              : tc.border.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 36,
            child: isTop3
                ? _medalIcon(entry.rank)
                : Text(
                    '#${entry.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: tc.primary.withValues(alpha: 0.12),
            backgroundImage: entry.profileImage != null
                ? NetworkImage(entry.profileImage!)
                : null,
            child: entry.profileImage == null
                ? Text(
                    entry.userName.isNotEmpty
                        ? entry.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: tc.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name + streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? '${entry.userName} (You)' : entry.userName,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 14,
                    fontWeight: isSelf ? FontWeight.w700 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      '${entry.streakDays}d streak',
                      style: TextStyle(
                        color: tc.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.consistencyPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: tc.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Score + rank change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (entry.rankChange != 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.rankChange > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: entry.rankChangeColor,
                      size: 12,
                    ),
                    Text(
                      entry.rankChangeText,
                      style: TextStyle(
                        color: entry.rankChangeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns a medal emoji for the top 3 ranks.
  Widget _medalIcon(int rank) {
    String medal;
    double size;
    switch (rank) {
      case 1:
        medal = '🥇';
        size = 24;
        break;
      case 2:
        medal = '🥈';
        size = 22;
        break;
      case 3:
        medal = '🥉';
        size = 22;
        break;
      default:
        medal = '';
        size = 20;
    }
    return Text(medal, style: TextStyle(fontSize: size), textAlign: TextAlign.center);
  }
}
