// =============================================================================
// insight_screen.dart — Daily Insights & Recommendations
// =============================================================================
// Screen that presents the user with AI-powered daily insights, a
// motivational quote, and actionable recommendations to improve their
// habit-building journey.
//
// Data is loaded via [InsightController] which wraps [InsightService].
// The screen supports pull-to-refresh and gracefully handles loading
// and empty states.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'insight_controller.dart';
import 'habit_analysis_screen.dart';
import '../../models/insight.dart';

/// Entry point widget for the Insights feature.
///
/// Wraps [_InsightView] inside its own [ChangeNotifierProvider] so that
/// the controller is scoped to this screen's lifecycle.
class InsightScreen extends StatelessWidget {
  const InsightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InsightController(),
      child: const _InsightView(),
    );
  }
}

/// Internal view that builds the insights UI.
///
/// Reads [InsightController] from the widget tree and renders:
///  1. A page header with title and decorative icon.
///  2. A motivational quote card (if available).
///  3. A list of smart insight cards.
///  4. A list of recommended-action cards.
class _InsightView extends StatelessWidget {
  const _InsightView();

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final controller = Provider.of<InsightController>(context);

    if (controller.isLoading) {
      return Scaffold(
        backgroundColor: tc.bg,
        body: Center(
          child: CircularProgressIndicator(color: tc.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildAnalysisCTA(context),
                const SizedBox(height: 20),

                if (controller.dailyQuote != null)
                  _buildQuoteCard(context, controller.dailyQuote!),

                const SizedBox(height: 24),

                _buildVisualInsightsSection(context, controller),

                const SizedBox(height: 28),

                if (controller.insights.isNotEmpty) ...[
                  Text(
                    'Smart Insights',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...controller.insights.map(
                    (insight) => _buildInsightCard(context, insight),
                  ),
                ] else
                  _buildEmptyState(
                    context,
                    'No insights available yet. Keep tracking your habits!',
                  ),

                const SizedBox(height: 32),

                if (controller.recommendations.isNotEmpty) ...[
                  Text(
                    'Recommended Actions',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...controller.recommendations.map(
                    (rec) => _buildRecommendationCard(context, rec),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualInsightsSection(BuildContext context, InsightController controller) {
    final tc = context.colors;
    final hasVisualData =
        controller.topHabits.isNotEmpty || controller.trendSeries.isNotEmpty || controller.bestTime.isNotEmpty;

    if (!hasVisualData) {
      return _buildEmptyState(
        context,
        'Visual insight data will appear as soon as you complete more habit logs.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Intelligence',
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bar, line, and pie charts that explain your habit behavior at a glance.',
          style: TextStyle(color: tc.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (controller.bestTime.isNotEmpty) _buildBestTimeSpotlight(context, controller.bestTime),
        const SizedBox(height: 14),
        if (controller.topHabits.isNotEmpty) _buildTopHabitsBarChart(context, controller.topHabits),
        const SizedBox(height: 14),
        if (controller.trendSeries.isNotEmpty) _buildTrendLineChart(context, controller.trendSeries),
        const SizedBox(height: 14),
        if (controller.topHabits.isNotEmpty) _buildCategoryPieChart(context, controller.topHabits),
      ],
    );
  }

  Widget _buildBestTimeSpotlight(BuildContext context, Map<String, dynamic> bestTime) {
    final tc = context.colors;
    final label = (bestTime['timeLabel'] ?? 'Best Time').toString();
    final percentage = _toDouble(bestTime['percentage']);
    final insight = (bestTime['insight'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            tc.primary,
            tc.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peak Time',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% of completions happen here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (insight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              insight,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHabitsBarChart(BuildContext context, List<Map<String, dynamic>> habits) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bar Graph: Top Habit Consistency',
            style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(color: tc.surfaceVariant),
                ),
                borderData: FlBorderData(show: false),
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final title = _shortHabitName(habits[group.x]['title']?.toString() ?? 'Habit');
                      return BarTooltipItem(
                        '$title\n${rod.toY.toStringAsFixed(1)}%',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 34,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(fontSize: 10, color: tc.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= habits.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortHabitName(habits[i]['title']?.toString() ?? ''),
                            style: TextStyle(fontSize: 10, color: tc.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(habits.length, (index) {
                  final consistency = _toDouble(habits[index]['consistency']);
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: consistency,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: [tc.primary, tc.secondary],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLineChart(BuildContext context, List<Map<String, dynamic>> trend) {
    final tc = context.colors;
    final points = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      points.add(FlSpot(i.toDouble(), _toDouble(trend[i]['rate'])));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Line Graph: 14-Day Completion Trend',
            style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (trend.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(color: tc.surfaceVariant),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 34,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(fontSize: 10, color: tc.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 3,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                        final date = trend[i]['date']?.toString() ?? '';
                        final label = date.length >= 10 ? date.substring(5, 10).replaceAll('-', '/') : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label, style: TextStyle(fontSize: 9, color: tc.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}%',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    barWidth: 4,
                    color: tc.primary,
                    dotData: FlDotData(show: trend.length <= 14),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          tc.primary.withValues(alpha: 0.25),
                          tc.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(BuildContext context, List<Map<String, dynamic>> habits) {
    final tc = context.colors;
    final categoryTotals = <String, double>{};

    for (final item in habits) {
      final category = (item['category'] ?? 'General').toString();
      final completed = _toDouble(item['completedDays']);
      categoryTotals[category] = (categoryTotals[category] ?? 0) + completed;
    }

    if (categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = categoryTotals.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final palette = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.warning,
      AppColors.success,
      AppColors.info,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pie Chart: Completion Share by Category',
            style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                      sections: List.generate(entries.length, (index) {
                        final e = entries[index];
                        final pct = total > 0 ? (e.value / total) * 100 : 0;
                        return PieChartSectionData(
                          value: e.value,
                          color: palette[index % palette.length],
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: 56,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(entries.length, (index) {
                      final e = entries[index];
                      final pct = total > 0 ? (e.value / total) * 100 : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: palette[index % palette.length],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${e.key} ${pct.toStringAsFixed(0)}%',
                                style: TextStyle(color: tc.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCTA(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habit Intelligence',
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Run KMeans-based analysis to detect your consistency cluster and get personalized suggestions.',
            style: TextStyle(color: tc.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HabitAnalysisScreen()),
              );
            },
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analyze My Habits'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  HEADER
  // =========================================================================

  /// Builds the page header with the screen title, subtitle, and a
  /// decorative sparkle icon.
  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Daily wisdom and performance analysis',
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: tc.accent,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  //  MOTIVATIONAL QUOTE
  // =========================================================================

  /// Renders an elegant gradient card displaying the [quote] of the day.
  Widget _buildQuoteCard(BuildContext context, MotivationalQuote quote) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tc.card, tc.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tc.card.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: tc.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            '"${quote.quote}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 18,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '- ${quote.author}',
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  INSIGHT CARD
  // =========================================================================

  /// Builds a card for a single [Insight] with a coloured icon and message.
  Widget _buildInsightCard(BuildContext context, Insight insight) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(insight.icon, color: insight.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  RECOMMENDATION CARD
  // =========================================================================

  /// Renders a green-accented card for a single [Recommendation] with a
  /// forward-arrow affordance.
  Widget _buildRecommendationCard(BuildContext context, Recommendation rec) {
    final tc = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.success,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  rec.message,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppColors.success, size: 14),
        ],
      ),
    );
  }

  // =========================================================================
  //  EMPTY STATE
  // =========================================================================

  /// Generic empty-state placeholder shown when no data is available.
  Widget _buildEmptyState(BuildContext context, String message) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: tc.textMuted),
        ),
      ),
    );
  }

  static double _toDouble(dynamic v) => v is num ? v.toDouble() : 0;

  static String _shortHabitName(String name) {
    if (name.length <= 7) return name;
    return '${name.substring(0, 7)}...';
  }
}
