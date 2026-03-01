// =============================================================================
// File: admin_analytics_page.dart
// Description: Analytics page with engagement metrics, completion breakdown,
//              and interactive charts.
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

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  EngagementMetrics? _engagement;
  bool _loadingEngagement = false;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    setState(() => _loadingEngagement = true);
    try {
      _engagement = await AdminApiService().getEngagementMetrics(days: 30);
    } catch (_) {}
    if (mounted) setState(() => _loadingEngagement = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, ctrl, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Growth chart (reuse from dashboard)
              if (ctrl.growthTrends.isNotEmpty) ...[
                Text('User Growth',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: _GrowthLineChart(data: ctrl.growthTrends),
                ),
                const SizedBox(height: 32),
              ],

              // Engagement metrics
              Text('Engagement — last 30 days',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (_loadingEngagement)
                const Center(child: CircularProgressIndicator())
              else if (_engagement != null) ...[
                _EngagementRow(engagement: _engagement!),
                const SizedBox(height: 24),
                SizedBox(
                  height: 260,
                  child: _CompletionPieChart(engagement: _engagement!),
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
// Engagement Row — KPI tiles
// =============================================================================

class _EngagementRow extends StatelessWidget {
  final EngagementMetrics engagement;
  const _EngagementRow({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiles = [
      _TileData('Total Logs', '${engagement.totalLogs}', AppColors.primary),
      _TileData('Completed', '${engagement.completed}', AppColors.success),
      _TileData('Skipped', '${engagement.skipped}', AppColors.warning),
      _TileData('Missed', '${engagement.missed}', AppColors.error),
      _TileData('Completion Rate',
          '${engagement.completionRate.toStringAsFixed(1)}%', AppColors.info),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: tiles
          .map((t) => Container(
                width: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.value,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: t.color)),
                    const SizedBox(height: 4),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _TileData {
  final String label, value;
  final Color color;
  _TileData(this.label, this.value, this.color);
}

// =============================================================================
// Completion Pie Chart
// =============================================================================

class _CompletionPieChart extends StatelessWidget {
  final EngagementMetrics engagement;
  const _CompletionPieChart({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = engagement.completed + engagement.skipped + engagement.missed;
    if (total == 0) {
      return const Center(child: Text('No data'));
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: engagement.completed.toDouble(),
                    color: AppColors.success,
                    title:
                        '${(engagement.completed / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    radius: 60,
                  ),
                  PieChartSectionData(
                    value: engagement.skipped.toDouble(),
                    color: AppColors.warning,
                    title:
                        '${(engagement.skipped / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    radius: 55,
                  ),
                  PieChartSectionData(
                    value: engagement.missed.toDouble(),
                    color: AppColors.error,
                    title:
                        '${(engagement.missed / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(color: AppColors.success, label: 'Completed'),
              const SizedBox(height: 8),
              _LegendItem(color: AppColors.warning, label: 'Skipped'),
              const SizedBox(height: 8),
              _LegendItem(color: AppColors.error, label: 'Missed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// =============================================================================
// Growth Line Chart (same as dashboard but standalone)
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                      fontSize: 11,
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
                  show: true, color: AppColors.primary.withValues(alpha: 0.08)),
            ),
            LineChartBarData(
              spots: List.generate(
                  data.length,
                  (i) => FlSpot(
                      i.toDouble(), data[i].dailyActiveUsers.toDouble())),
              isCurved: true,
              color: AppColors.secondary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
