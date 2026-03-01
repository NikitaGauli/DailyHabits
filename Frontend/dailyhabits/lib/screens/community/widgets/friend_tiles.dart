// =============================================================================
// File: friend_tiles.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: A collection of reusable tile widgets for the Friends tab.
//              Includes tiles for accepted friends, user search results, and
//              incoming friend requests, each with contextual action buttons.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

// =============================================================================
//  FRIEND TILE
// =============================================================================

/// A list tile representing an accepted friend.
///
/// Shows the friend’s avatar initial, name, current streak badge, and
/// an optional trailing action button (defaults to a “remove friend” icon).
class FriendTile extends StatelessWidget {
  /// Raw friend data map containing at least `'name'` and `'currentStreak'`.
  final Map<String, dynamic> friend;

  /// Callback fired when the trailing action button is tapped.
  final VoidCallback? onAction;

  /// Icon displayed in the trailing action button.
  final IconData actionIcon;

  /// Colour of the trailing action icon; defaults to the theme’s muted text.
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

// =============================================================================
//  USER SEARCH TILE
// =============================================================================

/// A compact tile for displaying a user search result.
///
/// Shows the user’s avatar initial and name on the left, and a relationship
/// status widget on the right that adapts based on the current relationship:
/// - `'accepted'` → "Friends" badge in green.
/// - `'pending'` → "Pending" badge in warning amber.
/// - `'incoming'` → "Respond" badge in primary colour.
/// - `'none'` → An “Add” icon button.
class UserSearchTile extends StatelessWidget {
  /// Raw user data map containing at least `'name'` and `'relationship'`.
  final Map<String, dynamic> user;

  /// Callback fired when the add-friend button is tapped (relationship = none).
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

  /// Returns a status badge or action button based on the [rel]ationship
  /// string. Handles four states: accepted, pending, incoming, and none.
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

// =============================================================================
//  FRIEND REQUEST TILE
// =============================================================================

/// A tile for an incoming friend request with accept / reject buttons.
///
/// Displays the requester’s avatar and name, a “Wants to be your friend”
/// subtitle, a reject (X) icon button, and a primary “Accept” elevated button.
class FriendRequestTile extends StatelessWidget {
  /// Raw request data map containing a nested `'user'` map with `'name'`.
  final Map<String, dynamic> request;

  /// Callback fired when the user taps the Accept button.
  final VoidCallback? onAccept;

  /// Callback fired when the user taps the Reject (X) button.
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
