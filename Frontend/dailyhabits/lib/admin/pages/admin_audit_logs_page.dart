// =============================================================================
// File: admin_audit_logs_page.dart
// Description: Audit logs viewer — paginated, filterable, read-only timeline
//              of all admin actions.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminAuditLogsPage extends StatelessWidget {
  const AdminAuditLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.auditLogsPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return const Center(child: Text('No audit log entries'));
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: page.results.length,
                itemBuilder: (_, i) => _LogRow(entry: page.results[i]),
              ),
            ),
            _AuditPagination(page: page, ctrl: ctrl),
          ],
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  final AuditLogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _severityColor(entry.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity indicator
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.action.replaceAll('_', ' '),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(entry.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: AppColors.lightTextMuted),
                    const SizedBox(width: 4),
                    Text(entry.adminEmail,
                        style: const TextStyle(fontSize: 12)),
                    if (entry.resourceType.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.category,
                          size: 14, color: AppColors.lightTextMuted),
                      const SizedBox(width: 4),
                      Text(entry.resourceType,
                          style: const TextStyle(fontSize: 12)),
                    ],
                    if (entry.ipAddress != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.language,
                          size: 14, color: AppColors.lightTextMuted),
                      const SizedBox(width: 4),
                      Text(entry.ipAddress!,
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      case 'info':
        return AppColors.info;
      default:
        return AppColors.lightTextMuted;
    }
  }

  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AuditPagination extends StatelessWidget {
  final PaginatedResponse<AuditLogEntry> page;
  final AdminController ctrl;
  const _AuditPagination({required this.page, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.count} entries',
              style: const TextStyle(color: AppColors.lightTextSecondary)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.previous != null
                    ? () => ctrl.loadAuditLogs(
                        page: (page.previous != null) ? 1 : 1)
                    : null,
              ),
              const Text('Page'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    page.next != null ? () => ctrl.loadAuditLogs() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
