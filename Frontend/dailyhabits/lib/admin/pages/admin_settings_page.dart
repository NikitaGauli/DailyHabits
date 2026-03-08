// =============================================================================
// File: admin_settings_page.dart
// Description: Modern system settings page — grouped cards, inline edit,
//              toggle switches, search, and category icons.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _search = '';

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
        // Filter and group
        final filtered = page.results
            .where((s) =>
                _search.isEmpty ||
                s.key.toLowerCase().contains(_search.toLowerCase()) ||
                s.description.toLowerCase().contains(_search.toLowerCase()))
            .toList();
        final grouped = <String, List<SystemSetting>>{};
        for (final s in filtered) {
          grouped.putIfAbsent(s.category, () => []).add(s);
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('System Settings',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${page.results.length} keys',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                            fontSize: 12)),
                  ),
                  const Spacer(),
                  // Search
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search settings…',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text('No settings match "$_search"',
                          style: TextStyle(
                              color: AppColors.lightTextSecondary)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: grouped.entries
                          .map((entry) => _SettingGroup(
                                category: entry.key,
                                settings: entry.value,
                                ctrl: ctrl,
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Setting Group
// =============================================================================

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
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_categoryIcon(category),
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const Spacer(),
                Text('${settings.length} setting${settings.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted)),
              ],
            ),
          ),
          // Setting rows with dividers
          ...settings.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Column(
              children: [
                _SettingRow(setting: s, ctrl: ctrl),
                if (i < settings.length - 1)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : AppColors.lightBorder.withValues(alpha: 0.5),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('general')) return Icons.settings_rounded;
    if (c.contains('security') || c.contains('auth')) return Icons.shield_rounded;
    if (c.contains('notification') || c.contains('email')) return Icons.notifications_rounded;
    if (c.contains('gamif') || c.contains('xp')) return Icons.emoji_events_rounded;
    if (c.contains('social') || c.contains('group')) return Icons.people_rounded;
    if (c.contains('api') || c.contains('rate')) return Icons.api_rounded;
    return Icons.tune_rounded;
  }
}

// =============================================================================
// Setting Row
// =============================================================================

class _SettingRow extends StatelessWidget {
  final SystemSetting setting;
  final AdminController ctrl;
  const _SettingRow({required this.setting, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canEdit = ctrl.hasPermission('settings.edit');
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
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (setting.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
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
          // Value widget
          if (setting.valueType == 'boolean')
            Switch(
              value: setting.value.toLowerCase() == 'true',
              activeThumbColor: AppColors.primary,
              onChanged: canEdit
                  ? (v) =>
                      ctrl.updateSetting(setting.key, v ? 'true' : 'false')
                  : null,
            )
          else
            SizedBox(
              width: 220,
              child: _InlineEditField(
                initialValue: setting.value,
                enabled: canEdit,
                onSubmit: (v) => ctrl.updateSetting(setting.key, v),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Inline Edit Field
// =============================================================================

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
  bool _dirty = false;

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
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: _dirty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.success),
                    onPressed: () {
                      widget.onSubmit(_ctrl.text);
                      setState(() => _dirty = false);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.undo_rounded,
                        size: 18, color: AppColors.lightTextMuted),
                    onPressed: () {
                      _ctrl.text = widget.initialValue;
                      setState(() => _dirty = false);
                    },
                  ),
                ],
              )
            : null,
      ),
      onChanged: (v) {
        if (v != widget.initialValue && !_dirty) {
          setState(() => _dirty = true);
        } else if (v == widget.initialValue && _dirty) {
          setState(() => _dirty = false);
        }
      },
      onSubmitted: widget.enabled
          ? (v) {
              widget.onSubmit(v);
              setState(() => _dirty = false);
            }
          : null,
    );
  }
}
