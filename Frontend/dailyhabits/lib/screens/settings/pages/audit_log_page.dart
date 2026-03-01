import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/settings_models.dart';
import '../settings_controller.dart';

/// Audit Log page — view all settings change history with category filters.
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  String? _selectedCategory;

  static const _categories = <String?, String>{
    null: 'All',
    'profile': 'Profile',
    'appearance': 'Appearance',
    'notifications': 'Notifications',
    'privacy': 'Privacy',
    'security': 'Security',
    'data': 'Data',
    'advanced': 'Advanced',
  };

  @override
  void initState() {
    super.initState();
    context.read<SettingsController>().loadAuditLogs();
  }

  void _onCategoryChanged(String? category) {
    setState(() => _selectedCategory = category);
    context.read<SettingsController>().loadAuditLogs(category: category);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final logs = ctrl.auditLogs;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Category filter chips ──
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _categories.entries.map((e) {
                final selected = _selectedCategory == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => _onCategoryChanged(e.key),
                    selectedColor: colors.primary.withValues(alpha: 0.15),
                    checkmarkColor: colors.primary,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Body ──
          Expanded(
            child: ctrl.isLoadingAuditLogs
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 48, color: colors.textMuted),
                            const SizedBox(height: 12),
                            Text('No activity yet',
                                style: TextStyle(color: colors.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ctrl.loadAuditLogs(category: _selectedCategory),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _AuditLogTile(entry: logs[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _categoryColor(entry.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.categoryIcon,
                size: 18,
                color: _categoryColor(entry.category),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.action,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _categoryColor(entry.category).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.categoryLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor(entry.category),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(entry.createdAt),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                  if (entry.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.description,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (entry.ipAddress != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.language, size: 12, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          entry.ipAddress!,
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'profile':
        return AppColors.primary;
      case 'appearance':
        return AppColors.secondary;
      case 'notifications':
        return AppColors.warning;
      case 'privacy':
        return AppColors.info;
      case 'security':
        return AppColors.error;
      case 'data':
        return const Color(0xFF8B5CF6);
      case 'advanced':
        return const Color(0xFF6366F1);
      default:
        return AppColors.primary;
    }
  }

  String _formatTimestamp(String iso) {
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 5) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
