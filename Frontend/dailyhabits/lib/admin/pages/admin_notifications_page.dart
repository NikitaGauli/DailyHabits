// =============================================================================
// File: admin_notifications_page.dart
// Description: Notification campaigns page — list campaigns, send/cancel,
//              create new campaigns.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.campaignsPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign_outlined,
                    size: 64, color: AppColors.lightTextMuted),
                const SizedBox(height: 12),
                const Text('No campaigns yet'),
                if (ctrl.hasPermission('notifications.send'))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Campaign'),
                      onPressed: () => _showCreateDialog(context, ctrl),
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  Text('${page.count} campaigns',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (ctrl.hasPermission('notifications.send'))
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Campaign'),
                      onPressed: () => _showCreateDialog(context, ctrl),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: page.results.length,
                itemBuilder: (context, i) =>
                    _CampaignCard(campaign: page.results[i], ctrl: ctrl),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context, AdminController ctrl) {
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Campaign'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Campaign Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notification Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notification Body'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration:
                      const InputDecoration(labelText: 'Target Audience'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(
                        value: 'active', child: Text('Active Users')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive Users')),
                    DropdownMenuItem(
                        value: 'new_users', child: Text('New Users')),
                  ],
                  onChanged: (v) => setState(() => audience = v ?? 'all'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ctrl.loadCampaigns();
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final NotificationCampaign campaign;
  final AdminController ctrl;
  const _CampaignCard({required this.campaign, required this.ctrl});

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
              Expanded(
                child: Text(campaign.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              _CampaignStatusBadge(status: campaign.status),
            ],
          ),
          const SizedBox(height: 8),

          Text(campaign.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(campaign.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary)),
          const SizedBox(height: 12),

          // Metrics
          Row(
            children: [
              _MetricChip(
                  label: 'Recipients', value: '${campaign.totalRecipients}'),
              const SizedBox(width: 16),
              _MetricChip(
                  label: 'Delivered', value: '${campaign.deliveredCount}'),
              const SizedBox(width: 16),
              _MetricChip(
                  label: 'Open Rate',
                  value: '${campaign.openRate.toStringAsFixed(1)}%'),
            ],
          ),

          // Actions
          if (campaign.status == 'draft' || campaign.status == 'scheduled') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (campaign.status == 'draft' &&
                    ctrl.hasPermission('notifications.send'))
                  FilledButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
                    onPressed: () => ctrl.sendCampaign(campaign.id),
                  ),
                if (campaign.status == 'scheduled') ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error),
                    onPressed: () => ctrl.sendCampaign(campaign.id),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CampaignStatusBadge extends StatelessWidget {
  final String status;
  const _CampaignStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'sent' || 'sending' => AppColors.success,
      'scheduled' => AppColors.info,
      'draft' => AppColors.lightTextMuted,
      'cancelled' => AppColors.error,
      _ => AppColors.lightTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.lightTextSecondary)),
      ],
    );
  }
}
