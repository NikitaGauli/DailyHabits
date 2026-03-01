// =============================================================================
// File: invite_card.dart
// Description: Card widget for displaying a habit invitation with accept/decline
//              actions, inviter info, and habit details.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

/// Card widget showing a pending habit invitation.
class InviteCard extends StatelessWidget {
  final HabitInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool expanded;

  const InviteCard({
    super.key,
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
      ),
      color: colors.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Text(invite.habitEmoji,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.habitTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'from ${invite.invitedBy.displayName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${invite.memberCount} members',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),

            // ── Message ─────────────────────────────────────────────
            if (invite.message.isNotEmpty && expanded) ...[
              const SizedBox(height: 8),
              Text(
                '"${invite.message}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // ── Actions ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                          color: colors.outline.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
