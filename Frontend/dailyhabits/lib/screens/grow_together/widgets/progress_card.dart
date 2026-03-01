// =============================================================================
// File: progress_card.dart
// Description: Card widget showing a member's daily progress — completion
//              status, note, XP earned, and reaction buttons.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

/// Card showing a member's daily progress entry with reaction support.
class ProgressCard extends StatelessWidget {
  final CollaborativeProgress progress;
  final Function(String)? onReact;

  const ProgressCard({
    super.key,
    required this.progress,
    this.onReact,
  });

  static const _reactionEmojis = {
    'fire': '🔥',
    'clap': '👏',
    'heart': '❤️',
    'celebrate': '🎉',
    'strong': '💪',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User Row ─────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  child: Text(
                    progress.user.displayName.isNotEmpty
                        ? progress.user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.user.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        progress.date,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status
                if (progress.completed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          '+${progress.xpEarned} XP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.3)),
              ],
            ),

            // ── Note ─────────────────────────────────────────────
            if (progress.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: colors.outline.withValues(alpha: 0.08)),
                ),
                child: Text(
                  progress.note,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Reactions ────────────────────────────────────────
            Wrap(
              spacing: 6,
              children: _reactionEmojis.entries.map((entry) {
                final count = progress.reactions[entry.key] ?? 0;
                return InkWell(
                  onTap: onReact != null ? () => onReact!(entry.key) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? colors.primary.withValues(alpha: 0.08)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: count > 0
                            ? colors.primary.withValues(alpha: 0.3)
                            : colors.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.value, style: const TextStyle(fontSize: 14)),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
