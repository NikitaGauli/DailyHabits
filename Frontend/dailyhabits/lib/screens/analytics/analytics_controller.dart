import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/habit_service.dart';
import '../../models/analytics_summary.dart';

class AnalyticsController extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();
  final HabitService _habitService = HabitService();

  bool isLoading = true;
  Map<String, dynamic>? dashboardData;
  List<WeeklyDataPoint> weeklyData = [];
  List<Map<String, dynamic>> categoryBreakdown = [];
  List<Map<String, dynamic>> monthlyHeatmap = [];
  List<Map<String, dynamic>> habitStats = [];

  DateTime currentMonth = DateTime.now();

  AnalyticsController() {
    _loadAll();
  }

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

  void changeMonth(int offset) {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + offset);
    loadHeatmap().then((_) => notifyListeners());
  }
}
