// =============================================================================
// File: admin_settings_page.dart
// Description: System settings page — key-value config editor grouped by
//              category with inline editing.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.settingsPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return const Center(child: Text('No settings configured'));
        }
        // Group by category
        final grouped = <String, List<SystemSetting>>{};
        for (final s in page.results) {
          grouped.putIfAbsent(s.category, () => []).add(s);
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: grouped.entries
              .map((entry) => _SettingGroup(
                    category: entry.key,
                    settings: entry.value,
                    ctrl: ctrl,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SettingGroup extends StatelessWidget {
  final String category;
  final List<SystemSetting> settings;
  final AdminController ctrl;
  const _SettingGroup(
      {required this.category, required this.settings, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              category.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color:
                    isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          // Setting rows
          ...settings.map((s) => _SettingRow(setting: s, ctrl: ctrl)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final SystemSetting setting;
  final AdminController ctrl;
  const _SettingRow({required this.setting, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(setting.key,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (setting.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(setting.description,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Value — boolean toggle or text edit
          if (setting.valueType == 'boolean')
            Switch(
              value: setting.value.toLowerCase() == 'true',
              activeThumbColor: AppColors.primary,
              onChanged: ctrl.hasPermission('settings.edit')
                  ? (v) => ctrl.updateSetting(
                      setting.key, v ? 'true' : 'false')
                  : null,
            )
          else
            SizedBox(
              width: 200,
              child: _InlineEditField(
                initialValue: setting.value,
                enabled: ctrl.hasPermission('settings.edit'),
                onSubmit: (v) => ctrl.updateSetting(setting.key, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineEditField extends StatefulWidget {
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onSubmit;
  const _InlineEditField(
      {required this.initialValue,
      required this.enabled,
      required this.onSubmit});

  @override
  State<_InlineEditField> createState() => _InlineEditFieldState();
}

class _InlineEditFieldState extends State<_InlineEditField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, size: 18),
          onPressed: widget.enabled ? () => widget.onSubmit(_ctrl.text) : null,
        ),
      ),
      onSubmitted: widget.enabled ? widget.onSubmit : null,
    );
  }
}
