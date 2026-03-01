// =============================================================================
// File: admin_users_page.dart
// Description: User management page — paginated table with search, suspend/
//              activate actions, and user detail drill-down.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.usersPage;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Search bar
              _SearchBar(
                controller: _searchController,
                onSearch: (q) => ctrl.loadUsers(search: q),
              ),
              const SizedBox(height: 16),

              // Data table
              Expanded(
                child: page == null
                    ? const Center(child: CircularProgressIndicator())
                    : _UsersTable(
                        users: page.results,
                        ctrl: ctrl,
                      ),
              ),

              // Pagination
              if (page != null) _Pagination(page: page, ctrl: ctrl),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Search Bar
// =============================================================================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search users by name or email…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              controller.clear();
              onSearch('');
            },
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: onSearch,
      ),
    );
  }
}

// =============================================================================
// Users Table
// =============================================================================

class _UsersTable extends StatelessWidget {
  final List<AdminUser> users;
  final AdminController ctrl;
  const _UsersTable({required this.users, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            ),
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Habits'), numeric: true),
              DataColumn(label: Text('Streak'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Joined')),
              DataColumn(label: Text('Actions')),
            ],
            rows: users.map((u) => _buildRow(context, u)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, AdminUser user) {
    return DataRow(cells: [
      DataCell(Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(user.email)),
      DataCell(Text('${user.habitsCount}')),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.currentStreak > 0)
            Icon(Icons.local_fire_department,
                size: 16, color: AppColors.warning),
          Text(' ${user.currentStreak}'),
        ],
      )),
      DataCell(_StatusChip(
        label: user.isSuspended
            ? 'Suspended'
            : user.isActive
                ? 'Active'
                : 'Inactive',
        color: user.isSuspended
            ? AppColors.error
            : user.isActive
                ? AppColors.success
                : AppColors.lightTextMuted,
      )),
      DataCell(Text(_formatDate(user.createdAt))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ctrl.hasPermission('users.suspend'))
            user.isSuspended
                ? IconButton(
                    icon: Icon(Icons.play_arrow_rounded,
                        color: AppColors.success, size: 20),
                    tooltip: 'Activate',
                    onPressed: () => ctrl.activateUser(user.id),
                  )
                : IconButton(
                    icon: Icon(Icons.block_rounded,
                        color: AppColors.error, size: 20),
                    tooltip: 'Suspend',
                    onPressed: () => _showSuspendDialog(context, user),
                  ),
        ],
      )),
    ]);
  }

  void _showSuspendDialog(BuildContext context, AdminUser user) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Suspend ${user.name}?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason for suspension (optional)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ctrl.suspendUser(user.id, reason: reasonCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Pagination
// =============================================================================

class _Pagination extends StatelessWidget {
  final PaginatedResponse<AdminUser> page;
  final AdminController ctrl;
  const _Pagination({required this.page, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final totalPages = (page.count / 25).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${page.count} users total',
              style: TextStyle(color: AppColors.lightTextSecondary)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.previous != null
                    ? () =>
                        ctrl.loadUsers(page: ctrl.usersCurrentPage - 1)
                    : null,
              ),
              Text('Page ${ctrl.usersCurrentPage} of $totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page.next != null
                    ? () =>
                        ctrl.loadUsers(page: ctrl.usersCurrentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared Status Chip
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
