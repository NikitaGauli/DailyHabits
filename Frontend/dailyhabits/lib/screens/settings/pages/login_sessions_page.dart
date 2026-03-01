import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/settings_models.dart';
import '../settings_controller.dart';

/// Login Sessions page — view and manage active device sessions.
class LoginSessionsPage extends StatefulWidget {
  const LoginSessionsPage({super.key});

  @override
  State<LoginSessionsPage> createState() => _LoginSessionsPageState();
}

class _LoginSessionsPageState extends State<LoginSessionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsController>().loadLoginSessions();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final sessions = ctrl.loginSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Sessions'),
        centerTitle: true,
        actions: [
          if (sessions.length > 1)
            TextButton.icon(
              onPressed: () => _confirmRevokeAll(context, ctrl),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Revoke All'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
        ],
      ),
      body: ctrl.isLoadingSessions
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_outlined, size: 48, color: colors.textMuted),
                      const SizedBox(height: 12),
                      Text('No active sessions',
                          style: TextStyle(color: colors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: ctrl.loadLoginSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${sessions.length} active session${sessions.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      return _SessionCard(
                        session: sessions[index - 1],
                        onRevoke: () => _revokeSession(ctrl, sessions[index - 1]),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _revokeSession(SettingsController ctrl, LoginSessionModel session) async {
    if (session.isCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot revoke current session')),
      );
      return;
    }
    final ok = await ctrl.revokeSession(session.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Session revoked' : 'Failed to revoke session'),
        ),
      );
    }
  }

  void _confirmRevokeAll(BuildContext context, SettingsController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke All Sessions'),
        content: const Text(
          'This will sign out all other devices. Your current session will remain active.',
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
              final ok = await ctrl.revokeAllSessions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'All other sessions revoked'
                        : 'Failed to revoke sessions'),
                  ),
                );
              }
            },
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final LoginSessionModel session;
  final VoidCallback onRevoke;

  const _SessionCard({required this.session, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: session.isCurrent
                        ? AppColors.success.withValues(alpha: 0.1)
                        : colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    session.deviceIcon,
                    color: session.isCurrent ? AppColors.success : colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.deviceName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (session.isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${session.platform} \u2022 ${session.ipAddress}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!session.isCurrent)
                  IconButton(
                    onPressed: onRevoke,
                    icon: const Icon(Icons.logout, size: 20),
                    color: AppColors.error,
                    tooltip: 'Revoke session',
                  ),
              ],
            ),
            if (session.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(session.location!,
                      style: TextStyle(fontSize: 12, color: colors.textMuted)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Last active: ${_formatDate(session.lastActiveAt)}',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
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
