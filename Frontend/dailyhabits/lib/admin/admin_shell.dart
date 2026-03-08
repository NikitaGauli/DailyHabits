// =============================================================================
// File: admin_shell.dart
// Description: Modern SaaS-quality admin layout shell — collapsible sidebar,
//              glassmorphism top bar, breadcrumbs, responsive design.
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
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

class _AdminShellState extends State<AdminShell>
    with SingleTickerProviderStateMixin {
  bool _sidebarCollapsed = false;
  bool _sidebarHovered = false;
  late final AnimationController _sidebarAnim;
  late final Animation<double> _sidebarWidth;

  static const double expandedWidth = 260;
  static const double collapsedWidth = 72;

  @override
  void initState() {
    super.initState();
    _sidebarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _sidebarWidth = Tween<double>(
      begin: expandedWidth,
      end: collapsedWidth,
    ).animate(CurvedAnimation(parent: _sidebarAnim, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().init();
    });
  }

  @override
  void dispose() {
    _sidebarAnim.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    if (_sidebarCollapsed) {
      _sidebarAnim.forward();
    } else {
      _sidebarAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        if (ctrl.profile == null && ctrl.loading) {
          return Scaffold(
            backgroundColor: _bg(context),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text('Loading Admin Panel…',
                      style: TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          );
        }
        if (ctrl.profile == null && ctrl.error != null) {
          return Scaffold(
            backgroundColor: _bg(context),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          size: 32, color: AppColors.error),
                    ),
                    const SizedBox(height: 20),
                    Text('Admin Access Required',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(ctrl.error!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.lightTextSecondary)),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon:
                            const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Go Back'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: _bg(context),
          body: Row(
            children: [
              // Animated sidebar
              AnimatedBuilder(
                animation: _sidebarWidth,
                builder: (context, _) => _AdminSidebar(
                  ctrl: ctrl,
                  width: _sidebarWidth.value,
                  collapsed: _sidebarCollapsed,
                  hovered: _sidebarHovered,
                  onHoverChange: (h) =>
                      setState(() => _sidebarHovered = h),
                  onToggle: _toggleSidebar,
                ),
              ),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    _AdminTopBar(
                      ctrl: ctrl,
                      onToggleSidebar: _toggleSidebar,
                      sidebarCollapsed: _sidebarCollapsed,
                    ),
                    if (ctrl.error != null) _ErrorBanner(ctrl: ctrl),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildPage(ctrl.currentPage),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _bg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkBg : const Color(0xFFF1F5F9);
  }

  Widget _buildPage(AdminPage page) {
    switch (page) {
      case AdminPage.dashboard:
        return const AdminDashboardPage(key: ValueKey('dashboard'));
      case AdminPage.users:
        return const AdminUsersPage(key: ValueKey('users'));
      case AdminPage.reports:
        return const AdminReportsPage(key: ValueKey('reports'));
      case AdminPage.moderation:
        return const AdminModerationPage(key: ValueKey('moderation'));
      case AdminPage.analytics:
        return const AdminAnalyticsPage(key: ValueKey('analytics'));
      case AdminPage.settings:
        return const AdminSettingsPage(key: ValueKey('settings'));
      case AdminPage.featureFlags:
        return const AdminFeatureFlagsPage(key: ValueKey('featureFlags'));
      case AdminPage.notifications:
        return const AdminNotificationsPage(key: ValueKey('notifications'));
      case AdminPage.auditLogs:
        return const AdminAuditLogsPage(key: ValueKey('auditLogs'));
    }
  }
}

// =============================================================================
// Sidebar
// =============================================================================

class _AdminSidebar extends StatelessWidget {
  final AdminController ctrl;
  final double width;
  final bool collapsed;
  final bool hovered;
  final ValueChanged<bool> onHoverChange;
  final VoidCallback onToggle;

  const _AdminSidebar({
    required this.ctrl,
    required this.width,
    required this.collapsed,
    required this.hovered,
    required this.onHoverChange,
    required this.onToggle,
  });

  bool get _showLabels => !collapsed || hovered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final selectedBg = AppColors.primary.withValues(alpha: 0.15);
    final effectiveWidth =
        (collapsed && hovered) ? _AdminShellState.expandedWidth : width;

    return MouseRegion(
      onEnter: (_) => onHoverChange(true),
      onExit: (_) => onHoverChange(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: effectiveWidth,
        decoration: BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── Logo ───
            _SidebarLogo(showLabel: _showLabels),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            // ─── Navigation ───
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  if (_showLabels) const _NavSection(label: 'OVERVIEW'),
                  _NavItem(
                    icon: Icons.space_dashboard_rounded,
                    label: 'Dashboard',
                    page: AdminPage.dashboard,
                    current: ctrl.currentPage,
                    selectedBg: selectedBg,
                    showLabel: _showLabels,
                    onTap: () => ctrl.navigateTo(AdminPage.dashboard),
                  ),

                  SizedBox(height: _showLabels ? 16 : 8),
                  if (_showLabels) const _NavSection(label: 'MANAGEMENT'),
                  if (ctrl.hasPermission('users.view'))
                    _NavItem(
                      icon: Icons.people_alt_rounded,
                      label: 'Users',
                      page: AdminPage.users,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      badge: ctrl.overviewStats != null &&
                              ctrl.overviewStats!.newUsersToday > 0
                          ? '${ctrl.overviewStats!.newUsersToday}'
                          : null,
                      onTap: () => ctrl.navigateTo(AdminPage.users),
                    ),
                  if (ctrl.hasPermission('moderation.view'))
                    _NavItem(
                      icon: Icons.flag_rounded,
                      label: 'Reports',
                      page: AdminPage.reports,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      badge: ctrl.overviewStats != null &&
                              ctrl.overviewStats!.pendingReports > 0
                          ? '${ctrl.overviewStats!.pendingReports}'
                          : null,
                      badgeColor: AppColors.error,
                      onTap: () => ctrl.navigateTo(AdminPage.reports),
                    ),
                  if (ctrl.hasPermission('moderation.approve'))
                    _NavItem(
                      icon: Icons.gavel_rounded,
                      label: 'Moderation',
                      page: AdminPage.moderation,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () => ctrl.navigateTo(AdminPage.moderation),
                    ),

                  SizedBox(height: _showLabels ? 16 : 8),
                  if (_showLabels) const _NavSection(label: 'INSIGHTS'),
                  if (ctrl.hasPermission('analytics.view'))
                    _NavItem(
                      icon: Icons.insights_rounded,
                      label: 'Analytics',
                      page: AdminPage.analytics,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () => ctrl.navigateTo(AdminPage.analytics),
                    ),
                  if (ctrl.hasPermission('audit.view'))
                    _NavItem(
                      icon: Icons.shield_rounded,
                      label: 'Audit Logs',
                      page: AdminPage.auditLogs,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () => ctrl.navigateTo(AdminPage.auditLogs),
                    ),

                  SizedBox(height: _showLabels ? 16 : 8),
                  if (_showLabels)
                    const _NavSection(label: 'CONFIGURATION'),
                  if (ctrl.hasPermission('settings.view'))
                    _NavItem(
                      icon: Icons.tune_rounded,
                      label: 'Settings',
                      page: AdminPage.settings,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () => ctrl.navigateTo(AdminPage.settings),
                    ),
                  if (ctrl.hasPermission('feature_flags.manage'))
                    _NavItem(
                      icon: Icons.toggle_on_rounded,
                      label: 'Feature Flags',
                      page: AdminPage.featureFlags,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () =>
                          ctrl.navigateTo(AdminPage.featureFlags),
                    ),
                  if (ctrl.hasPermission('notifications.view'))
                    _NavItem(
                      icon: Icons.campaign_rounded,
                      label: 'Campaigns',
                      page: AdminPage.notifications,
                      current: ctrl.currentPage,
                      selectedBg: selectedBg,
                      showLabel: _showLabels,
                      onTap: () =>
                          ctrl.navigateTo(AdminPage.notifications),
                    ),
                ],
              ),
            ),

            // ─── Profile Footer ───
            const Divider(color: Colors.white10, height: 1),
            _SidebarProfile(
                profile: ctrl.profile, showLabel: _showLabels),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sidebar Sub-Widgets
// =============================================================================

class _SidebarLogo extends StatelessWidget {
  final bool showLabel;
  const _SidebarLogo({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 18 : 0),
      alignment: showLabel ? Alignment.centerLeft : Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 20),
          ),
          if (showLabel) ...[
            const SizedBox(width: 12),
            const Text(
              'DailyHabits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Text(
              'Admin',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarProfile extends StatelessWidget {
  final dynamic profile;
  final bool showLabel;
  const _SidebarProfile(
      {required this.profile, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final name = (profile as AdminProfile?)?.userName ?? 'Admin';
    final role = (profile as AdminProfile?)?.roleName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_horiz,
                color: Colors.white.withValues(alpha: 0.4), size: 18),
          ],
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
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final AdminPage page;
  final AdminPage current;
  final Color selectedBg;
  final bool showLabel;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.page,
    required this.current,
    required this.selectedBg,
    required this.showLabel,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.current == widget.page;
    final bgColor = selected
        ? widget.selectedBg
        : _hovered
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.transparent;
    final iconColor = selected
        ? AppColors.primary
        : _hovered
            ? Colors.white
            : Colors.white.withValues(alpha: 0.65);
    final textColor =
        selected ? AppColors.primary : Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? 12 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: widget.showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (selected)
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(widget.icon, size: 20, color: iconColor),
                if (widget.showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.badgeColor ?? AppColors.primary)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.badge!,
                        style: TextStyle(
                          color: widget.badgeColor ?? AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
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
  final VoidCallback onToggleSidebar;
  final bool sidebarCollapsed;

  const _AdminTopBar({
    required this.ctrl,
    required this.onToggleSidebar,
    required this.sidebarCollapsed,
  });

  static const Map<AdminPage, String> _pageTitles = {
    AdminPage.dashboard: 'Dashboard',
    AdminPage.users: 'User Management',
    AdminPage.reports: 'Reports',
    AdminPage.moderation: 'Content Moderation',
    AdminPage.analytics: 'Analytics & Insights',
    AdminPage.settings: 'System Settings',
    AdminPage.featureFlags: 'Feature Flags',
    AdminPage.notifications: 'Notification Campaigns',
    AdminPage.auditLogs: 'Audit Logs',
  };

  static const Map<AdminPage, IconData> _pageIcons = {
    AdminPage.dashboard: Icons.space_dashboard_rounded,
    AdminPage.users: Icons.people_alt_rounded,
    AdminPage.reports: Icons.flag_rounded,
    AdminPage.moderation: Icons.gavel_rounded,
    AdminPage.analytics: Icons.insights_rounded,
    AdminPage.settings: Icons.tune_rounded,
    AdminPage.featureFlags: Icons.toggle_on_rounded,
    AdminPage.notifications: Icons.campaign_rounded,
    AdminPage.auditLogs: Icons.shield_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkCard : Colors.white)
                .withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Sidebar toggle
              IconButton(
                icon: AnimatedRotation(
                  turns: sidebarCollapsed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child:
                      const Icon(Icons.menu_open_rounded, size: 22),
                ),
                tooltip: sidebarCollapsed
                    ? 'Expand sidebar'
                    : 'Collapse sidebar',
                onPressed: onToggleSidebar,
              ),
              const SizedBox(width: 8),

              // Page icon + title + breadcrumb
              Icon(
                _pageIcons[ctrl.currentPage] ?? Icons.dashboard,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pageTitles[ctrl.currentPage] ?? 'Dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                  ),
                  Text(
                    'Admin / ${_pageTitles[ctrl.currentPage] ?? 'Dashboard'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Loading indicator
              if (ctrl.loading)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              // Refresh
              _TopBarAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: () => ctrl.navigateTo(ctrl.currentPage),
              ),
              const SizedBox(width: 4),

              // Notifications bell with badge
              Stack(
                children: [
                  _TopBarAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    onTap: () {},
                  ),
                  if ((ctrl.overviewStats?.pendingReports ?? 0) > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Divider
              Container(
                width: 1,
                height: 28,
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              const SizedBox(width: 12),

              // Admin chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (ctrl.profile?.userName ?? 'A').isNotEmpty
                              ? ctrl.profile!.userName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ctrl.profile?.userName ?? 'Admin',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.lightTextMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
      ),
    );
  }
}

// =============================================================================
// Error Banner
// =============================================================================

class _ErrorBanner extends StatelessWidget {
  final AdminController ctrl;
  const _ErrorBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ctrl.error!,
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: AppColors.error),
            onPressed: ctrl.clearError,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
