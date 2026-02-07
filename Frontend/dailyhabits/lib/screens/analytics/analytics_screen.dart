import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/screens/analytics/analytics_controller.dart';
import 'package:dailyhabits/screens/analytics/widgets/consistency_ring.dart';
import 'package:dailyhabits/screens/analytics/widgets/streak_card.dart';
import 'package:dailyhabits/screens/analytics/widgets/calendar_heatmap.dart';
import 'package:dailyhabits/screens/analytics/widgets/trend_chart.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnalyticsController(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final controller = Provider.of<AnalyticsController>(context);

    if (controller.isLoading && controller.dashboardData == null) {
      return Scaffold(
        backgroundColor: tc.bg,
        body: Center(
          child: CircularProgressIndicator(color: tc.primary),
        ),
      );
    }

    // Extract summary data
    final data = controller.dashboardData ?? {};
    final summary = data['summary'] ?? {};
    final currentStreak = _toInt(summary['currentStreak']);
    final bestStreak = _toInt(summary['bestStreak']);
    final consistency = _toDouble(summary['todayRate']);
    final totalHabits = _toInt(summary['totalHabits']);
    final completions = _toInt(summary['todayCompleted']);
    final weeklyCompletions = _toInt(summary['weeklyCompletions']);
    final avgConsistency = _toDouble(summary['avgConsistency']);

    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.loadDashboard();
            await controller.loadHeatmap();
          },
          color: tc.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header
                _buildHeader(context),
                const SizedBox(height: 24),

                // ── Overview Card: Ring + Stats
                _buildOverviewCard(
                  context,
                  consistency: consistency,
                  completions: completions,
                  totalHabits: totalHabits,
                  weeklyCompletions: weeklyCompletions,
                  avgConsistency: avgConsistency,
                ),
                const SizedBox(height: 20),

                // ── Streak Card
                StreakCard(
                  currentStreak: currentStreak,
                  bestStreak: bestStreak,
                ),
                const SizedBox(height: 24),

                // ── Category Breakdown
                if (controller.categoryBreakdown.isNotEmpty) ...[
                  _sectionTitle(context, 'By Category'),
                  const SizedBox(height: 12),
                  _buildCategoryBreakdown(context, controller.categoryBreakdown),
                  const SizedBox(height: 24),
                ],

                // ── Weekly Trend
                _sectionTitle(context, 'Weekly Trend'),
                const SizedBox(height: 12),
                if (controller.weeklyData.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: tc.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tc.border.withValues(alpha: 0.15)),
                    ),
                    child: TrendChart(weeklyData: controller.weeklyData),
                  )
                else
                  _buildEmptyCard(context, 'Complete a habit to see trends here'),
                const SizedBox(height: 24),

                // ── Monthly Heatmap
                Row(
                  children: [
                    Expanded(
                      child: _sectionTitle(context, 'Monthly View'),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, color: tc.textSecondary),
                      onPressed: () => controller.changeMonth(-1),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: tc.textSecondary),
                      onPressed: () => controller.changeMonth(1),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tc.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tc.border.withValues(alpha: 0.15)),
                  ),
                  child: CalendarHeatmap(
                    data: controller.monthlyHeatmap,
                    monthDate: controller.currentMonth,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: AppTextStyles.h1.copyWith(color: tc.textPrimary, fontSize: 26),
        ),
        const SizedBox(height: 4),
        Text(
          'Your progress at a glance',
          style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
        ),
      ],
    );
  }

  // ─── Overview Card ────────────────────────────────────────────────────────

  Widget _buildOverviewCard(
    BuildContext context, {
    required double consistency,
    required int completions,
    required int totalHabits,
    required int weeklyCompletions,
    required double avgConsistency,
  }) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ConsistencyRing(
            consistency: consistency / 100.0,
            size: 110,
            strokeWidth: 10,
            color: tc.primary,
            backgroundColor: tc.surfaceVariant,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completions / $totalHabits',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Done Today',
                  style: TextStyle(color: tc.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Mini stats row
                Row(
                  children: [
                    _miniStat(
                      context,
                      icon: Icons.calendar_today_rounded,
                      value: '$weeklyCompletions',
                      label: 'This week',
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      context,
                      icon: Icons.show_chart_rounded,
                      value: '${avgConsistency.toInt()}%',
                      label: 'Average',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(consistency).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(consistency),
                    style: TextStyle(
                      color: _statusColor(consistency),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context,
      {required IconData icon, required String value, required String label}) {
    final tc = context.colors;
    return Row(
      children: [
        Icon(icon, size: 14, color: tc.textMuted),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: tc.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: tc.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Color _statusColor(double rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.secondary;
    if (rate >= 25) return AppColors.warning;
    return AppColors.error;
  }

  String _statusLabel(double rate) {
    if (rate >= 80) return 'On Fire';
    if (rate >= 50) return 'Solid';
    if (rate >= 25) return 'Building Up';
    return 'Getting Started';
  }

  // ─── Category Breakdown ───────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(
    BuildContext context,
    List<Map<String, dynamic>> categories,
  ) {
    final tc = context.colors;
    final categoryColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: List.generate(categories.length, (i) {
          final cat = categories[i];
          final name = cat['category'] ?? 'General';
          final count = _toInt(cat['habitCount']);
          final rate = _toDouble(cat['avgConsistency']);
          final color = categoryColors[i % categoryColors.length];

          return Padding(
            padding: EdgeInsets.only(bottom: i < categories.length - 1 ? 14 : 0),
            child: Row(
              children: [
                // Color dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                // Category name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: tc.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$count habit${count == 1 ? '' : 's'}',
                        style: TextStyle(color: tc.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Progress bar
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100.0,
                      minHeight: 6,
                      backgroundColor: tc.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Rate
                SizedBox(
                  width: 40,
                  child: Text(
                    '${rate.toInt()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext context, String title) {
    final tc = context.colors;
    return Text(
      title,
      style: TextStyle(
        color: tc.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(Icons.insights_rounded, size: 36, color: tc.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: tc.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  static int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
  static double _toDouble(dynamic v) => v is double ? v : (v is num ? v.toDouble() : 0.0);
}
