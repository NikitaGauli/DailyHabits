// =============================================================================
// File: xp_activity_tile.dart
// Description: Compact tile showing a single XP event with icon, description,
//              XP amount, and relative timestamp.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/gamification_models.dart';

/// A compact list tile for a single XP gain/loss event.
class XPActivityTile extends StatelessWidget {
  final XPEvent event;

  const XPActivityTile({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Source icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              event.sourceIcon,
              color: const Color(0xFF4F46E5),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),

          // Description + source label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description.isNotEmpty
                      ? event.description
                      : event.sourceLabel,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(event.createdAt),
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // XP amount + multiplier
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${event.amount} XP',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (event.multiplier > 1.0)
                Text(
                  '${event.multiplier}x',
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns a human-friendly relative time string.
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
