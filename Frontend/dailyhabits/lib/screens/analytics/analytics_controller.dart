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
    notifyListeners();
    await Future.wait([
      loadDashboard(),
      loadHeatmap(),
      loadHabitStats(),
    ]);
    isLoading = false;
    notifyListeners();
  }

  /// Fetches the main analytics dashboard and parses weekly trend data
  /// and category breakdown from the response.
  Future<void> loadDashboard() async {
    try {
      final dashboard = await _analyticsService.getDashboard();
      dashboardData = dashboard;

      if (dashboard.containsKey('weeklyData')) {
        weeklyData = (dashboard['weeklyData'] as List)
            .map((json) => WeeklyDataPoint.fromJson(json))
            .toList();
      }

      categoryBreakdown = await _analyticsService.getCategoryBreakdown();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  /// Fetches the monthly heatmap data for [currentMonth] from the backend.
  Future<void> loadHeatmap() async {
    try {
      monthlyHeatmap = await _analyticsService.getMonthlyHeatmap(
        currentMonth.year,
        currentMonth.month,
      );
    } catch (e) {
      debugPrint('Error loading heatmap: $e');
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
      }
    } catch (e) {
      debugPrint('Error loading habit stats: $e');
    }
  }

  /// Advances or rewinds [currentMonth] by [offset] months and reloads
  /// the heatmap data accordingly. Called by the navigation arrows.
  void changeMonth(int offset) {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + offset);
    loadHeatmap().then((_) => notifyListeners());
  }
}
