// =============================================================================
// File: member_list_tile.dart
// Description: List tile widget for displaying a collaborative habit member —
//              avatar, name, role badge, streak, and XP.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

/// List tile showing a member's info, role badge, streak, and XP.
class MemberListTile extends StatelessWidget {
  final CollaborativeHabitMember member;
  final VoidCallback? onTap;

  const MemberListTile({super.key, required this.member, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colors.primary.withValues(alpha: 0.12),
        child: Text(
          member.user.displayName.isNotEmpty
              ? member.user.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: colors.primary),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _RoleBadge(role: member.role),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
          const SizedBox(width: 2),
          Text(
            '${member.currentStreak}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 12),
          Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            '${member.totalXpEarned} XP',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            '${member.totalCompletions} done',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      trailing: member.isActive
          ? null
          : Text(
              'Inactive',
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.4)),
            ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color bg;
    Color fg;

    switch (role) {
      case 'owner':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade800;
        break;
      case 'admin':
        bg = colors.primary.withValues(alpha: 0.1);
        fg = colors.primary;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
