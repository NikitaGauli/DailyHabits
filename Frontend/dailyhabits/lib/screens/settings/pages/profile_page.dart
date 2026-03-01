import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

/// Profile settings page — manage display name, email, and avatar.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<SettingsController>().profile;
    _nameCtrl = TextEditingController(text: profile?['name'] ?? '');
    _emailCtrl = TextEditingController(text: profile?['email'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final colors = context.colors;
    final profile = ctrl.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  backgroundImage: profile?['profileImage'] != null
                      ? NetworkImage(profile!['profileImage'])
                      : null,
                  child: profile?['profileImage'] == null
                      ? Icon(Icons.person, size: 50, color: colors.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          _buildField(
            label: 'Display Name',
            controller: _nameCtrl,
            icon: Icons.person_outlined,
          ),
          const SizedBox(height: 16),

          // Email field (read-only)
          _buildField(
            label: 'Email',
            controller: _emailCtrl,
            icon: Icons.email_outlined,
            readOnly: true,
          ),
          const SizedBox(height: 16),

          // Stats card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account Stats',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Current Streak',
                    value: '${profile?['currentStreak'] ?? 0} days',
                    icon: Icons.local_fire_department,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    label: 'Total Habits Completed',
                    value: '${profile?['totalHabitsCompleted'] ?? 0}',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    label: 'Member Since',
                    value: _formatDate(profile?['dateJoined']),
                    icon: Icons.calendar_today,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? context.colors.surface.withValues(alpha: 0.5) : null,
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    await context.read<SettingsController>().updateProfile({
      'name': _nameCtrl.text.trim(),
    });
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
        ),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
      ],
    );
  }
}
