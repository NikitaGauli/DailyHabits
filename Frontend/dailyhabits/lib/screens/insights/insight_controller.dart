// =============================================================================
// insight_controller.dart — Insights Business Logic
// =============================================================================
// State controller for the Insights screen.
//
// Fetches the daily summary (quote, insights, and recommendations) from
// [InsightService] and exposes reactive properties consumed by the UI
// via `Provider`.
//
// Data is loaded eagerly in the constructor so the screen shows content
// as soon as it is mounted.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/insight_service.dart';
import '../../models/insight.dart';

/// Manages the loaded state for [InsightScreen].
///
/// Holds:
///  • [dailyQuote] – an optional motivational quote.
///  • [insights] – AI-generated performance insights.
///  • [recommendations] – actionable habit improvement suggestions.
class InsightController extends ChangeNotifier {
  /// API service used to fetch insight data.
  final InsightService _service = InsightService();

  /// Whether the initial data load is in progress.
  bool isLoading = true;

  /// Today’s motivational quote (may be `null` if unavailable).
  MotivationalQuote? dailyQuote;

  /// List of AI-generated insight cards.
  List<Insight> insights = [];

  /// List of recommended actions for the user.
  List<Recommendation> recommendations = [];

  /// Best time-of-day payload for pie chart and performance callout.
  Map<String, dynamic> bestTime = {};

  /// Top consistent habits for bar-chart comparison.
  List<Map<String, dynamic>> topHabits = [];

  /// Declining habits comparison payloads for trend visualizations.
  List<Map<String, dynamic>> decliningHabits = [];

  /// Time series points for line-chart trend section.
  List<Map<String, dynamic>> trendSeries = [];

  InsightController() {
    loadData();
  }

  /// Loads (or reloads) the daily summary from the backend.
  ///
  /// Sets [isLoading] to `true` before the call and `false` when done,
  /// notifying listeners at both transitions.
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await _service.getDailySummary();

      if (data.containsKey('quote')) dailyQuote = data['quote'];
      if (data.containsKey('insights')) insights = data['insights'];
      if (data.containsKey('recommendations')) {
        recommendations = data['recommendations'];
      }
      if (data.containsKey('bestTime')) {
        bestTime = Map<String, dynamic>.from(data['bestTime'] as Map);
      }
      if (data.containsKey('topHabits')) {
        topHabits = List<Map<String, dynamic>>.from(data['topHabits'] as List);
      }
      if (data.containsKey('decliningHabits')) {
        decliningHabits = List<Map<String, dynamic>>.from(data['decliningHabits'] as List);
      }

      trendSeries = await _service.getInsightTrend(days: 14);
    } catch (e) {
      debugPrint('Error loading insights: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
