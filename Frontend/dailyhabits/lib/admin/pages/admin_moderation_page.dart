// =============================================================================
// File: admin_moderation_page.dart
// Description: Content moderation queue — review flagged content and make
//              approve/reject decisions.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.moderationPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 64, color: AppColors.success),
                SizedBox(height: 12),
                Text('Moderation queue is clear'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: page.results.length,
          itemBuilder: (context, i) =>
              _ModerationCard(item: page.results[i], ctrl: ctrl),
        );
      },
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final ModerationItem item;
  final AdminController ctrl;
  const _ModerationCard({required this.item, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.flag, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                '${item.contentType} — ${item.flagReason}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _ScoreBadge(score: item.autoFlagScore),
            ],
          ),
          const SizedBox(height: 10),

          // Preview
          if (item.contentPreview.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.contentPreview,
                  maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 10),

          // Author + date
          Text(
            'Author: ${item.authorEmail}  •  ${_formatDate(item.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),

          // Actions
          if (item.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  onPressed: () =>
                      ctrl.moderationDecide(item.id, decision: 'approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  onPressed: () =>
                      _showRejectDialog(context, item.id, ctrl),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(
      BuildContext context, String id, AdminController ctrl) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Content'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(hintText: 'Rejection reason…'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ctrl.moderationDecide(id,
                  decision: 'reject', notes: notesCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.8
        ? AppColors.error
        : score >= 0.5
            ? AppColors.warning
            : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Score ${(score * 100).toInt()}%',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
