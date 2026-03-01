// =============================================================================
// profile_screen.dart — User Profile
// =============================================================================
// Displays the authenticated user’s profile information and provides
// access to account actions.
//
// Content:
//  • Avatar with an edit-name affordance.
//  • Name, email, and membership date.
//  • Streak and completed-habits stat cards.
//  • Quick-link to the Settings screen.
//
// Profile data is fetched from [AuthService.getUser] on mount.
// The user’s display name can be updated in-place via a dialog that
// PATCH-es the backend profile endpoint.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/screens/settings/settings_screen.dart';
import 'package:dailyhabits/screens/settings/settings_controller.dart';

/// The user profile screen.
///
/// Fetches the current user’s data on mount and renders their avatar,
/// stats, and a settings link.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Internal state for [ProfileScreen].
class _ProfileScreenState extends State<ProfileScreen> {
  /// Raw profile map returned by the auth service.
  Map<String, dynamic>? _profile;

  /// Whether the profile data is still being loaded.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Fetches the authenticated user’s profile from the backend.
  Future<void> _loadProfile() async {
    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _profile = user;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.h3.copyWith(color: tc.textPrimary)),
        backgroundColor: tc.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: tc.secondary))
          : _buildBody(context),
    );
  }

  // =========================================================================
  //  BODY
  // =========================================================================

  /// Builds the scrollable profile body: avatar, name, email,
  /// stats cards, and the settings action tile.
  Widget _buildBody(BuildContext context) {
    final tc = context.colors;
    final name = _profile?['name'] ?? 'User';
    final email = _profile?['email'] ?? '';
    final createdAt = _profile?['created_at'];
    final streak = _profile?['current_streak'] ?? 0;
    final completed = _profile?['total_habits_completed'] ?? 0;

    String memberSince = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        memberSince = DateFormat('MMMM yyyy').format(dt);
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: tc.accent.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tc.accent),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showEditNameDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tc.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: tc.bg, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(email, style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted)),
        ),
        if (memberSince.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Member since $memberSince',
              style: AppTextStyles.caption.copyWith(color: tc.textMuted),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Stats row
        Row(
          children: [
            _buildStatCard(context, '$streak', 'Current\nStreak', Icons.local_fire_department_rounded, const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _buildStatCard(context, '$completed', 'Habits\nCompleted', Icons.check_circle_rounded, const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 32),

        // Settings button
        _buildActionTile(
          context,
          'Settings',
          Icons.settings_rounded,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => SettingsController(),
                child: const SettingsScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  //  STAT CARD
  // =========================================================================

  /// Builds a compact stat card showing an icon, numeric [value], and
  /// a multi-line [label].
  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final tc = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.h3.copyWith(color: tc.textPrimary)),
                Text(label, style: AppTextStyles.caption.copyWith(color: tc.textMuted, height: 1.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  ACTION TILE
  // =========================================================================

  /// A tappable row used for navigation items (e.g. Settings).
  Widget _buildActionTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final tc = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tc.accent, size: 22),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(color: tc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: tc.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  EDIT NAME DIALOG
  // =========================================================================

  /// Shows a simple dialog allowing the user to update their display name.
  void _showEditNameDialog(BuildContext context) {
    final tc = context.colors;
    final ctrl = TextEditingController(text: _profile?['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.card,
        title: Text('Edit Name', style: TextStyle(color: tc.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: tc.textPrimary),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: tc.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: tc.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _updateName(name);
              }
            },
            child: Text('Save', style: TextStyle(color: tc.accent)),
          ),
        ],
      ),
    );
  }

  /// Sends a PATCH request to update the user’s display [name] on the
  /// backend and refreshes local state on success.
  Future<void> _updateName(String name) async {
    final svc = AuthService();
    // Retrieve the stored JWT for authentication
    final token = await svc.getToken();
    if (token == null) return;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/profile/');
      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _profile?['name'] = name;
        });
      }
    } catch (_) {}
  }
}
