import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';

/// Group card for the Groups tab.
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onTap;
  final VoidCallback? onLeave;

  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final name = group['name'] ?? 'Group';
    final memberCount = group['memberCount'] ?? 0;
    final maxMembers = group['maxMembers'] ?? 50;
    final myRole = group['myRole'] ?? 'member';
    final inviteCode = group['inviteCode'] ?? '';

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

/// Discover-group card with a Join button.
class DiscoverGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
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
