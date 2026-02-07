import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat.MMMd().format(date);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final bool isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: tc.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: tc.error, size: 22),
            const SizedBox(height: 2),
            Text(
              'Delete',
              style: TextStyle(color: tc.error, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDismiss?.call();
        return false; // Controller handles removal
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread
                ? tc.primary.withValues(alpha: 0.04)
                : tc.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? tc.primary.withValues(alpha: 0.18)
                  : tc.border,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeading(tc),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyLg.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: tc.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(notification.createdAt),
                          style: AppTextStyles.caption.copyWith(
                            color: tc.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: isUnread
                            ? tc.textSecondary
                            : tc.textMuted,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show group or habit tag
                    if (notification.groupName != null ||
                        notification.habitTitle != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: notification.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notification.groupName ??
                              notification.habitTitle ??
                              '',
                          style: TextStyle(
                            color: notification.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tc.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the leading icon — shows user avatar for social notifications,
  /// otherwise a colored icon container.
  Widget _buildLeading(ThemeColors tc) {
    // Social notification with user avatar
    if (notification.isSocial && notification.fromUserName != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // User avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: notification.color.withValues(alpha: 0.12),
            backgroundImage: notification.fromUserImage != null
                ? NetworkImage(notification.fromUserImage!)
                : null,
            child: notification.fromUserImage == null
                ? Text(
                    notification.fromUserName!.isNotEmpty
                        ? notification.fromUserName![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: notification.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          // Small type icon badge
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: tc.surface,
                shape: BoxShape.circle,
                border: Border.all(color: tc.bg, width: 1.5),
              ),
              child: Icon(
                _typeIcon(notification.type),
                color: notification.color,
                size: 12,
              ),
            ),
          ),
        ],
      );
    }

    // Standard icon
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: notification.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(notification.icon, color: notification.color, size: 22),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
        return Icons.person_add_rounded;
      case 'group_join':
      case 'group_approval':
        return Icons.group_add_rounded;
      case 'group_challenge':
        return Icons.emoji_events_rounded;
      case 'social_like':
        return Icons.favorite_rounded;
      case 'social_comment':
        return Icons.chat_bubble_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'achievement':
        return Icons.star_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'admin':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

