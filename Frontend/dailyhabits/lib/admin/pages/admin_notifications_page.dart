// =============================================================================
// File: admin_notifications_page.dart
// Description: Modern notification campaigns page — campaign cards with
//              delivery metrics, create dialog, send/cancel actions.
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
          return _EmptyCampaigns(ctrl: ctrl);
        }

        final drafts = page.results.where((c) => c.status == 'draft').length;
        final sent = page.results.where((c) => c.status == 'sent' || c.status == 'sending').length;

        return Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('Campaigns',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  _Badge('${page.count} total', AppColors.primary),
                  const SizedBox(width: 6),
                  _Badge('$drafts drafts', AppColors.lightTextMuted),
                  const SizedBox(width: 6),
                  _Badge('$sent sent', AppColors.success),
                  const Spacer(),
                  if (ctrl.hasPermission('notifications.send'))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Campaign'),
                      onPressed: () => _showCreateDialog(context, ctrl),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: page.results.length,
                itemBuilder: (_, i) =>
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('New Campaign'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Campaign Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: bodyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Message Body',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: InputDecoration(
                    labelText: 'Target Audience',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('All Users')),
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

// =============================================================================
// Campaign Card
// =============================================================================

class _CampaignCard extends StatefulWidget {
  final NotificationCampaign campaign;
  final AdminController ctrl;
  const _CampaignCard({required this.campaign, required this.ctrl});

  @override
  State<_CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<_CampaignCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final campaign = widget.campaign;
    final ctrl = widget.ctrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovering
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(campaign.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(campaign.status),
                      size: 20, color: _statusColor(campaign.status)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(campaign.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(campaign.title,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary)),
                    ],
                  ),
                ),
                _StatusBadge(status: campaign.status),
              ],
            ),
            const SizedBox(height: 12),

            // Body preview
            Text(campaign.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4)),
            const SizedBox(height: 16),

            // Metrics row
            Row(
              children: [
                _MetricTile(
                  icon: Icons.people_rounded,
                  label: 'Recipients',
                  value: '${campaign.totalRecipients}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                _MetricTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Delivered',
                  value: '${campaign.deliveredCount}',
                  color: AppColors.success,
                ),
                const SizedBox(width: 16),
                _MetricTile(
                  icon: Icons.remove_red_eye_rounded,
                  label: 'Open Rate',
                  value: '${campaign.openRate.toStringAsFixed(1)}%',
                  color: AppColors.info,
                ),
                const Spacer(),
                // Actions
                if (campaign.status == 'draft' &&
                    ctrl.hasPermission('notifications.send'))
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Send'),
                    onPressed: () => ctrl.sendCampaign(campaign.id),
                  ),
                if (campaign.status == 'scheduled')
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => ctrl.sendCampaign(campaign.id),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'sent' || 'sending' => AppColors.success,
      'scheduled' => AppColors.info,
      'draft' => AppColors.lightTextMuted,
      'cancelled' => AppColors.error,
      _ => AppColors.lightTextSecondary,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'sent' || 'sending' => Icons.check_circle_rounded,
      'scheduled' => Icons.schedule_rounded,
      'draft' => Icons.edit_note_rounded,
      'cancelled' => Icons.cancel_rounded,
      _ => Icons.campaign_rounded,
    };
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(status,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.lightTextSecondary)),
          ],
        ),
      ],
    );
  }
}

class _EmptyCampaigns extends StatelessWidget {
  final AdminController ctrl;
  const _EmptyCampaigns({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No campaigns yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Create your first notification campaign',
              style: TextStyle(color: AppColors.lightTextSecondary)),
          if (ctrl.hasPermission('notifications.send')) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Campaign'),
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }
}
