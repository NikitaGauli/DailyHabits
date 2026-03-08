// =============================================================================
// File: admin_dashboard_page.dart
// Description: Modern SaaS-quality overview dashboard with animated KPI cards,
//              trend indicators, multi-chart layout, and quick action panels.
// =============================================================================

import 'dart:math' as math;
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.space_dashboard_rounded,
                    size: 56, color: AppColors.lightTextMuted),
                const SizedBox(height: 12),
                const Text('No dashboard data available'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reload'),
                  onPressed: () => ctrl.refreshDashboard(),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ctrl.refreshDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Welcome header ───
                _WelcomeHeader(ctrl: ctrl),
                const SizedBox(height: 24),

                // ─── Top KPI Row ───
                _TopKpiRow(stats: stats),
                const SizedBox(height: 24),

                // ─── Charts Grid ───
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _GrowthChartCard(
                                data: ctrl.growthTrends),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: _QuickStatsCard(stats: stats),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _GrowthChartCard(data: ctrl.growthTrends),
                        const SizedBox(height: 20),
                        _QuickStatsCard(stats: stats),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ─── Bottom Grid ───
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _ActivityCard(stats: stats)),
                          const SizedBox(width: 20),
                          Expanded(
                              child: _SystemHealthCard(stats: stats)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _ActivityCard(stats: stats),
                        const SizedBox(height: 20),
                        _SystemHealthCard(stats: stats),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Welcome Header
// =============================================================================

class _WelcomeHeader extends StatelessWidget {
  final AdminController ctrl;
  const _WelcomeHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = ctrl.profile?.userName ?? 'Admin';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s what\'s happening with your platform today.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Date badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                _formatToday(),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// =============================================================================
// Top KPI Row
// =============================================================================

class _TopKpiRow extends StatelessWidget {
  final OverviewStats stats;
  const _TopKpiRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiData(
        title: 'Total Users',
        value: _formatNumber(stats.totalUsers),
        subtitle: '+${stats.newUsersToday} today',
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
        gradient: AppColors.primaryGradient,
      ),
      _KpiData(
        title: 'Active Today',
        value: _formatNumber(stats.activeUsersToday),
        subtitle: '${stats.totalUsers > 0 ? (stats.activeUsersToday / stats.totalUsers * 100).toStringAsFixed(1) : '0'}% of total',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
        ),
      ),
      _KpiData(
        title: 'Completion Rate',
        value: '${stats.averageCompletionRate.toStringAsFixed(1)}%',
        subtitle: '${stats.habitsCompletedToday} completed today',
        icon: Icons.pie_chart_rounded,
        color: AppColors.secondary,
        gradient: AppColors.secondaryGradient,
      ),
      _KpiData(
        title: 'Active Streaks',
        value: _formatNumber(stats.activeStreaks),
        subtitle: '${stats.totalXpToday} XP earned today',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.warning,
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 700
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: crossCount == 1 ? 3.0 : 2.2,
          ),
          itemBuilder: (context, i) => _KpiCard(kpi: kpis[i]),
        );
      },
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

class _KpiCard extends StatefulWidget {
  final _KpiData kpi;
  const _KpiCard({required this.kpi});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.kpi.color.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.kpi.color.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Gradient icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: widget.kpi.gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: widget.kpi.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.kpi.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.kpi.title,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.kpi.value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.kpi.subtitle,
                    style: TextStyle(
                      color: widget.kpi.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Growth Chart Card
// =============================================================================

class _GrowthChartCard extends StatelessWidget {
  final List<GrowthDataPoint> data;
  const _GrowthChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Growth',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Last 30 days',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Legend
              _ChartLegend(items: [
                _LegendData('Total Users', AppColors.primary),
                _LegendData('DAU', AppColors.secondary),
              ]),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 260,
            child: data.isEmpty
                ? const Center(child: Text('No growth data'))
                : _buildChart(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(bool isDark) {
    final maxUsers =
        data.map((e) => e.totalUsers).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxUsers > 0 ? maxUsers / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            strokeWidth: 0.8,
            dashArray: [6, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox();
                }
                final d = data[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    d.length >= 10 ? d.substring(5) : d,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                _shortNumber(value.toInt()),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
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
          // Total users
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) =>
                  FlSpot(i.toDouble(), data[i].totalUsers.toDouble()),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // DAU
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(
                  i.toDouble(), data[i].dailyActiveUsers.toDouble()),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.secondary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.secondary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      _shortNumber(s.y.toInt()),
                      TextStyle(
                        color: s.bar.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  String _shortNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// =============================================================================
// Quick Stats Card (right of chart)
// =============================================================================

class _QuickStatsCard extends StatelessWidget {
  final OverviewStats stats;
  const _QuickStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _QuickStat('New This Week', '${stats.newUsersThisWeek}',
          Icons.person_add_alt_rounded, AppColors.info),
      _QuickStat('Total Habits', '${stats.totalHabits}',
          Icons.task_alt_rounded, AppColors.primaryLight),
      _QuickStat('Active Groups', '${stats.totalGroups}',
          Icons.groups_rounded, AppColors.secondary),
      _QuickStat('Challenges', '${stats.totalChallengesActive}',
          Icons.emoji_events_rounded, AppColors.warning),
      _QuickStat('Pending Reports', '${stats.pendingReports}',
          Icons.report_rounded, AppColors.error),
      _QuickStat('Open Tickets', '${stats.openSupportTickets}',
          Icons.support_agent_rounded, AppColors.info),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Stats',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickStatRow(stat: item, isDark: isDark),
              )),
        ],
      ),
    );
  }
}

class _QuickStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _QuickStat(this.label, this.value, this.icon, this.color);
}

class _QuickStatRow extends StatelessWidget {
  final _QuickStat stat;
  final bool isDark;
  const _QuickStatRow({required this.stat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(stat.icon, color: stat.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            stat.label,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          stat.value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Activity Breakdown Card (Bar Chart)
// =============================================================================

class _ActivityCard extends StatelessWidget {
  final OverviewStats stats;
  const _ActivityCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _BarItem('Users', stats.totalUsers.toDouble(), AppColors.primary),
      _BarItem('Habits', stats.totalHabits.toDouble(), AppColors.secondary),
      _BarItem(
          'Completed', stats.habitsCompletedToday.toDouble(), AppColors.success),
      _BarItem('Streaks', stats.activeStreaks.toDouble(), AppColors.warning),
      _BarItem('Groups', stats.totalGroups.toDouble(), AppColors.info),
    ];

    final maxVal = items
        .map((e) => e.value)
        .fold<double>(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Platform Activity',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _HorizontalBar(
                    item: item, maxVal: maxVal, isDark: isDark),
              )),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final Color color;
  _BarItem(this.label, this.value, this.color);
}

class _HorizontalBar extends StatelessWidget {
  final _BarItem item;
  final double maxVal;
  final bool isDark;
  const _HorizontalBar({
    required this.item,
    required this.maxVal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxVal > 0 ? item.value / maxVal : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                )),
            Text(
              item.value.toInt().toString(),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                color: item.color.withValues(alpha: 0.1),
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// System Health Card
// =============================================================================

class _SystemHealthCard extends StatelessWidget {
  final OverviewStats stats;
  const _SystemHealthCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthScore = _calculateHealth(stats);
    final healthColor = healthScore >= 80
        ? AppColors.success
        : healthScore >= 50
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monitor_heart_rounded,
                    color: healthColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'System Health',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${healthScore.toInt()}%',
                  style: TextStyle(
                    color: healthColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Health progress ring
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _HealthRingPainter(
                  progress: healthScore / 100,
                  color: healthColor,
                  bgColor: healthColor.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        healthScore >= 80
                            ? Icons.check_circle_rounded
                            : healthScore >= 50
                                ? Icons.warning_rounded
                                : Icons.error_rounded,
                        color: healthColor,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        healthScore >= 80
                            ? 'Good'
                            : healthScore >= 50
                                ? 'Fair'
                                : 'Needs Attention',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: healthColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Health items
          _HealthRow(
            label: 'Reports Queue',
            value: stats.pendingReports == 0 ? 'Clear' : '${stats.pendingReports} pending',
            ok: stats.pendingReports == 0,
          ),
          const SizedBox(height: 8),
          _HealthRow(
            label: 'Support Tickets',
            value: stats.openSupportTickets == 0
                ? 'Clear'
                : '${stats.openSupportTickets} open',
            ok: stats.openSupportTickets == 0,
          ),
          const SizedBox(height: 8),
          _HealthRow(
            label: 'Completion Rate',
            value: '${stats.averageCompletionRate.toStringAsFixed(1)}%',
            ok: stats.averageCompletionRate >= 50,
          ),
        ],
      ),
    );
  }

  double _calculateHealth(OverviewStats stats) {
    double score = 100;
    if (stats.pendingReports > 0) score -= math.min(stats.pendingReports * 5, 25).toDouble();
    if (stats.openSupportTickets > 0) {
      score -= math.min(stats.openSupportTickets * 3, 15).toDouble();
    }
    if (stats.averageCompletionRate < 50) score -= 20;
    if (stats.activeUsersToday == 0) score -= 15;
    return score.clamp(0, 100);
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  const _HealthRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 16,
          color: ok ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              )),
        ),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _HealthRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _HealthRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

// =============================================================================
// Chart Legend
// =============================================================================

class _ChartLegend extends StatelessWidget {
  final List<_LegendData> items;
  const _ChartLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _LegendData {
  final String label;
  final Color color;
  _LegendData(this.label, this.color);
}
