import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';
import 'pages/appearance_page.dart';
import 'pages/notifications_page.dart';
import 'pages/quiet_hours_page.dart';
import 'pages/daily_summary_page.dart';
import 'pages/motivational_quotes_page.dart';
import 'pages/export_data_page.dart';
import 'pages/privacy_policy_page.dart';
import 'pages/help_support_page.dart';
import 'pages/profile_page.dart';
import 'pages/privacy_security_page.dart';
import 'pages/login_sessions_page.dart';
import 'pages/advanced_settings_page.dart';
import 'pages/audit_log_page.dart';
import 'package:dailyhabits/admin/admin_screen.dart';

/// The root settings screen — entry point for all user preferences.
///
/// Organized into 8 sections:
///   1. Profile          5. Privacy & Security
///   2. Appearance       6. Data & Export
///   3. Notifications    7. Help & Support
///   4. Habit Reminders  8. Advanced
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.error != null
              ? _ErrorView(error: ctrl.error!, onRetry: ctrl.loadAll)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // ── Profile ───────────────────────────────
                    _SectionHeader(title: 'Profile'),
                    _SettingsTile(
                      icon: Icons.person_outlined,
                      title: 'Profile',
                      subtitle: ctrl.profile?['email'] ?? 'Manage your account',
                      onTap: () => _push(context, const ProfilePage()),
                    ),

                    // ── Appearance ────────────────────────────
                    _SectionHeader(title: 'Appearance'),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Theme, accent color, font size',
                      onTap: () => _push(context, const AppearancePage()),
                    ),

                    // ── Notifications ─────────────────────────
                    _SectionHeader(title: 'Notifications'),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Push Notifications',
                      subtitle: 'Reminders, streaks, insights',
                      trailing: Switch.adaptive(
                        value: ctrl.notifSettings?.notificationsEnabled ?? true,
                        onChanged: ctrl.toggleNotifications,
                        activeTrackColor: colors.primary,
                      ),
                      onTap: () => _push(context, const NotificationsPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.do_not_disturb_on_outlined,
                      title: 'Quiet Hours',
                      subtitle: _quietHoursSummary(ctrl),
                      onTap: () => _push(context, const QuietHoursPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.summarize_outlined,
                      title: 'Daily Summary',
                      subtitle: ctrl.appSettings?.dailySummaryEnabled == true
                          ? 'Enabled at '
                          : 'Disabled',
                      onTap: () => _push(context, const DailySummaryPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.format_quote_outlined,
                      title: 'Motivational Quotes',
                      subtitle: ctrl.appSettings?.quotesEnabled == true
                          ? ' \u2022 '
                          : 'Disabled',
                      onTap: () => _push(context, const MotivationalQuotesPage()),
                    ),

                    // ── Privacy & Security ────────────────────
                    _SectionHeader(title: 'Privacy & Security'),
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & Security',
                      subtitle: 'Visibility, 2FA, data controls',
                      onTap: () => _push(context, const PrivacySecurityPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.devices_outlined,
                      title: 'Login Sessions',
                      subtitle: 'Manage active devices',
                      onTap: () => _push(context, const LoginSessionsPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.history_outlined,
                      title: 'Activity Log',
                      subtitle: 'Settings change history',
                      onTap: () => _push(context, const AuditLogPage()),
                    ),

                    // ── Data & Export ─────────────────────────
                    _SectionHeader(title: 'Data & Export'),
                    _SettingsTile(
                      icon: Icons.download_outlined,
                      title: 'Export Data',
                      subtitle: 'Download your habit data',
                      onTap: () => _push(context, const ExportDataPage()),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'How we protect your data',
                      onTap: () => _push(context, const PrivacyPolicyPage()),
                    ),

                    // ── Help & Support ────────────────────────
                    _SectionHeader(title: 'Help & Support'),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'FAQs, contact support',
                      onTap: () => _push(context, const HelpSupportPage()),
                    ),

                    // ── Advanced ──────────────────────────────
                    _SectionHeader(title: 'Advanced'),
                    _SettingsTile(
                      icon: Icons.tune_outlined,
                      title: 'Advanced Settings',
                      subtitle: 'Language, analytics, archive',
                      onTap: () => _push(context, const AdvancedSettingsPage()),
                    ),

                    // ── Admin Panel ───────────────────────────
                    _SectionHeader(title: 'Admin'),
                    _SettingsTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Dashboard',
                      subtitle: 'Manage users, reports, analytics',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _DeleteAccountTile(ctrl: ctrl),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<SettingsController>(),
          child: page,
        ),
      ),
    );
  }

  String _quietHoursSummary(SettingsController ctrl) {
    if (ctrl.appSettings?.quietHoursEnabled != true) return 'Disabled';
    final start = ctrl.appSettings!.quietHoursStart ?? '22:00';
    final end = ctrl.appSettings!.quietHoursEnd ?? '07:00';
    return '$start \u2013 $end';
  }
}

// ═════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colors.primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w500, color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: colors.textMuted),
      onTap: onTap,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(error),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountTile extends StatelessWidget {
  final SettingsController ctrl;
  const _DeleteAccountTile({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _showDeleteDialog(context),
        icon: const Icon(Icons.delete_forever),
        label: const Text('Delete Account'),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account and all associated data. '
              'This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ctrl.requestAccountDeletion(
                  reason: reasonCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success'] == true
                          ? 'Account deletion requested. You will receive confirmation via email.'
                          : result['error'] ?? 'Failed to request deletion',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
