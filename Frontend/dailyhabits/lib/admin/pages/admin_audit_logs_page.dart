// =============================================================================
// File: admin_audit_logs_page.dart
// Description: Modern audit logs viewer — timeline view with severity tags,
//              resource details, filters, and search.
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
          return _EmptyLogs();
        }
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('Audit Logs',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${page.count} entries',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                            fontSize: 12)),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ctrl.loadAuditLogs(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          const Text('Refresh',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Timeline
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: page.results.length,
                itemBuilder: (_, i) => _AuditLogRow(
                  entry: page.results[i],
                  isLast: i == page.results.length - 1,
                ),
              ),
            ),
            // Pagination
            _Pagination(page: page, ctrl: ctrl),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Audit Log Row — Timeline style
// =============================================================================

class _AuditLogRow extends StatefulWidget {
  final AuditLogEntry entry;
  final bool isLast;
  const _AuditLogRow({required this.entry, required this.isLast});

  @override
  State<_AuditLogRow> createState() => _AuditLogRowState();
}

class _AuditLogRowState extends State<_AuditLogRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = widget.entry;
    final sevColor = _severityColor(entry.severity);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline pillar
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: sevColor, width: 2),
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content card
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _expanded
                        ? sevColor.withValues(alpha: 0.3)
                        : isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      children: [
                        _SeverityBadge(
                            severity: entry.severity, color: sevColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.action.replaceAll('_', ' '),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        Text(
                          _formatTimestamp(entry.createdAt),
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      entry.description,
                      maxLines: _expanded ? 10 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    // Meta chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                            icon: Icons.person_outline_rounded,
                            label: entry.adminEmail),
                        if (entry.resourceType.isNotEmpty)
                          _MetaChip(
                              icon: Icons.category_rounded,
                              label: entry.resourceType),
                        if (entry.ipAddress != null)
                          _MetaChip(
                              icon: Icons.language_rounded,
                              label: entry.ipAddress!),
                      ],
                    ),
                    // Expanded details
                    if (_expanded) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow('Admin', entry.adminEmail),
                            if (entry.resourceType.isNotEmpty)
                              _DetailRow('Resource', entry.resourceType),
                            if (entry.resourceId.isNotEmpty)
                              _DetailRow('Resource ID', entry.resourceId),
                            if (entry.ipAddress != null)
                              _DetailRow('IP Address', entry.ipAddress!),
                            _DetailRow('Timestamp', entry.createdAt),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Small Widgets
// =============================================================================

class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color color;
  const _SeverityBadge({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5),
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
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.lightTextSecondary)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Pagination
// =============================================================================

class _Pagination extends StatelessWidget {
  final PaginatedResponse<AuditLogEntry> page;
  final AdminController ctrl;
  const _Pagination({required this.page, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = (page.count / 25).ceil();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.count} entries total',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted)),
          Row(
            children: [
              _PageBtn(
                icon: Icons.chevron_left_rounded,
                enabled: page.previous != null,
                onTap: () => ctrl.loadAuditLogs(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page 1 / $totalPages',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              _PageBtn(
                icon: Icons.chevron_right_rounded,
                enabled: page.next != null,
                onTap: () => ctrl.loadAuditLogs(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(icon,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.lightTextMuted),
        ),
      ),
    );
  }
}

class _EmptyLogs extends StatelessWidget {
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
              color: AppColors.info.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                size: 40, color: AppColors.info),
          ),
          const SizedBox(height: 16),
          const Text('No audit log entries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Actions will appear here as they are logged',
              style: TextStyle(color: AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}
