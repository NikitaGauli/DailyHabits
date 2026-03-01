// =============================================================================
// File: shared_habit_card.dart
// Description: Card widget for displaying a shared habit in the community feed,
//              with reaction bar, comment section, and join button.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';
import 'package:dailyhabits/models/shared_habit.dart';

// =============================================================================
// SharedHabitCard — Main entry widget
// =============================================================================

/// A glassmorphism card that displays a habit shared by a friend.
///
/// Shows the habit's metadata, owner streak, emoji reaction bar, comment count,
/// and a "Join" button to clone the habit.
class SharedHabitCard extends StatelessWidget {
  final SharedHabit habit;
  final void Function(String reactionType)? onReact;
  final VoidCallback? onComment;
  final VoidCallback? onJoin;

  const SharedHabitCard({
    super.key,
    required this.habit,
    this.onReact,
    this.onComment,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sharer info row ──────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: habit.color.withValues(alpha: 0.12),
                child: Text(
                  habit.sharedBy.name.isNotEmpty
                      ? habit.sharedBy.name[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: habit.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.sharedBy.name,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                    Text(
                      _timeAgo(habit.sharedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Streak badge
              if (habit.currentStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppColors.warning,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${habit.currentStreak}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Habit title + category ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: habit.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: habit.color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(habit.icon, color: habit.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.habitTitle,
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                      if (habit.categoryName.isNotEmpty)
                        Text(
                          habit.categoryName,
                          style: AppTextStyles.caption.copyWith(
                            color: tc.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Join button
                if (onJoin != null)
                  _JoinButton(color: habit.color, onTap: onJoin!),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Reaction bar ─────────────────────────────────────────
          ReactionBar(
            reactions: habit.reactions,
            canReact: habit.canReact,
            accentColor: habit.color,
            onReact: onReact,
          ),

          const SizedBox(height: 10),

          // ── Comment action ──────────────────────────────────────
          InkWell(
            onTap: onComment,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: tc.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    habit.commentCount > 0
                        ? '${habit.commentCount} comment${habit.commentCount > 1 ? 's' : ''}'
                        : 'Add a comment',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: tc.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// =============================================================================
// _JoinButton — Compact pill-shaped button to clone a habit
// =============================================================================

class _JoinButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _JoinButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                'Join',
                style: AppTextStyles.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ReactionBar — Horizontal row of emoji reaction chips
// =============================================================================

/// A row of tappable emoji reaction chips with counts.
///
/// Each chip shows the emoji glyph and a count. Tapping a chip calls
/// [onReact] with the reaction type string.
class ReactionBar extends StatelessWidget {
  /// Map of reaction type → count (e.g. `{ 'fire': 3, 'clap': 1 }`).
  final Map<String, int> reactions;

  /// Whether the user is allowed to react.
  final bool canReact;

  /// Accent colour for active / highlighted chips.
  final Color accentColor;

  /// Called with the reaction type string when the user taps a chip.
  final void Function(String reactionType)? onReact;

  const ReactionBar({
    super.key,
    required this.reactions,
    this.canReact = true,
    this.accentColor = AppColors.primary,
    this.onReact,
  });

  static const _allReactions = [
    ('like', '👍'),
    ('encourage', '💪'),
    ('celebrate', '🎉'),
    ('fire', '🔥'),
    ('clap', '👏'),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _allReactions.map((entry) {
        final type = entry.$1;
        final emoji = entry.$2;
        final count = reactions[type] ?? 0;
        final hasCount = count > 0;

        return GestureDetector(
          onTap: canReact ? () => onReact?.call(type) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasCount
                  ? accentColor.withValues(alpha: 0.1)
                  : tc.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasCount
                    ? accentColor.withValues(alpha: 0.3)
                    : tc.textMuted.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                if (hasCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// HabitCommentSection — Scrollable comment list with text input
// =============================================================================

/// A sheet-friendly comment section with a scrollable list and a sticky
/// text input at the bottom.
class HabitCommentSection extends StatefulWidget {
  /// Loaded comments.
  final List<HabitComment> comments;

  /// Called when the user submits a new comment.
  final void Function(String content)? onSubmit;

  /// Whether the user may post comments.
  final bool canComment;

  const HabitCommentSection({
    super.key,
    required this.comments,
    this.onSubmit,
    this.canComment = true,
  });

  @override
  State<HabitCommentSection> createState() => _HabitCommentSectionState();
}

class _HabitCommentSectionState extends State<HabitCommentSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tc.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Comments',
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Comment list
          Expanded(
            child: widget.comments.isEmpty
                ? Center(
                    child: Text(
                      'No comments yet. Be the first!',
                      style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.comments.length,
                    itemBuilder: (context, i) {
                      final c = widget.comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: tc.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                c.authorName.isNotEmpty
                                    ? c.authorName[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                  color: tc.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: AppTextStyles.bodyMd.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: tc.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _ago(c.createdAt),
                                        style: AppTextStyles.caption.copyWith(
                                          color: tc.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.content,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input
          if (widget.canComment) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 300,
                    style: AppTextStyles.bodyMd.copyWith(color: tc.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: AppTextStyles.bodyMd.copyWith(
                        color: tc.textMuted,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: tc.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      widget.onSubmit?.call(text);
                      _controller.clear();
                    }
                  },
                  icon: Icon(Icons.send_rounded, color: tc.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: tc.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
