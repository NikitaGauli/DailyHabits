// =============================================================================
// File: admin_feature_flags_page.dart
// Description: Feature flags management — toggle flags, view rollout strategy.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminFeatureFlagsPage extends StatelessWidget {
  const AdminFeatureFlagsPage({super.key});

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
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: page.results.length,
          itemBuilder: (context, i) =>
              _FlagCard(flag: page.results[i], ctrl: ctrl),
        );
      },
    );
  }
}

class _FlagCard extends StatelessWidget {
  final FeatureFlag flag;
  final AdminController ctrl;
  const _FlagCard({required this.flag, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (flag.isEnabled ? AppColors.success : AppColors.lightTextMuted)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              flag.isEnabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: flag.isEnabled ? AppColors.success : AppColors.lightTextMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(flag.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(flag.key,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        fontFamily: 'monospace')),
                if (flag.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(flag.description,
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StrategyBadge(strategy: flag.rolloutStrategy),
                    if (flag.rolloutStrategy == 'percentage') ...[
                      const SizedBox(width: 8),
                      Text('${flag.rolloutPercentage}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Toggle
          Switch(
            value: flag.isEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: ctrl.hasPermission('feature_flags.manage')
                ? (_) => ctrl.toggleFlag(flag.id)
                : null,
          ),
        ],
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        strategy.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
