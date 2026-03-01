// =============================================================================
// smart_tip_card.dart — AI Smart Tip Card Widget
// =============================================================================
// A dismissible card that renders a single AI-generated [SmartTip].
//
// Features:
//  • Swipe-to-dismiss to remove the tip.
//  • "Helpful" (like) and "Save" action chips with optimistic toggle.
//  • Colour-coded icon and optional habit-name chip.
//  • Relative timestamp (e.g. "3h ago").
//
// Used inside the Smart Tips tab of [NotificationScreen].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/notification_model.dart';

/// A card that presents a single [SmartTip] with like, save, and
/// dismiss interactions.
class SmartTipCard extends StatelessWidget {
  /// The smart tip data to render.
  final SmartTip tip;

  /// Called when the user taps the "Helpful" chip.
  final VoidCallback? onLike;

  /// Called when the user taps the "Save" chip.
  final VoidCallback? onSave;

  /// Called when the user swipes the card away.
  final VoidCallback? onDismiss;

  const SmartTipCard({
    super.key,
    required this.tip,
    this.onLike,
    this.onSave,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Dismissible(
      key: ValueKey('tip_${tip.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: tc.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.close_rounded, color: tc.error, size: 24),
      ),
      onDismissed: (_) => onDismiss?.call(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title + habit chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tip.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                        ),
                      ),
                      if (tip.habitTitle != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tip.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tip.habitTitle!,
                            style: AppTextStyles.caption.copyWith(
                              color: tip.color,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              tip.message,
              style: AppTextStyles.bodyMd.copyWith(
                color: tc.textSecondary,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 12),

            // Action row: like + save
            Row(
              children: [
                _ActionChip(
                  icon: tip.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: tip.isLiked ? 'Liked' : 'Helpful',
                  isActive: tip.isLiked,
                  activeColor: AppColors.error,
                  onTap: onLike,
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  icon: tip.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: tip.isSaved ? 'Saved' : 'Save',
                  isActive: tip.isSaved,
                  activeColor: tc.accent,
                  onTap: onSave,
                ),
                const Spacer(),
                Text(
                  _formatAge(tip.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: tc.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formats a [DateTime] as a concise relative age string
  /// (e.g. "3d ago", "5h ago", "Just now").
  String _formatAge(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

/// A small, tappable chip used for like / save actions.
///
/// Displays an [icon] and [label], toggling visual styling between
/// active (filled colour) and inactive (muted) states.
class _ActionChip extends StatelessWidget {
  /// The leading icon for the chip.
  final IconData icon;

  /// Display label next to the icon.
  final String label;

  /// Whether this chip is currently in the "active" state.
  final bool isActive;

  /// Colour used when [isActive] is `true`.
  final Color activeColor;

  /// Tap callback.
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : tc.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.3)
                : tc.border.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? activeColor : tc.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? activeColor : tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
