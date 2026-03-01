import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Privacy & Security page — combined privacy controls, security toggles,
/// and password management in a single scrollable page.
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  @override
  void initState() {
    super.initState();
    final ctrl = context.read<SettingsController>();
    if (ctrl.privacySettings == null) ctrl.loadPrivacySettings();
    if (ctrl.securitySettings == null) ctrl.loadSecuritySettings();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final priv = ctrl.privacySettings;
    final sec = ctrl.securitySettings;
    final loading = ctrl.isLoadingPrivacy || ctrl.isLoadingSecurity;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security'), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Privacy Section ──────────────────────────
                _SectionTitle(title: 'Account Visibility', icon: Icons.visibility_outlined),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DropdownRow(
                          label: 'Account Visibility',
                          value: priv?.accountVisibility ?? 'friends',
                          options: const {'public': 'Public', 'friends': 'Friends Only', 'private': 'Private'},
                          onChanged: (v) => ctrl.setAccountVisibility(v),
                        ),
                        const Divider(height: 24),
                        _SwitchRow(
                          label: 'Show Profile in Search',
                          value: priv?.showProfileInSearch ?? true,
                          onChanged: ctrl.setShowProfileInSearch,
                        ),
                        _SwitchRow(
                          label: 'Show in Leaderboard',
                          value: priv?.showInLeaderboard ?? true,
                          onChanged: ctrl.setShowInLeaderboard,
                        ),
                        _SwitchRow(
                          label: 'Show Online Status',
                          value: priv?.showOnlineStatus ?? true,
                          onChanged: ctrl.setShowOnlineStatus,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _SectionTitle(title: 'Sharing Controls', icon: Icons.share_outlined),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DropdownRow(
                          label: 'Who Can View Habits',
                          value: priv?.whoCanViewHabits ?? 'friends',
                          options: const {'everyone': 'Everyone', 'friends': 'Friends Only', 'nobody': 'Nobody'},
                          onChanged: (v) => ctrl.setWhoCanViewHabits(v),
                        ),
                        const SizedBox(height: 12),
                        _DropdownRow(
                          label: 'Who Can View Streaks',
                          value: priv?.whoCanViewStreaks ?? 'friends',
                          options: const {'everyone': 'Everyone', 'friends': 'Friends Only', 'nobody': 'Nobody'},
                          onChanged: (v) => ctrl.setWhoCanViewStreaks(v),
                        ),
                        const Divider(height: 24),
                        _SwitchRow(
                          label: 'Share Progress with Groups',
                          value: priv?.shareProgressWithGroups ?? true,
                          onChanged: ctrl.setShareProgressWithGroups,
                        ),
                        _DropdownRow(
                          label: 'Friend Requests From',
                          value: priv?.whoCanSendFriendRequests ?? 'everyone',
                          options: const {'everyone': 'Everyone', 'friends_of_friends': 'Friends of Friends', 'nobody': 'Nobody'},
                          onChanged: (v) => ctrl.setWhoCanSendFriendRequests(v),
                        ),
                        const SizedBox(height: 8),
                        _SwitchRow(
                          label: 'Allow Group Invites',
                          value: priv?.allowGroupInvites ?? true,
                          onChanged: ctrl.setAllowGroupInvites,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _SectionTitle(title: 'Data & AI', icon: Icons.analytics_outlined),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SwitchRow(
                          label: 'Share Anonymous Usage Data',
                          subtitle: 'Helps improve the app experience',
                          value: priv?.shareAnonymousUsageData ?? true,
                          onChanged: ctrl.setShareAnonymousUsageData,
                        ),
                        _SwitchRow(
                          label: 'Allow AI Training',
                          subtitle: 'Let AI learn from your patterns',
                          value: priv?.allowAiTraining ?? false,
                          onChanged: ctrl.setAllowAiTraining,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Security Section ─────────────────────────
                _SectionTitle(title: 'Security', icon: Icons.lock_outlined),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SwitchRow(
                          label: 'Two-Factor Authentication',
                          subtitle: sec?.twoFactorEnabled == true
                              ? 'Enabled via ${sec!.twoFactorMethod}'
                              : 'Add an extra layer of security',
                          value: sec?.twoFactorEnabled ?? false,
                          onChanged: ctrl.setTwoFactorEnabled,
                        ),
                        if (sec?.twoFactorEnabled == true) ...[
                          const SizedBox(height: 8),
                          _DropdownRow(
                            label: '2FA Method',
                            value: sec?.twoFactorMethod ?? 'email',
                            options: const {'email': 'Email', 'authenticator': 'Authenticator App'},
                            onChanged: (v) => ctrl.setTwoFactorMethod(v),
                          ),
                        ],
                        const Divider(height: 24),
                        _SwitchRow(
                          label: 'Biometric Lock',
                          subtitle: 'Use fingerprint or face to unlock',
                          value: sec?.biometricLockEnabled ?? false,
                          onChanged: ctrl.setBiometricLockEnabled,
                        ),
                        _SwitchRow(
                          label: 'Login Notifications',
                          subtitle: 'Get notified of new sign-ins',
                          value: sec?.loginNotificationEnabled ?? true,
                          onChanged: ctrl.setLoginNotificationEnabled,
                        ),
                        const Divider(height: 24),
                        _SwitchRow(
                          label: 'Require Auth for Export',
                          value: sec?.requireAuthForExport ?? true,
                          onChanged: ctrl.setRequireAuthForExport,
                        ),
                        _SwitchRow(
                          label: 'Require Auth for Delete',
                          value: sec?.requireAuthForDelete ?? true,
                          onChanged: ctrl.setRequireAuthForDelete,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Change Password
                Card(
                  child: ListTile(
                    leading: Icon(Icons.password, color: colors.primary),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update your account password'),
                    trailing: Icon(Icons.chevron_right, color: colors.textMuted),
                    onTap: () => _showChangePasswordDialog(context, ctrl),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, SettingsController ctrl) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              if (newCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters')),
                );
                return;
              }
              Navigator.pop(ctx);
              final result = await ctrl.changePassword(
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success'] == true
                        ? 'Password changed successfully'
                        : result['error'] ?? 'Failed to change password'),
                  ),
                );
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            )),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: context.colors.primary,
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary)),
          ),
          DropdownButton<String>(
            value: options.containsKey(value) ? value : options.keys.first,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: options.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
