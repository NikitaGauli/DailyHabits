import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/theme_provider.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsController(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SettingsController>(context);
    final settings = controller.settings;
    final tc = context.colors;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
        ),
        backgroundColor: tc.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: controller.isLoading || settings == null
          ? Center(
              child: CircularProgressIndicator(color: tc.secondary),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Theme Section ────────────────────────────
                _buildSectionHeader(context, 'Appearance'),
                _buildThemeSelector(context, themeProvider),

                const SizedBox(height: 28),

                // ── Notifications ────────────────────────────
                _buildSectionHeader(context, 'Notifications'),
                _buildSwitchTile(
                  context,
                  'Push Notifications',
                  'Turn all notifications on or off',
                  settings.notificationsEnabled,
                  (val) => controller.toggleNotifications(val),
                ),
                if (settings.notificationsEnabled) ...[
                  _buildSwitchTile(
                    context,
                    'Habit Reminders',
                  'Notify me for scheduled habits',
                    settings.habitReminders,
                    (val) => controller.toggleHabitReminders(val),
                  ),
                  _buildSwitchTile(
                    context,
                    'Streak Alerts',
                  'Warn me when a streak is at risk',
                    settings.streakAlerts,
                    (val) => controller.toggleStreakAlerts(val),
                  ),
                  _buildSwitchTile(
                    context,
                  'Daily Summary',
                  'Receive a daily progress digest',
                    settings.insightNotifications,
                    (val) => controller.toggleInsightNotifications(val),
                  ),
                  _buildSwitchTile(
                    context,
                    'Motivational Quotes',
                  'A small dose of encouragement daily',
                    settings.motivationalQuotes,
                    (val) => controller.toggleMotivationalQuotes(val),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Quiet Hours ──────────────────────────────
                _buildSectionHeader(context, 'Quiet Hours'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tc.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tc.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bedtime_rounded, color: tc.textMuted),
                      const SizedBox(width: 16),
                      Text(
                        'Quiet Hours',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: tc.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Account ──────────────────────────────────
                _buildSectionHeader(context, 'Account'),
                _buildActionTile(
                  context,
                  'Export Data',
                  Icons.download_rounded,
                  () {},
                ),
                _buildActionTile(
                  context,
                  'Privacy Policy',
                  Icons.lock_outline_rounded,
                  () {},
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  context,
                  'Delete Account',
                  Icons.delete_forever_rounded,
                  () {},
                  color: AppColors.error,
                ),
              ],
            ),
    );
  }

  // ─── THEME SELECTOR ─────────────────────────────────────────────────────

  Widget _buildThemeSelector(BuildContext context, ThemeProvider provider) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _buildThemeOption(
            context,
            provider,
            ThemeMode.light,
            Icons.light_mode_rounded,
            'Light',
          ),
          _buildThemeOption(
            context,
            provider,
            ThemeMode.dark,
            Icons.dark_mode_rounded,
            'Dark',
          ),
          _buildThemeOption(
            context,
            provider,
            ThemeMode.system,
            Icons.brightness_auto_rounded,
            'System',
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider provider,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final tc = context.colors;
    final isSelected = provider.themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? tc.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : tc.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : tc.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title) {
    final tc = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: tc.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final tc = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: tc.textMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: tc.secondary.withValues(alpha: 0.3),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return tc.secondary;
              return tc.textMuted;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    final tc = context.colors;
    final tileColor = color ?? tc.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tileColor, size: 20),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: tileColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: tc.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
