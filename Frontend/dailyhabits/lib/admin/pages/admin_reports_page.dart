// =============================================================================
// File: admin_reports_page.dart
// Description: Reports management page — view/filter reports and resolve them
//              with actions (warn, suspend, ban, remove_content, dismiss).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.reportsPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: AppColors.success),
                SizedBox(height: 12),
                Text('No reports to review'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: page.results.length,
          itemBuilder: (context, i) =>
              _ReportCard(report: page.results[i], ctrl: ctrl),
        );
      },
    );
  }
}

// =============================================================================
// Report Card
// =============================================================================

class _ReportCard extends StatelessWidget {
  final Report report;
  final AdminController ctrl;
  const _ReportCard({required this.report, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _priorityColor(report.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _PriorityDot(color: priorityColor),
                const SizedBox(width: 8),
                Text(
                  report.category.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              report.description.isNotEmpty
                  ? report.description
                  : '(No description)',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Meta
            Row(
              children: [
                _MetaChip(
                    icon: Icons.person,
                    label: 'Reporter: ${report.reporterEmail}'),
                const SizedBox(width: 12),
                _MetaChip(
                    icon: Icons.person_off,
                    label: 'Reported: ${report.reportedUserEmail}'),
              ],
            ),
            const SizedBox(height: 8),
            _MetaChip(
                icon: Icons.category,
                label:
                    '${report.contentType} #${report.contentId.length > 8 ? report.contentId.substring(0, 8) : report.contentId}…'),

            // Actions
            if (report.status == 'pending' ||
                report.status == 'under_review') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (ctrl.hasPermission('moderation.approve')) ...[
                    _ActionButton(
                      label: 'Warn',
                      color: AppColors.warning,
                      onTap: () => _resolve(context, 'warn'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Suspend',
                      color: AppColors.error,
                      onTap: () => _resolve(context, 'suspend'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Dismiss',
                      color: AppColors.lightTextMuted,
                      onTap: () => _resolve(context, 'dismiss'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resolve(BuildContext context, String action) {
    final resolutionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Resolve — $action'),
        content: TextField(
          controller: resolutionCtrl,
          decoration:
              const InputDecoration(hintText: 'Resolution notes…'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ctrl.resolveReport(report.id,
                  action: action, resolution: resolutionCtrl.text);
              Navigator.pop(context);
            },
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      default:
        return AppColors.lightTextSecondary;
    }
  }
}

// =============================================================================
// Small Widgets
// =============================================================================

class _PriorityDot extends StatelessWidget {
  final Color color;
  const _PriorityDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'resolved'
        ? AppColors.success
        : status == 'dismissed'
            ? AppColors.lightTextMuted
            : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.lightTextMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.lightTextSecondary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
