// =============================================================================
// File: admin_shell.dart
// Description: Main layout shell for the Admin Dashboard — sidebar navigation,
//              top app bar, and content area. Responsive for web layout.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/pages/admin_dashboard_page.dart';
import 'package:dailyhabits/admin/pages/admin_users_page.dart';
import 'package:dailyhabits/admin/pages/admin_reports_page.dart';
import 'package:dailyhabits/admin/pages/admin_moderation_page.dart';
import 'package:dailyhabits/admin/pages/admin_analytics_page.dart';
import 'package:dailyhabits/admin/pages/admin_settings_page.dart';
import 'package:dailyhabits/admin/pages/admin_feature_flags_page.dart';
import 'package:dailyhabits/admin/pages/admin_notifications_page.dart';
import 'package:dailyhabits/admin/pages/admin_audit_logs_page.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    // Initialize admin data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        if (ctrl.profile == null && ctrl.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (ctrl.profile == null && ctrl.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings,
                      size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Admin Access Required',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(ctrl.error!,
                      style: TextStyle(color: AppColors.lightTextSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _AdminSidebar(ctrl: ctrl),
              Expanded(
                child: Column(
                  children: [
                    _AdminTopBar(ctrl: ctrl),
                    if (ctrl.error != null) _ErrorBanner(ctrl: ctrl),
                    Expanded(child: _buildPage(ctrl.currentPage)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(AdminPage page) {
    switch (page) {
      case AdminPage.dashboard:
        return const AdminDashboardPage();
      case AdminPage.users:
        return const AdminUsersPage();
      case AdminPage.reports:
        return const AdminReportsPage();
      case AdminPage.moderation:
        return const AdminModerationPage();
      case AdminPage.analytics:
        return const AdminAnalyticsPage();
      case AdminPage.settings:
        return const AdminSettingsPage();
      case AdminPage.featureFlags:
        return const AdminFeatureFlagsPage();
      case AdminPage.notifications:
        return const AdminNotificationsPage();
      case AdminPage.auditLogs:
        return const AdminAuditLogsPage();
    }
  }
}

// =============================================================================
// Sidebar
// =============================================================================

class _AdminSidebar extends StatelessWidget {
  final AdminController ctrl;
  const _AdminSidebar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : const Color(0xFF1E293B);
    final selectedBg = AppColors.primary.withValues(alpha: 0.15);

    return Container(
      width: 260,
      color: bg,
      child: Column(
        children: [
          // Logo / Brand
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DailyHabits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _NavSection(label: 'OVERVIEW'),
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  page: AdminPage.dashboard,
                  current: ctrl.currentPage,
                  selectedBg: selectedBg,
                  onTap: () => ctrl.navigateTo(AdminPage.dashboard),
                ),

                const SizedBox(height: 16),
                _NavSection(label: 'MANAGEMENT'),
                if (ctrl.hasPermission('users.view'))
                  _NavItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Users',
                    page: AdminPage.users,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.users),
                  ),
                if (ctrl.hasPermission('moderation.view'))
                  _NavItem(
                    icon: Icons.flag_rounded,
                    label: 'Reports',
                    page: AdminPage.reports,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.reports),
                  ),
                if (ctrl.hasPermission('moderation.approve'))
                  _NavItem(
                    icon: Icons.gavel_rounded,
                    label: 'Moderation',
                    page: AdminPage.moderation,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.moderation),
                  ),

                const SizedBox(height: 16),
                _NavSection(label: 'INSIGHTS'),
                if (ctrl.hasPermission('analytics.view'))
                  _NavItem(
                    icon: Icons.analytics_rounded,
                    label: 'Analytics',
                    page: AdminPage.analytics,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.analytics),
                  ),
                if (ctrl.hasPermission('audit.view'))
                  _NavItem(
                    icon: Icons.history_rounded,
                    label: 'Audit Logs',
                    page: AdminPage.auditLogs,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.auditLogs),
                  ),

                const SizedBox(height: 16),
                _NavSection(label: 'CONFIGURATION'),
                if (ctrl.hasPermission('settings.view'))
                  _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    page: AdminPage.settings,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.settings),
                  ),
                if (ctrl.hasPermission('feature_flags.manage'))
                  _NavItem(
                    icon: Icons.toggle_on_rounded,
                    label: 'Feature Flags',
                    page: AdminPage.featureFlags,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.featureFlags),
                  ),
                if (ctrl.hasPermission('notifications.view'))
                  _NavItem(
                    icon: Icons.campaign_rounded,
                    label: 'Notifications',
                    page: AdminPage.notifications,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    onTap: () => ctrl.navigateTo(AdminPage.notifications),
                  ),
              ],
            ),
          ),

          // Profile footer
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (ctrl.profile?.userName ?? 'A').isNotEmpty
                        ? ctrl.profile!.userName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ctrl.profile?.userName ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ctrl.profile?.roleName ?? '',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AdminPage page;
  final AdminPage current;
  final Color selectedBg;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.page,
    required this.current,
    required this.selectedBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == page;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color:
                        selected ? AppColors.primary : Colors.white70),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : Colors.white70,
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Top Bar
// =============================================================================

class _AdminTopBar extends StatelessWidget {
  final AdminController ctrl;
  const _AdminTopBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _pageTitles[ctrl.currentPage] ?? 'Dashboard',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (ctrl.loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 16),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ctrl.navigateTo(ctrl.currentPage),
          ),
        ],
      ),
    );
  }

  static const Map<AdminPage, String> _pageTitles = {
    AdminPage.dashboard: 'Dashboard',
    AdminPage.users: 'User Management',
    AdminPage.reports: 'Reports',
    AdminPage.moderation: 'Content Moderation',
    AdminPage.analytics: 'Analytics',
    AdminPage.settings: 'System Settings',
    AdminPage.featureFlags: 'Feature Flags',
    AdminPage.notifications: 'Notification Campaigns',
    AdminPage.auditLogs: 'Audit Logs',
  };
}

// =============================================================================
// Error Banner
// =============================================================================

class _ErrorBanner extends StatelessWidget {
  final AdminController ctrl;
  const _ErrorBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: AppColors.error.withValues(alpha: 0.1),
      leading: Icon(Icons.error_outline, color: AppColors.error),
      content: Text(ctrl.error!),
      actions: [
        TextButton(
          onPressed: ctrl.clearError,
          child: const Text('DISMISS'),
        ),
      ],
    );
  }
}
