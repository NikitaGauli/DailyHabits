// =============================================================================
// File: admin_reports_page.dart
// Description: Modern reports management — filter by status/priority, cards
//              with timeline, resolve actions with confirmation dialog.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.reportsPage;

        return Column(
          children: [
            // ─── Filter Bar ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Reports',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (page != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${page.count}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 13)),
                    ),
                  ],
                  const Spacer(),
                  ..._buildFilterChips(ctrl),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Content ───
            Expanded(
              child: page == null && ctrl.loading
                  ? const Center(child: CircularProgressIndicator())
                  : page == null || page.results.isEmpty
                      ? _EmptyReports()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: page.results.length,
                          itemBuilder: (ctx, i) => _ReportCard(
                            report: page.results[i],
                            ctrl: ctrl,
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFilterChips(AdminController ctrl) {
    final filters = [null, 'pending', 'under_review', 'resolved', 'dismissed'];
    final labels = ['All', 'Pending', 'Under Review', 'Resolved', 'Dismissed'];

    return [
      for (int i = 0; i < filters.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        _FilterChip(
          label: labels[i],
          selected: _statusFilter == filters[i],
          onTap: () {
            setState(() => _statusFilter = filters[i]);
            ctrl.loadReports(status: filters[i]);
          },
        ),
      ],
    ];
  }
}

// =============================================================================
// Filter Chip
// =============================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : null,
          ),
        ),
      ),
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
    final isActionable =
        report.status == 'pending' || report.status == 'under_review';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Priority accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: priorityColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            report.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: priorityColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.category.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: report.status),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  report.description.isNotEmpty
                      ? report.description
                      : '(No description provided)',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Meta info
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _MetaItem(
                        icon: Icons.person_outline_rounded,
                        label: report.reporterEmail),
                    _MetaItem(
                        icon: Icons.person_off_outlined,
                        label: report.reportedUserEmail),
                    _MetaItem(
                        icon: Icons.article_outlined,
                        label:
                            '${report.contentType} #${report.contentId.length > 8 ? report.contentId.substring(0, 8) : report.contentId}'),
                  ],
                ),

                // Action buttons
                if (isActionable &&
                    ctrl.hasPermission('moderation.approve')) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.warning_amber_rounded,
                        label: 'Warn',
                        color: AppColors.warning,
                        onTap: () => _resolve(context, 'warn'),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.block_rounded,
                        label: 'Suspend',
                        color: AppColors.error,
                        onTap: () => _resolve(context, 'suspend'),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.close_rounded,
                        label: 'Dismiss',
                        color: AppColors.lightTextMuted,
                        onTap: () => _resolve(context, 'dismiss'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resolve(BuildContext context, String action) {
    final resCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              action == 'dismiss'
                  ? Icons.close_rounded
                  : action == 'warn'
                      ? Icons.warning_amber_rounded
                      : Icons.block_rounded,
              color: _actionColor(action),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text('${action[0].toUpperCase()}${action.substring(1)} Report'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: resCtrl,
            decoration: InputDecoration(
              hintText: 'Resolution notes…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(14),
            ),
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _actionColor(action)),
            onPressed: () {
              ctrl.resolveReport(report.id,
                  action: action, resolution: resCtrl.text);
              Navigator.pop(context);
            },
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'warn':
        return AppColors.warning;
      case 'suspend':
        return AppColors.error;
      default:
        return AppColors.lightTextMuted;
    }
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
// Shared Widgets
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'resolved'
        ? AppColors.success
        : status == 'dismissed'
            ? AppColors.lightTextMuted
            : status == 'under_review'
                ? AppColors.info
                : AppColors.warning;
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
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.lightTextMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.lightTextSecondary)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
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
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          const Text('All clear!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('No reports match the current filter',
              style: TextStyle(color: AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}
