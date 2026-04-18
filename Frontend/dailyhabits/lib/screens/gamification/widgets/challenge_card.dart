// =============================================================================
// File: challenge_card.dart
// Description: Card widget for displaying a challenge with progress bar,
//              difficulty badge, reward info, and optional join button.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/gamification_models.dart';

/// A themed card that shows a challenge's status, progress, and rewards.
class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool compact;
  final bool showJoinButton;
  final VoidCallback? onJoin;
  final VoidCallback? onMarkToday;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.compact = false,
    this.showJoinButton = false,
    this.onJoin,
    this.onMarkToday,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: challenge.isCompleted
              ? const Color(0xFF22C55E).withValues(alpha: 0.3)
              : tc.border.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title + difficulty badge
          Row(
            children: [
              // Challenge icon
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: challenge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  challenge.icon,
                  color: challenge.color,
                  size: compact ? 18 : 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact)
                      Text(
                        challenge.description,
                        style: TextStyle(
                          color: tc.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: challenge.difficultyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  challenge.difficultyLabel,
                  style: TextStyle(
                    color: challenge.difficultyColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (!compact) ...[
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (challenge.progressPercentage / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: tc.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  challenge.isCompleted
                      ? const Color(0xFF22C55E)
                      : challenge.color,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Progress text + rewards row
            Row(
              children: [
                Text(
                  '${challenge.progress}/${challenge.target}',
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (challenge.isCompleted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 14),
                  const SizedBox(width: 2),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '${challenge.rating10.toStringAsFixed(1)}/10',
                  style: TextStyle(
                    color: challenge.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Rewards
                _rewardChip(Icons.stars_rounded, '+${challenge.xpReward} XP',
                    const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _rewardChip(Icons.monetization_on_rounded,
                    '+${challenge.coinReward}', const Color(0xFF3B82F6)),
              ],
            ),

            // Time remaining + participants
            if (challenge.timeRemaining != null ||
                challenge.participantCount > 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (challenge.timeRemaining != null) ...[
                    Icon(Icons.timer_outlined, color: tc.textMuted, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      challenge.timeRemaining!,
                      style: TextStyle(
                        color: tc.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (challenge.participantCount > 1) ...[
                    const Spacer(),
                    Icon(Icons.people_outline_rounded,
                        color: tc.textMuted, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.participantCount} participants',
                      style: TextStyle(
                        color: tc.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Join button
            if (showJoinButton && onJoin != null && !challenge.isCompleted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: challenge.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Join Challenge',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],

            // Mark today button for personal challenge gamification
            if (!showJoinButton && !challenge.isCompleted) ...[
              const SizedBox(height: 10),
              if (challenge.doneToday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Done Today',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else if (challenge.canMarkToday && onMarkToday != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onMarkToday,
                    icon: const Icon(Icons.task_alt_rounded, size: 16),
                    label: const Text('Mark Done Today'),
                  ),
                ),
            ],
          ] else ...[
            // Compact mode: simple progress row
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (challenge.progressPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: tc.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(challenge.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${challenge.progress}/${challenge.target}',
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rewardChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
