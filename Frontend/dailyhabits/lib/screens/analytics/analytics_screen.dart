// =============================================================================
// File: analytics_screen.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: Main analytics dashboard screen that presents the user's habit
//              tracking statistics, including consistency rings, streak cards,
//              category breakdowns, weekly trend charts, and monthly heatmaps.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/screens/analytics/analytics_controller.dart';
import 'package:dailyhabits/screens/analytics/widgets/consistency_ring.dart';
import 'package:dailyhabits/screens/analytics/widgets/streak_card.dart';
import 'package:dailyhabits/screens/analytics/widgets/calendar_heatmap.dart';
import 'package:dailyhabits/screens/analytics/widgets/trend_chart.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';
import 'package:dailyhabits/widgets/common/shimmer_loading.dart';

/// Top-level entry point for the Analytics feature.
///
/// Uses the app-level [AnalyticsController] from the [MultiProvider] in
/// main.dart so that habit toggles can trigger analytics refresh.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AnalyticsView();
  }
}

/// Internal view widget that renders the full analytics dashboard.
///
/// Displays a vertically scrollable layout containing:
/// - A header with title and subtitle
/// - An overview card with consistency ring and today's stats
/// - A streak card showing current and best streaks
/// - A category breakdown with per-category progress bars
/// - A weekly trend line chart
/// - A navigable monthly heatmap calendar
class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final controller = Provider.of<AnalyticsController>(context);
    final canGoBack = Navigator.of(context).canPop();

    // Show shimmer skeleton until the initial dashboard payload arrives
    if (controller.isLoading && controller.dashboardData == null) {
      return Scaffold(
        backgroundColor: tc.bg,
        appBar: AppBar(
          title: const Text('Progress Calendar'),
          centerTitle: true,
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
          actions: [
            if (canGoBack)
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header shimmer
                const ShimmerBox(width: 120, height: 26, borderRadius: 8),
                const SizedBox(height: 6),
                const ShimmerBox(width: 200, height: 14, borderRadius: 6),
                const SizedBox(height: 24),
                // Overview card shimmer
                const ShimmerBox(width: double.infinity, height: 150, borderRadius: 24),
                const SizedBox(height: 20),
                // Streak card shimmer
                const ShimmerBox(width: double.infinity, height: 100, borderRadius: 20),
                const SizedBox(height: 24),
                // Category shimmer
                const ShimmerBox(width: 120, height: 18, borderRadius: 6),
                const SizedBox(height: 12),
                const ShimmerBox(width: double.infinity, height: 140, borderRadius: 20),
                const SizedBox(height: 24),
                // Chart shimmer
                const ShimmerBox(width: 120, height: 18, borderRadius: 6),
                const SizedBox(height: 12),
                const ShimmerBox(width: double.infinity, height: 200, borderRadius: 20),
              ],
            ),
          ),
        ),
      );
    }

    // Extract and safely parse summary statistics from the dashboard payload
    final data = controller.dashboardData ?? {};
    final summary = data['summary'] ?? {};
    final currentStreak = _toInt(summary['currentStreak']);
    final bestStreak = _toInt(summary['bestStreak']);
    final consistency = _toDouble(summary['todayRate']);
    final totalHabits = _toInt(summary['totalHabits']);
    final completions = _toInt(summary['todayCompleted']);
    final weeklyCompletions = _toInt(summary['weeklyCompletions']);
    final avgConsistency = _toDouble(summary['avgConsistency']);
    final wowThisWeek = _toMap(controller.weeklyComparison['thisWeek']);
    final wowLastWeek = _toMap(controller.weeklyComparison['lastWeek']);
    final wowDelta = _toDouble(controller.weeklyComparison['changePercent']);
    final wowTrend = (controller.weeklyComparison['trend'] ?? '').toString();
    final thisWeekDaily = _toDouble(wowThisWeek['dailyAverage']);
    final lastWeekDaily = _toDouble(wowLastWeek['dailyAverage']);
    final trendData = controller.completionTrend;
    final trendDays = controller.selectedTrendDays;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        title: const Text('Progress Calendar'),
        centerTitle: true,
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          if (canGoBack)
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          color: tc.primary,
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tc.primary.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                top: 260,
                left: -80,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tc.secondary.withValues(alpha: 0.06),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _buildBreadcrumbBar(context),
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 18),

                _buildHeroSpotlight(
                  context,
                  consistency: consistency,
                  completions: completions,
                  totalHabits: totalHabits,
                  weeklyCompletions: weeklyCompletions,
                ),
                const SizedBox(height: 18),

                _buildKpiGrid(
                  context,
                  avgConsistency: avgConsistency,
                  currentStreak: currentStreak,
                  bestStreak: bestStreak,
                  thisWeekDaily: thisWeekDaily,
                ),
                const SizedBox(height: 22),

                _buildOverviewCard(
                  context,
                  consistency: consistency,
                  completions: completions,
                  totalHabits: totalHabits,
                  weeklyCompletions: weeklyCompletions,
                  avgConsistency: avgConsistency,
                ),
                const SizedBox(height: 20),

                StreakCard(
                  currentStreak: currentStreak,
                  bestStreak: bestStreak,
                ),
                const SizedBox(height: 24),

                _sectionTitle(context, 'Week-over-Week Momentum'),
                const SizedBox(height: 12),
                _buildWeekComparisonCard(
                  context,
                  thisWeekDaily: thisWeekDaily,
                  lastWeekDaily: lastWeekDaily,
                  delta: wowDelta,
                  trend: wowTrend,
                ),
                const SizedBox(height: 24),

                if (controller.categoryBreakdown.isNotEmpty) ...[
                  _sectionTitle(context, 'By Category'),
                  const SizedBox(height: 12),
                  _buildCategoryBreakdown(context, controller.categoryBreakdown),
                  const SizedBox(height: 24),
                ],

                if (controller.categorySuccess.isNotEmpty) ...[
                  _sectionTitle(context, 'Category Success League'),
                  const SizedBox(height: 12),
                  _buildCategorySuccessCard(context, controller.categorySuccess),
                  const SizedBox(height: 24),
                ],

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

                _sectionTitle(context, 'Performance Pulse'),
                const SizedBox(height: 10),
                _buildTrendWindowSelector(context, controller, trendDays),
                const SizedBox(height: 10),
                if (controller.isTrendLoading)
                  const ShimmerBox(width: double.infinity, height: 220, borderRadius: 20)
                else if (trendData.isNotEmpty)
                  _buildPerformanceTrendCard(context, trendData)
                else
                  _buildEmptyCard(context, 'No trend data available for this range yet'),
                const SizedBox(height: 24),

                if (controller.longTermTrends.isNotEmpty) ...[
                  _sectionTitle(context, '6-Month Performance'),
                  const SizedBox(height: 12),
                  _buildLongTermTrendCard(context, controller.longTermTrends),
                  const SizedBox(height: 24),
                ],

                Row(
                  children: [
                    Expanded(
                      child: _sectionTitle(context, 'Monthly Progress Calendar'),
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
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(color: tc.warning, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbBar(BuildContext context) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You are here: Profile > Quick Access > Progress Calendar',
              style: TextStyle(
                color: tc.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_rounded, size: 16),
            label: const Text('Dashboard'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the screen title and descriptive subtitle.
  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: AppTextStyles.h1.copyWith(color: tc.textPrimary, fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          'Beautiful insights for your habit engine',
          style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
        ),
      ],
    );
  }

  Widget _buildHeroSpotlight(
    BuildContext context, {
    required double consistency,
    required int completions,
    required int totalHabits,
    required int weeklyCompletions,
  }) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            tc.primary,
            tc.secondary.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: tc.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Score',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${consistency.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _statusLabel(consistency),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip('$completions/$totalHabits done today'),
              _heroChip('$weeklyCompletions completions this week'),
              _heroChip('Keep consistency above 70%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildKpiGrid(
    BuildContext context, {
    required double avgConsistency,
    required int currentStreak,
    required int bestStreak,
    required double thisWeekDaily,
  }) {
    final cards = [
      _KpiData('30-day Avg', '${avgConsistency.toStringAsFixed(1)}%', Icons.analytics_rounded, AppColors.info),
      _KpiData('Current Streak', '$currentStreak days', Icons.local_fire_department_rounded, AppColors.warning),
      _KpiData('Best Streak', '$bestStreak days', Icons.emoji_events_rounded, AppColors.success),
      _KpiData('Daily Avg', thisWeekDaily.toStringAsFixed(1), Icons.timeline_rounded, AppColors.secondary),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.52,
      ),
      itemBuilder: (context, index) => _buildKpiCard(context, cards[index]),
    );
  }

  Widget _buildKpiCard(BuildContext context, _KpiData data) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(color: tc.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OVERVIEW CARD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the hero overview card containing a [ConsistencyRing], today's
  /// completion fraction, weekly completions, average consistency, and a
  /// dynamic status badge (On Fire / Solid / Building Up / Getting Started).
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

  /// Renders a small inline stat row used inside the overview card
  /// (e.g. weekly completions, average percentage).
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

  /// Returns an appropriate status colour based on the user's completion [rate].
  Color _statusColor(double rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.secondary;
    if (rate >= 25) return AppColors.warning;
    return AppColors.error;
  }

  /// Returns a human-readable motivation label based on the completion [rate].
  String _statusLabel(double rate) {
    if (rate >= 80) return 'On Fire';
    if (rate >= 50) return 'Solid';
    if (rate >= 25) return 'Building Up';
    return 'Getting Started';
  }

  Widget _buildWeekComparisonCard(
    BuildContext context, {
    required double thisWeekDaily,
    required double lastWeekDaily,
    required double delta,
    required String trend,
  }) {
    final tc = context.colors;
    final bool isUp = delta >= 0;
    final badgeColor = isUp ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: badgeColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}% vs last week',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trend.isEmpty ? 'stable' : trend,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _comparisonMetric(context, 'This week', thisWeekDaily)),
              const SizedBox(width: 10),
              Expanded(child: _comparisonMetric(context, 'Last week', lastWeekDaily)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonMetric(BuildContext context, String label, double value) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: tc.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text('daily completions', style: TextStyle(color: tc.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CATEGORY BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Renders a card listing each habit category with its habit count,
  /// colour-coded dot, progress bar, and average consistency percentage.
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
                // Animated progress bar
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: rate / 100.0),
                      duration: AppDurations.dramatic,
                      curve: AppCurves.smooth,
                      builder: (_, val, _) => LinearProgressIndicator(
                        value: val,
                        minHeight: 6,
                        backgroundColor: tc.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
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

  Widget _buildCategorySuccessCard(BuildContext context, List<Map<String, dynamic>> categories) {
    final tc = context.colors;
    final top = categories.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: List.generate(top.length, (index) {
          final item = top[index];
          final ratio = _toDouble(item['successRatio']);
          final category = (item['category'] ?? 'General').toString();
          final habits = _toInt(item['habitCount']);

          return Padding(
            padding: EdgeInsets.only(bottom: index == top.length - 1 ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700)),
                      Text('$habits habits', style: TextStyle(color: tc.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  '${ratio.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrendWindowSelector(
    BuildContext context,
    AnalyticsController controller,
    int selectedDays,
  ) {
    final options = [7, 30, 90];
    return Row(
      children: options
          .map(
            (days) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildRangeChip(context, controller, selectedDays, days),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRangeChip(
    BuildContext context,
    AnalyticsController controller,
    int selectedDays,
    int days,
  ) {
    final tc = context.colors;
    final selected = selectedDays == days;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => controller.setTrendWindow(days),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.smooth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tc.primary : tc.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tc.primary : tc.border.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          '$days days',
          style: TextStyle(
            color: selected ? Colors.white : tc.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceTrendCard(BuildContext context, List<Map<String, dynamic>> trendData) {
    final tc = context.colors;
    final spots = <FlSpot>[];
    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _toDouble(trendData[i]['rate'])));
    }

    final maxRate = trendData
        .map((e) => _toDouble(e['rate']))
        .fold<double>(0, (prev, value) => value > prev ? value : prev);
    final yCap = ((maxRate / 10).ceil() * 10).clamp(30, 100).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion intensity',
            style: TextStyle(color: tc.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 185,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (trendData.length - 1).toDouble(),
                minY: 0,
                maxY: yCap,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(color: tc.surfaceVariant),
                ),
                borderData: FlBorderData(show: false),
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
                        style: TextStyle(color: tc.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _xIntervalForTrend(trendData.length),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trendData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _trendDateLabel(trendData[idx]['date']),
                            style: TextStyle(color: tc.textMuted, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}%',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    barWidth: 4,
                    color: tc.primary,
                    dotData: FlDotData(
                      show: trendData.length <= 14,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3.2,
                        color: tc.primary,
                        strokeColor: tc.card,
                        strokeWidth: 1,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tc.primary.withValues(alpha: 0.22),
                          tc.secondary.withValues(alpha: 0.05),
                        ],
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

  Widget _buildLongTermTrendCard(BuildContext context, List<Map<String, dynamic>> trends) {
    final tc = context.colors;
    final maxRate = trends
        .map((e) => _toDouble(e['completionRate']))
        .fold<double>(0, (prev, value) => value > prev ? value : prev);
    final yCap = ((maxRate / 10).ceil() * 10).clamp(40, 100).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(color: tc.surfaceVariant),
                  drawVerticalLine: false,
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
                        if (i < 0 || i >= trends.length) return const SizedBox.shrink();
                        final label = (trends[i]['month'] ?? '').toString();
                        final short = label.isNotEmpty ? label.split(' ').first : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(short, style: TextStyle(fontSize: 10, color: tc.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: yCap,
                barGroups: List.generate(trends.length, (index) {
                  final rate = _toDouble(trends[index]['completionRate']);
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: rate,
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
          const SizedBox(height: 8),
          Text(
            'Completion rate over the last 6 months',
            style: TextStyle(color: tc.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds a bold section title used to separate dashboard segments.
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

  /// Displays a subtle empty-state placeholder with an icon and [message]
  /// when a data section has no content to show.
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

  /// Safely casts a dynamic value to [int], defaulting to `0`.
  static int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

  /// Safely casts a dynamic value to [double], defaulting to `0.0`.
  static double _toDouble(dynamic v) => v is double ? v : (v is num ? v.toDouble() : 0.0);

  /// Safely casts a dynamic value to [Map<String, dynamic>].
  static Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  static double _xIntervalForTrend(int length) {
    if (length <= 8) return 1;
    if (length <= 20) return 3;
    if (length <= 45) return 7;
    return 15;
  }

  static String _trendDateLabel(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.length >= 10) {
      return text.substring(5).replaceAll('-', '/');
    }
    return text;
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiData(this.label, this.value, this.icon, this.color);
}
