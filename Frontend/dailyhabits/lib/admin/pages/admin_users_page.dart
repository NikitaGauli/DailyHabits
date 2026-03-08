// =============================================================================
// File: admin_users_page.dart
// Description: Modern user management page with advanced data table, search,
//              filters, status chips, action menus, and user detail drawers.
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
  String _sortField = '-created_at';

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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ─── Header Row ───
              _HeaderRow(
                ctrl: ctrl,
                searchController: _searchController,
                sortField: _sortField,
                onSortChanged: (v) {
                  setState(() => _sortField = v);
                  ctrl.loadUsers(search: _searchController.text);
                },
              ),
              const SizedBox(height: 20),

              // ─── Stats Row ───
              if (page != null) _UserStatsRow(page: page, isDark: isDark),
              if (page != null) const SizedBox(height: 16),

              // ─── Table ───
              Expanded(
                child: page == null
                    ? const Center(child: CircularProgressIndicator())
                    : page.results.isEmpty
                        ? _EmptyState()
                        : _UsersTable(users: page.results, ctrl: ctrl),
              ),

              // ─── Pagination ───
              if (page != null && page.count > 0)
                _Pagination(page: page, ctrl: ctrl),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Header Row
// =============================================================================

class _HeaderRow extends StatelessWidget {
  final AdminController ctrl;
  final TextEditingController searchController;
  final String sortField;
  final ValueChanged<String> onSortChanged;

  const _HeaderRow({
    required this.ctrl,
    required this.searchController,
    required this.sortField,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        // Search
        Expanded(
          flex: 3,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email…',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          searchController.clear();
                          ctrl.loadUsers(search: '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (q) => ctrl.loadUsers(search: q),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Sort dropdown
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortField,
              icon: const Icon(Icons.sort_rounded, size: 18),
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              items: const [
                DropdownMenuItem(
                    value: '-created_at', child: Text('Newest first')),
                DropdownMenuItem(
                    value: 'created_at', child: Text('Oldest first')),
                DropdownMenuItem(value: 'email', child: Text('Email A-Z')),
                DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                DropdownMenuItem(
                    value: '-last_login', child: Text('Last active')),
              ],
              onChanged: (v) {
                if (v != null) onSortChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Refresh
        _ActionChip(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onTap: () =>
              ctrl.loadUsers(search: searchController.text),
        ),
      ],
    );
  }
}

// =============================================================================
// User Stats Row
// =============================================================================

class _UserStatsRow extends StatelessWidget {
  final PaginatedResponse<AdminUser> page;
  final bool isDark;
  const _UserStatsRow({required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = page.count;
    final active = page.results.where((u) => u.isActive && !u.isSuspended).length;
    final suspended = page.results.where((u) => u.isSuspended).length;

    return Row(
      children: [
        _MiniStat(label: 'Total', value: '$total', color: AppColors.primary),
        const SizedBox(width: 12),
        _MiniStat(label: 'Active', value: '$active', color: AppColors.success),
        const SizedBox(width: 12),
        _MiniStat(
            label: 'Suspended', value: '$suspended', color: AppColors.error),
        const Spacer(),
        Text(
          'Showing ${page.results.length} of $total',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextMuted
                : AppColors.lightTextMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            dataRowMaxHeight: 64,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('USER')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('HABITS'), numeric: true),
              DataColumn(label: Text('STREAK'), numeric: true),
              DataColumn(label: Text('JOINED')),
              DataColumn(label: Text('LAST ACTIVE')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: users.map((u) => _buildRow(context, u)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, AdminUser user) {
    return DataRow(cells: [
      // User cell with avatar
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UserAvatar(name: user.name, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              Text(user.email,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.lightTextMuted)),
            ],
          ),
        ],
      )),
      // Status
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
      DataCell(Text('${user.habitsCount}',
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.currentStreak > 0)
            Icon(Icons.local_fire_department_rounded,
                size: 16, color: AppColors.warning),
          const SizedBox(width: 2),
          Text('${user.currentStreak}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      )),
      DataCell(Text(_formatDate(user.createdAt),
          style: const TextStyle(fontSize: 13))),
      DataCell(Text(_formatDate(user.lastLogin),
          style: const TextStyle(fontSize: 13))),
      // Actions
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ctrl.hasPermission('users.suspend'))
            user.isSuspended
                ? _SmallAction(
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.success,
                    tooltip: 'Activate',
                    onTap: () => ctrl.activateUser(user.id),
                  )
                : _SmallAction(
                    icon: Icons.block_rounded,
                    color: AppColors.error,
                    tooltip: 'Suspend',
                    onTap: () => _showSuspendDialog(context, user),
                  ),
          _SmallAction(
            icon: Icons.visibility_rounded,
            color: AppColors.info,
            tooltip: 'View Details',
            onTap: () => _showUserDetails(context, user),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text('Suspend ${user.name}?'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This will immediately prevent this user from accessing the platform.',
                style: TextStyle(
                    color: AppColors.lightTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'Reason for suspension (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('Suspend User'),
            onPressed: () {
              ctrl.suspendUser(user.id, reason: reasonCtrl.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UserAvatar(name: user.name, size: 56),
              const SizedBox(height: 16),
              Text(user.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(user.email,
                  style: TextStyle(color: AppColors.lightTextSecondary)),
              const SizedBox(height: 20),
              _DetailRow(label: 'Status', value: user.isSuspended ? 'Suspended' : user.isActive ? 'Active' : 'Inactive'),
              _DetailRow(label: 'Habits', value: '${user.habitsCount}'),
              _DetailRow(label: 'Streak', value: '${user.currentStreak} days'),
              _DetailRow(label: 'Joined', value: _formatDate(user.createdAt)),
              _DetailRow(label: 'Last Login', value: _formatDate(user.lastLogin)),
              _DetailRow(label: 'Staff', value: user.isStaff ? 'Yes' : 'No'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
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
// Shared Widgets
// =============================================================================

class _UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatar({required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      AppColors.primary, AppColors.secondary, AppColors.info,
      AppColors.warning, AppColors.success, AppColors.primaryLight,
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _SmallAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.lightTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
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
  final PaginatedResponse<AdminUser> page;
  final AdminController ctrl;
  const _Pagination({required this.page, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = (page.count / 25).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${page.count} users total',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              _PaginationButton(
                icon: Icons.chevron_left_rounded,
                enabled: page.previous != null,
                onTap: () =>
                    ctrl.loadUsers(page: ctrl.usersCurrentPage - 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ctrl.usersCurrentPage} / $totalPages',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              _PaginationButton(
                icon: Icons.chevron_right_rounded,
                enabled: page.next != null,
                onTap: () =>
                    ctrl.loadUsers(page: ctrl.usersCurrentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 20,
              color: enabled
                  ? AppColors.primary
                  : AppColors.lightTextMuted),
        ),
      ),
    );
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 56, color: AppColors.lightTextMuted),
          const SizedBox(height: 12),
          const Text('No users found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Try adjusting your search or filters',
              style: TextStyle(color: AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}
