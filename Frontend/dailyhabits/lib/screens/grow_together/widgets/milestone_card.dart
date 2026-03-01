// =============================================================================
// File: milestone_card.dart
// Description: Card widget for displaying a group milestone — achievement
//              status, badge emoji, XP reward, and achievement date.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/grow_together_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// Card widget showing a group milestone's status and details.
class MilestoneCard extends StatelessWidget {
  final GTGroupMilestone milestone;
  const MilestoneCard({super.key, required this.milestone});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final achieved = milestone.achieved;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: achieved
              ? AppColors.secondary.withValues(alpha: 0.3)
              : colors.outline.withValues(alpha: 0.12),
        ),
      ),
      color: achieved
          ? AppColors.secondary.withValues(alpha: 0.05)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Icon / Badge ─────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: achieved
                    ? AppColors.secondary.withValues(alpha: 0.15)
                    : colors.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                milestone.badgeEmoji,
                style: TextStyle(
                  fontSize: 24,
                  color: achieved ? null : colors.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Info ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: achieved ? colors.onSurface : colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (milestone.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      milestone.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '+${milestone.xpReward} XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: achieved ? AppColors.secondary : colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      if (achieved && milestone.achievedAt != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.check_circle,
                            size: 12, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text(
                          _formatDate(milestone.achievedAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Status Icon ──────────────────────────────────────
            achieved
                ? Icon(Icons.emoji_events, size: 28, color: AppColors.secondary)
                : Icon(Icons.lock_outline,
                    size: 24,
                    color: colors.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
