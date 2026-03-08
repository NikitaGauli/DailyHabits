// =============================================================================
// File: admin_feature_flags_page.dart
// Description: Modern feature flags management — toggle cards with rollout
//              info, animated switches, search, and status summary.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminFeatureFlagsPage extends StatefulWidget {
  const AdminFeatureFlagsPage({super.key});

  @override
  State<AdminFeatureFlagsPage> createState() => _AdminFeatureFlagsPageState();
}

class _AdminFeatureFlagsPageState extends State<AdminFeatureFlagsPage> {
  String _search = '';
  String _filter = 'all'; // all, enabled, disabled

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final page = ctrl.featureFlagsPage;
        if (page == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (page == null || page.results.isEmpty) {
          return const Center(child: Text('No feature flags configured'));
        }

        final filtered = page.results.where((f) {
          if (_search.isNotEmpty &&
              !f.name.toLowerCase().contains(_search.toLowerCase()) &&
              !f.key.toLowerCase().contains(_search.toLowerCase())) {
            return false;
          }
          if (_filter == 'enabled' && !f.isEnabled) return false;
          if (_filter == 'disabled' && f.isEnabled) return false;
          return true;
        }).toList();

        final enabledCount = page.results.where((f) => f.isEnabled).length;

        return Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('Feature Flags',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  _CountBadge(
                      '$enabledCount enabled', AppColors.success),
                  const SizedBox(width: 8),
                  _CountBadge(
                      '${page.results.length - enabledCount} disabled',
                      AppColors.lightTextMuted),
                  const Spacer(),
                  // Filter toggles
                  ..._buildFilters(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SearchBar(
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 16),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No flags match your filter',
                          style: TextStyle(
                              color: AppColors.lightTextSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) =>
                          _FlagCard(flag: filtered[i], ctrl: ctrl),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFilters() {
    final items = [
      ('all', 'All'),
      ('enabled', 'Enabled'),
      ('disabled', 'Disabled'),
    ];
    return items.map((item) {
      final selected = _filter == item.$1;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _filter = item.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
              ),
            ),
            child: Text(item.$2,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : null)),
          ),
        ),
      );
    }).toList();
  }
}

// =============================================================================
// Flag Card
// =============================================================================

class _FlagCard extends StatefulWidget {
  final FeatureFlag flag;
  final AdminController ctrl;
  const _FlagCard({required this.flag, required this.ctrl});

  @override
  State<_FlagCard> createState() => _FlagCardState();
}

class _FlagCardState extends State<_FlagCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flag = widget.flag;
    final statusColor = flag.isEnabled ? AppColors.success : AppColors.lightTextMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovering
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                flag.isEnabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(flag.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          flag.isEnabled ? 'ON' : 'OFF',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(flag.key,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontFamily: 'monospace')),
                  if (flag.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(flag.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)),
                  ],
                  const SizedBox(height: 8),
                  // Rollout strategy + percentage
                  Row(
                    children: [
                      _StrategyBadge(strategy: flag.rolloutStrategy),
                      if (flag.rolloutStrategy == 'percentage') ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: flag.rolloutPercentage / 100,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              valueColor:
                                  const AlwaysStoppedAnimation(AppColors.primary),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${flag.rolloutPercentage}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.primary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Toggle switch
            Switch(
              value: flag.isEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: widget.ctrl.hasPermission('feature_flags.manage')
                  ? (_) => widget.ctrl.toggleFlag(flag.id)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _CountBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CountBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search flags by name or key…',
          hintStyle: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
      ),
    );
  }
}

class _StrategyBadge extends StatelessWidget {
  final String strategy;
  const _StrategyBadge({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final color = switch (strategy) {
      'on' => AppColors.success,
      'off' => AppColors.lightTextMuted,
      'percentage' => AppColors.info,
      'staff_only' => AppColors.warning,
      _ => AppColors.lightTextMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            strategy == 'percentage'
                ? Icons.pie_chart_rounded
                : strategy == 'staff_only'
                    ? Icons.admin_panel_settings_rounded
                    : Icons.power_settings_new_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            strategy.replaceAll('_', ' '),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
