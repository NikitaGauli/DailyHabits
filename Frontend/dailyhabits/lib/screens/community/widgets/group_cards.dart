// =============================================================================
// File: group_cards.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: Reusable card widgets for the Groups tab. Includes a full-detail
//              GroupCard for groups the user belongs to (with leave / copy-code
//              menu) and a lightweight DiscoverGroupCard for public groups the
//              user can join.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

// =============================================================================
//  GROUP CARD (Joined)
// =============================================================================

/// A detailed card for a group the user has already joined.
///
/// Displays the group name, member count / capacity, the user’s role,
/// a progress bar representing capacity fill, and a popup menu with
/// “Copy Invite Code” and “Leave Group” actions.
class GroupCard extends StatelessWidget {
  /// Raw group data map from the backend.
  final Map<String, dynamic> group;

  /// Callback fired when the group card body is tapped.
  final VoidCallback? onTap;

  /// Callback fired when “Leave Group” is selected from the popup menu.
  final VoidCallback? onLeave;

  /// Callback fired when “Delete Group” is selected (admin only).
  final VoidCallback? onDelete;

  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onLeave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final name = group['name'] ?? 'Group';
    final memberCount = group['memberCount'] ?? 0;
    final maxMembers = group['maxMembers'] ?? 50;
    final myRole = group['myRole'] ?? 'member';
    final inviteCode = group['inviteCode'] ?? '';
    final isAdmin = myRole == 'admin';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tc.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.group_rounded, color: tc.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.bold,
                            color: tc.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$memberCount / $maxMembers members  •  $myRole',
                          style: AppTextStyles.caption.copyWith(
                            color: tc.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'leave') onLeave?.call();
                      if (v == 'delete') onDelete?.call();
                      if (v == 'copy') {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite code copied')),
                        );
                      }
                    },
                    icon: Icon(Icons.more_vert, color: tc.textMuted, size: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: tc.card,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18, color: tc.textSecondary),
                            const SizedBox(width: 8),
                            Text('Copy Invite Code',
                                style: TextStyle(color: tc.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, size: 18, color: tc.error),
                            const SizedBox(width: 8),
                            Text('Leave Group',
                                style: TextStyle(color: tc.error)),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever,
                                  size: 18, color: tc.error),
                              const SizedBox(width: 8),
                              Text('Delete Group',
                                  style: TextStyle(color: tc.error)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxMembers > 0 ? memberCount / maxMembers : 0,
                  minHeight: 4,
                  backgroundColor: tc.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(tc.primary),
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
//  DISCOVER GROUP CARD
// =============================================================================

/// A compact card for discoverable public groups with a Join button.
///
/// Shows the group name, description (if any), and member count, alongside
/// a primary “Join” button that triggers [onJoin] with the group’s invite code.
class DiscoverGroupCard extends StatelessWidget {
  /// Raw group data map from the backend.
  final Map<String, dynamic> group;

  /// Async callback fired with the group’s invite code when Join is tapped.
  final Future<void> Function(String code)? onJoin;

  const DiscoverGroupCard({
    super.key,
    required this.group,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final name = group['name'] ?? 'Group';
    final memberCount = group['memberCount'] ?? 0;
    final desc = group['description'] ?? '';

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tc.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.explore, color: tc.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600, color: tc.textPrimary)),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: AppTextStyles.caption
                          .copyWith(color: tc.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$memberCount',
              style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
          const SizedBox(width: 6),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => onJoin?.call(group['inviteCode'] ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Join',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
