// =============================================================================
// File: analytics_controller.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: State management controller for the Analytics screen. Fetches
//              dashboard summary data, weekly trend data, category breakdowns,
//              monthly heatmaps, and habit statistics from backend services and
//              exposes reactive state via [ChangeNotifier].
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/habit_service.dart';
import '../../models/analytics_summary.dart';

/// Reactive state controller for the Analytics dashboard.
///
/// On construction, it concurrently loads all analytics data from
/// [AnalyticsService] and [HabitService]. The UI observes this controller
/// via [Provider] and re-builds whenever [notifyListeners] fires.
///
/// Key data exposed:
/// - [dashboardData] — Raw summary map returned by the backend.
/// - [weeklyData] — Parsed [WeeklyDataPoint] list for the trend chart.
/// - [categoryBreakdown] — Per-category completion statistics.
/// - [monthlyHeatmap] — Daily completion counts for the calendar view.
/// - [habitStats] — General habit statistics.
class AnalyticsController extends ChangeNotifier {
  /// Service responsible for all analytics-related API calls.
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Service responsible for habit-specific API calls (stats summary).
  final HabitService _habitService = HabitService();

  // ── Observable State ────────────────────────────────────────────────────

  /// Whether the controller is performing its initial data fetch.
  bool isLoading = true;

  /// Raw dashboard JSON payload from the backend.
  Map<String, dynamic>? dashboardData;

  /// Parsed weekly completion data points for the trend chart.
  List<WeeklyDataPoint> weeklyData = [];

  /// Per-category breakdown showing habit counts and average consistency.
  List<Map<String, dynamic>> categoryBreakdown = [];

  /// Daily completion counts used to render the monthly heatmap calendar.
  List<Map<String, dynamic>> monthlyHeatmap = [];

  /// General habit statistics from the habit service.
  List<Map<String, dynamic>> habitStats = [];

  /// Week-over-week comparison metrics.
  Map<String, dynamic> weeklyComparison = {};

  /// Month-by-month trend values for long horizon charts.
  List<Map<String, dynamic>> longTermTrends = [];

  /// Category success ratios used for leaderboard-style display.
  List<Map<String, dynamic>> categorySuccess = [];

  /// Selected day-window for the dynamic performance trend.
  int selectedTrendDays = 30;

  /// Time-series payload for the selected trend window.
  List<Map<String, dynamic>> completionTrend = [];

  /// Loading state for trend-window switches.
  bool isTrendLoading = false;

  /// Optional readable error shown by the analytics view.
  String? errorMessage;

  /// The month currently displayed in the heatmap calendar.
  DateTime currentMonth = DateTime.now();

  /// Creates the controller and immediately begins loading all data.
  AnalyticsController() {
    _loadAll();
  }

  /// Loads all analytics data concurrently and toggles [isLoading] state.
  ///
  /// Uses [Future.wait] to fire dashboard, heatmap, and habit stats
  /// requests in parallel. Notifies listeners before and after loading.
  Future<void> _loadAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([
        loadDashboard(),
        loadHeatmap(),
        loadHabitStats(),
        loadEnhancedInsights(),
        loadCompletionTrend(days: selectedTrendDays, showLoading: false),
      ]);
    } catch (_) {
      errorMessage = 'Unable to load analytics right now.';
    }
    isLoading = false;
    notifyListeners();
  }

  /// Fetches the main analytics dashboard and parses weekly trend data
  /// and category breakdown from the response.
  Future<void> loadDashboard() async {
    try {
      final dashboard = await _analyticsService.getDashboard();
      final hasNestedSummary = dashboard['summary'] is Map<String, dynamic>;
      dashboardData = hasNestedSummary
          ? dashboard
          : {
              'summary': dashboard,
              'weeklyData': dashboard['weeklyData'] ?? [],
            };

      if (dashboardData!.containsKey('weeklyData')) {
        weeklyData = (dashboardData!['weeklyData'] as List)
            .map((json) => WeeklyDataPoint.fromJson(json))
            .toList();
      }

      categoryBreakdown = await _analyticsService.getCategoryBreakdown();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      errorMessage ??= 'Failed to load dashboard data.';
    }
  }

  /// Fetches the monthly heatmap data for [currentMonth] from the backend.
  Future<void> loadHeatmap() async {
    try {
      monthlyHeatmap = await _analyticsService.getMonthlyHeatmap(
        currentMonth.year,
        currentMonth.month,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading heatmap: $e');
      errorMessage ??= 'Failed to load monthly heatmap.';
    }
  }

  /// Fetches a general stats summary and merges it into [dashboardData]
  /// if the dashboard hasn't been populated yet.
  Future<void> loadHabitStats() async {
    try {
      final statsSummary = await _habitService.getStatsSummary();
      if (statsSummary.containsKey('totalHabits')) {
        // Merge into dashboard if not yet loaded
        dashboardData ??= {};
        dashboardData!['summary'] ??= statsSummary;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading habit stats: $e');
      errorMessage ??= 'Failed to load habit stats.';
    }
  }

  /// Fetches additional insights for richer charting and comparisons.
  Future<void> loadEnhancedInsights() async {
    try {
      final results = await Future.wait([
        _analyticsService.getWeeklyComparison(),
        _analyticsService.getLongTermTrends(months: 6),
        _analyticsService.getCategorySuccess(),
      ]);

      weeklyComparison = results[0] as Map<String, dynamic>;
      longTermTrends = results[1] as List<Map<String, dynamic>>;
      categorySuccess = results[2] as List<Map<String, dynamic>>;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading enhanced insights: $e');
      errorMessage ??= 'Some insights are temporarily unavailable.';
    }
  }

  /// Loads a completion trend for the selected [days] window.
  Future<void> loadCompletionTrend({required int days, bool showLoading = true}) async {
    if (showLoading) {
      isTrendLoading = true;
      notifyListeners();
    }

    selectedTrendDays = days;
    try {
      completionTrend = await _analyticsService.getCompletionTrend(days: days);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading completion trend: $e');
      errorMessage ??= 'Failed to load performance trend.';
    } finally {
      isTrendLoading = false;
      notifyListeners();
    }
  }

  /// Updates trend range and refreshes the trend series.
  Future<void> setTrendWindow(int days) async {
    if (selectedTrendDays == days && completionTrend.isNotEmpty) return;
    await loadCompletionTrend(days: days);
  }

  /// Advances or rewinds [currentMonth] by [offset] months and reloads
  /// the heatmap data accordingly. Called by the navigation arrows.
  void changeMonth(int offset) {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + offset);
    loadHeatmap().then((_) => notifyListeners());
  }

  /// Refreshes all analytics data. Call after habit completions or toggles
  /// to ensure the analytics screen reflects the latest data.
  Future<void> refresh() async {
    await _loadAll();
  }
}
