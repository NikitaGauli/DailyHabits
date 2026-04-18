// =============================================================================
// File: admin_analytics_page.dart
// Description: Modern analytics page with engagement metrics, retention data,
//              interactive charts (line, pie, bar), and category breakdown.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/models/admin_models.dart';
import 'package:dailyhabits/admin/services/admin_api_service.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage>
    with SingleTickerProviderStateMixin {
  EngagementMetrics? _engagement;
  bool _loadingEngagement = false;
  bool _exporting = false;
  int _exportDays = 30;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadEngagement();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEngagement() async {
    setState(() => _loadingEngagement = true);
    try {
      _engagement = await AdminApiService().getEngagementMetrics(days: 30);
    } catch (_) {}
    if (mounted) setState(() => _loadingEngagement = false);
  }

  Future<void> _exportReport(String format) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await AdminApiService().exportAnalyticsReport(
        days: _exportDays,
        format: format,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${format.toUpperCase()} report downloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'Export range:',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final d in const [7, 30, 90])
                          ChoiceChip(
                            label: Text('$d days'),
                            selected: _exportDays == d,
                            onSelected: (v) {
                              if (v) setState(() => _exportDays = d);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _exportReport('csv'),
                    icon: const Icon(Icons.table_view_rounded, size: 18),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _exporting ? null : () => _exportReport('pdf'),
                    icon: _exporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ),

            // ─── Tab Bar ───
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primary,
                unselectedLabelColor:
                    isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Growth'),
                  Tab(text: 'Engagement'),
                  Tab(text: 'Categories'),
                ],
              ),
            ),

            // ─── Tab Views ───
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _GrowthTab(ctrl: ctrl),
                  _EngagementTab(
                    engagement: _engagement,
                    loading: _loadingEngagement,
                  ),
                  _CategoriesTab(engagement: _engagement),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// TAB 1: Growth
// =============================================================================

class _GrowthTab extends StatelessWidget {
  final AdminController ctrl;
  const _GrowthTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final data = ctrl.growthTrends;
    if (data.isEmpty) {
      return const Center(child: Text('No growth data available'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'User Growth — 30 days',
            subtitle:
                '${data.last.totalUsers} total users · ${data.last.dailyActiveUsers} DAU',
          ),
          const SizedBox(height: 16),
          _ChartCard(
            height: 300,
            child: _GrowthLineChart(data: data),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'New Users per Day',
            subtitle: 'Daily registration trend',
          ),
          const SizedBox(height: 16),
          _ChartCard(
            height: 220,
            child: _NewUsersBarChart(data: data),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2: Engagement
// =============================================================================

class _EngagementTab extends StatelessWidget {
  final EngagementMetrics? engagement;
  final bool loading;
  const _EngagementTab({required this.engagement, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (engagement == null) {
      return const Center(child: Text('Failed to load engagement data'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Tiles
          _EngagementKpiRow(engagement: engagement!),
          const SizedBox(height: 24),
          // Completion breakdown pie
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompletionPieSection(engagement: engagement!),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StreakDistributionSection(engagement: engagement!),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _CompletionPieSection(engagement: engagement!),
                const SizedBox(height: 24),
                _StreakDistributionSection(engagement: engagement!),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: Categories
// =============================================================================

class _CategoriesTab extends StatelessWidget {
  final EngagementMetrics? engagement;
  const _CategoriesTab({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (engagement == null || engagement!.topCategories.isEmpty) {
      return const Center(child: Text('No category data available'));
    }
    final cats = engagement!.topCategories;
    final maxCount = cats.map((c) => c['count'] as int? ?? 0).fold(0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Top Habit Categories',
            subtitle: '${cats.length} categories tracked',
          ),
          const SizedBox(height: 16),
          ...cats.map((cat) {
            final name = cat['category'] as String? ?? 'Unknown';
            final count = cat['count'] as int? ?? 0;
            final fraction = maxCount > 0 ? count / maxCount : 0.0;
            final colors = [
              AppColors.primary, AppColors.secondary, AppColors.info,
              AppColors.warning, AppColors.success, AppColors.primaryLight,
            ];
            final color = colors[cats.indexOf(cat) % colors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_categoryIcon(name),
                            size: 18, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name[0].toUpperCase() + name.substring(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Text(
                        '$count habits',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: color.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('health') || n.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }
    if (n.contains('work') || n.contains('productivity')) {
      return Icons.work_rounded;
    }
    if (n.contains('learn') || n.contains('read') || n.contains('study')) {
      return Icons.school_rounded;
    }
    if (n.contains('meditat') || n.contains('mindful')) {
      return Icons.self_improvement_rounded;
    }
    if (n.contains('social')) return Icons.people_rounded;
    if (n.contains('finance') || n.contains('money')) {
      return Icons.savings_rounded;
    }
    return Icons.category_rounded;
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            )),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final double height;
  final Widget child;
  const _ChartCard({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
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
      child: child,
    );
  }
}

// ─── Engagement KPIs ───

class _EngagementKpiRow extends StatelessWidget {
  final EngagementMetrics engagement;
  const _EngagementKpiRow({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiles = [
      _Kpi('Total Logs', '${engagement.totalLogs}', Icons.list_alt_rounded,
          AppColors.primary),
      _Kpi('Completed', '${engagement.completed}',
          Icons.check_circle_rounded, AppColors.success),
      _Kpi('Skipped', '${engagement.skipped}', Icons.skip_next_rounded,
          AppColors.warning),
      _Kpi('Missed', '${engagement.missed}',
          Icons.cancel_rounded, AppColors.error),
      _Kpi(
          'Completion Rate',
          '${engagement.completionRate.toStringAsFixed(1)}%',
          Icons.trending_up_rounded,
          AppColors.info),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: tiles.map((t) {
        return Container(
          width: 190,
          padding: const EdgeInsets.all(16),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(t.icon, size: 20, color: t.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.color)),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Kpi {
  final String label, value;
  final IconData icon;
  final Color color;
  _Kpi(this.label, this.value, this.icon, this.color);
}

// ─── Completion Pie ───

class _CompletionPieSection extends StatelessWidget {
  final EngagementMetrics engagement;
  const _CompletionPieSection({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = engagement.completed + engagement.skipped + engagement.missed;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Completion Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: engagement.completed.toDouble(),
                          color: AppColors.success,
                          title:
                              '${(engagement.completed / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          radius: 55,
                        ),
                        PieChartSectionData(
                          value: engagement.skipped.toDouble(),
                          color: AppColors.warning,
                          title:
                              '${(engagement.skipped / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: engagement.missed.toDouble(),
                          color: AppColors.error,
                          title:
                              '${(engagement.missed / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          radius: 45,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(color: AppColors.success, label: 'Completed', count: engagement.completed),
                    const SizedBox(height: 10),
                    _LegendDot(color: AppColors.warning, label: 'Skipped', count: engagement.skipped),
                    const SizedBox(height: 10),
                    _LegendDot(color: AppColors.error, label: 'Missed', count: engagement.missed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendDot(
      {required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text('$label ($count)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Streak Distribution ───

class _StreakDistributionSection extends StatelessWidget {
  final EngagementMetrics engagement;
  const _StreakDistributionSection({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dist = engagement.streakDistribution;
    if (dist.isEmpty) return const SizedBox.shrink();

    final maxVal = dist
        .map((e) => (e['count'] as int?) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Streak Distribution',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...dist.map((entry) {
            final streak = entry['current_streak'] ?? 0;
            final count = (entry['count'] as int?) ?? 0;
            final fraction = maxVal > 0 ? count / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text('$streak days',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(
                            AppColors.primary.withValues(alpha: 0.7)),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    child: Text('$count',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// Growth Line Chart
// =============================================================================

class _GrowthLineChart extends StatelessWidget {
  final List<GrowthDataPoint> data;
  const _GrowthLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (data.isEmpty) return const SizedBox.shrink();
    final maxUsers =
        data.map((e) => e.totalUsers).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
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
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted),
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
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxUsers * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length,
                (i) => FlSpot(i.toDouble(), data[i].totalUsers.toDouble())),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          LineChartBarData(
            spots: List.generate(
                data.length,
                (i) =>
                    FlSpot(i.toDouble(), data[i].dailyActiveUsers.toDouble())),
            isCurved: true,
            color: AppColors.secondary,
            barWidth: 2,
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
            getTooltipItems: (spots) => spots.map((s) {
              final color = s.barIndex == 0 ? AppColors.primary : AppColors.secondary;
              final label = s.barIndex == 0 ? 'Total' : 'DAU';
              return LineTooltipItem(
                '$label: ${s.y.toInt()}',
                TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// New Users Bar Chart
// =============================================================================

class _NewUsersBarChart extends StatelessWidget {
  final List<GrowthDataPoint> data;
  const _NewUsersBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxNew =
        data.map((e) => e.newUsers).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: data[i].newUsers.toDouble(),
              width: data.length > 20 ? 6 : 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.info.withValues(alpha: 0.4),
                  AppColors.info,
                ],
              ),
            ),
          ]);
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            strokeWidth: 1,
            dashArray: [4, 4],
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
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxNew * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              final d = data[group.x];
              return BarTooltipItem(
                '${d.date.length >= 10 ? d.date.substring(5) : d.date}\n${d.newUsers} new users',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}
