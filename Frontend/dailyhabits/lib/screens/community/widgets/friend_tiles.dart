import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

/// Friend list-tile with streak badge and action button.
class FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Color? actionColor;

  const FriendTile({
    super.key,
    required this.friend,
    this.onAction,
    this.actionIcon = Icons.person_remove_outlined,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final name = friend['name'] ?? 'User';
    final streak = friend['currentStreak'] ?? 0;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: tc.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: tc.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      '$streak day streak',
                      style: AppTextStyles.caption.copyWith(
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onAction != null)
            IconButton(
              onPressed: onAction,
              icon: Icon(actionIcon, color: actionColor ?? tc.textMuted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Compact search result tile with relationship status.
class UserSearchTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onAdd;

  const UserSearchTile({
    super.key,
    required this.user,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final name = user['name'] ?? 'User';
    final rel = user['relationship'] ?? 'none';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tc.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: tc.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
          ),
          _statusWidget(context, rel),
        ],
      ),
    );
  }

  Widget _statusWidget(BuildContext context, String rel) {
    final tc = context.colors;
    if (rel == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tc.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Friends',
          style: AppTextStyles.caption.copyWith(
            color: tc.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (rel == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Pending',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (rel == 'incoming') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tc.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Respond',
          style: AppTextStyles.caption.copyWith(
            color: tc.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    // none → show add button
    return IconButton(
      onPressed: onAdd,
      icon: Icon(Icons.person_add_alt_1, color: tc.primary),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Incoming friend request tile with accept/reject.
class FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const FriendRequestTile({
    super.key,
    required this.request,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final user = request['user'] as Map<String, dynamic>? ?? {};
    final name = user['name'] ?? 'User';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tc.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: tc.primary,
                fontWeight: FontWeight.w700,
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
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                Text(
                  'Wants to be your friend',
                  style: AppTextStyles.caption.copyWith(
                    color: tc.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 20),
            color: tc.textMuted,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Accept',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
