import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

/// Feed post card matching the home-page design system.
class FeedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;

  const FeedPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final name = author['name'] ?? 'User';
    final streak = author['currentStreak'] ?? 0;
    final isLiked = post['isLiked'] == true;
    final likeCount = post['likeCount'] ?? 0;
    final commentCount = post['commentCount'] ?? 0;
    final content = post['content'] ?? '';
    final emoji = post['emoji'] ?? '';
    final postType = post['postType'] ?? '';
    final habitTitle = post['habitTitle'];
    final createdAt = post['createdAt'] ?? '';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ─────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tc.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: tc.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                    Text(
                      _timeAgo(createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tc.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: tc.primary, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '$streak',
                        style: AppTextStyles.label.copyWith(
                          color: tc.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Post type badge ────────────────────────────────────
          if (postType.isNotEmpty) ...[
            _typeBadge(context, postType),
            const SizedBox(height: 10),
          ],

          // ── Content ────────────────────────────────────────────
          Text(
            emoji.isNotEmpty ? '$emoji  $content' : content,
            style: AppTextStyles.bodyMd.copyWith(
              color: tc.textPrimary,
              height: 1.5,
            ),
          ),

          // ── Habit reference ────────────────────────────────────
          if (habitTitle != null && habitTitle.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tc.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: tc.success, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      habitTitle.toString(),
                      style: AppTextStyles.label.copyWith(
                        color: tc.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Actions ────────────────────────────────────────────
          Row(
            children: [
              _actionBtn(
                context,
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: likeCount > 0 ? '$likeCount' : 'Like',
                color: isLiked ? AppColors.error : tc.textSecondary,
                onTap: onLike,
              ),
              const SizedBox(width: 24),
              _actionBtn(
                context,
                icon: Icons.chat_bubble_outline,
                label: commentCount > 0 ? '$commentCount' : 'Comment',
                color: tc.textSecondary,
                onTap: onComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(BuildContext context, String type) {
    final tc = context.colors;
    final Map<String, (IconData, Color, String)> map = {
      'completion': (Icons.check_circle, tc.success, 'Completed'),
      'streak': (Icons.local_fire_department, AppColors.warning, 'Streak'),
      'achievement': (Icons.emoji_events, AppColors.warning, 'Achievement'),
      'group_update': (Icons.group, tc.primary, 'Group'),
      'motivation': (Icons.lightbulb_outline, tc.secondary, 'Motivational'),
    };
    final entry = map[type] ?? (Icons.article, tc.textMuted, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: entry.$2.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(entry.$1, size: 14, color: entry.$2),
          const SizedBox(width: 4),
          Text(
            entry.$3,
            style: AppTextStyles.caption.copyWith(
              color: entry.$2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.bodyMd.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }
}
