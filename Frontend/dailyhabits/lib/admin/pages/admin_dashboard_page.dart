// =============================================================================
// File: admin_dashboard_page.dart
// Description: Overview dashboard with KPI cards and growth trend chart.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        final stats = ctrl.overviewStats;
        if (stats == null && ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (stats == null) {
          return const Center(child: Text('No data available'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Grid
              _KpiGrid(stats: stats),
              const SizedBox(height: 32),

              // Growth Chart
              if (ctrl.growthTrends.isNotEmpty) ...[
                Text('User Growth — last 30 days',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: _GrowthChart(data: ctrl.growthTrends),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// KPI Grid
// =============================================================================

class _KpiGrid extends StatelessWidget {
  final OverviewStats stats;
  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _Kpi('Total Users', '${stats.totalUsers}', Icons.people_alt_rounded,
          AppColors.primary),
      _Kpi('Active Today', '${stats.activeUsersToday}',
          Icons.trending_up_rounded, AppColors.success),
      _Kpi('New Today', '${stats.newUsersToday}',
          Icons.person_add_alt_rounded, AppColors.info),
      _Kpi('New This Week', '${stats.newUsersThisWeek}',
          Icons.date_range_rounded, AppColors.secondary),
      _Kpi('Total Habits', '${stats.totalHabits}', Icons.task_alt_rounded,
          AppColors.primaryLight),
      _Kpi('Completed Today', '${stats.habitsCompletedToday}',
          Icons.check_circle_rounded, AppColors.success),
      _Kpi(
          'Completion Rate',
          '${stats.averageCompletionRate.toStringAsFixed(1)}%',
          Icons.pie_chart_rounded,
          AppColors.warning),
      _Kpi('Active Streaks', '${stats.activeStreaks}',
          Icons.local_fire_department_rounded, AppColors.error),
      _Kpi('Active Challenges', '${stats.totalChallengesActive}',
          Icons.emoji_events_rounded, AppColors.secondary),
      _Kpi('Pending Reports', '${stats.pendingReports}',
          Icons.report_rounded, AppColors.warning),
      _Kpi('Open Tickets', '${stats.openSupportTickets}',
          Icons.support_agent_rounded, AppColors.info),
      _Kpi('XP Today', '${stats.totalXpToday}', Icons.star_rounded,
          AppColors.primary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, i) => _KpiCard(kpi: kpis[i]),
        );
      },
    );
  }
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Kpi(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kpi.value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.label,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Growth Chart
// =============================================================================

class _GrowthChart extends StatelessWidget {
  final List<GrowthDataPoint> data;
  const _GrowthChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxUsers =
        data.map((e) => e.totalUsers).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.length / 6).ceilToDouble(),
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final d = data[idx].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      d.length >= 10 ? d.substring(5) : d,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxUsers * 1.15,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].totalUsers.toDouble()),
              ),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) =>
                    FlSpot(i.toDouble(), data[i].dailyActiveUsers.toDouble()),
              ),
              isCurved: true,
              color: AppColors.secondary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()}',
                        TextStyle(
                            color: s.bar.color, fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
