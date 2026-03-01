// =============================================================================
// File: analytics_service.dart
// Description: Analytics service for the DailyHabits application.
//              Provides dashboard summaries, weekly trend data, monthly
//              heatmap visualizations, and category-level breakdowns by
//              communicating with the backend analytics engine.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/analytics_summary.dart';

// =============================================================================
// Analytics Service
// =============================================================================

/// Service layer for retrieving habit analytics and performance metrics.
///
/// Exposes four primary data views:
/// - **Dashboard** — High-level summary with weekly aggregates.
/// - **Weekly data** — Day-by-day completion data points for chart rendering.
/// - **Monthly heatmap** — Per-day intensity values for a calendar heatmap.
/// - **Category breakdown** — Completion statistics grouped by habit category.
///
/// All requests are authenticated via JWT tokens from [AuthService].
class AnalyticsService {
  // ---------------------------------------------------------------------------
  // Dependencies & Configuration
  // ---------------------------------------------------------------------------

  /// Shared [AuthService] instance for retrieving the JWT token.
  final AuthService _authService = AuthService();

  /// Base URL for analytics endpoints, derived from [ApiConfig].
  String get _baseUrl => '${ApiConfig.baseUrl}/analytics';

  /// Builds authenticated HTTP headers with JSON content type.
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  /// Fetches the main analytics dashboard payload.
  ///
  /// Returns a map containing `summary` (aggregate metrics) and `weeklyData`
  /// (per-day completion counts). Throws on network or server errors.
  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']; // Returns summary + weeklyData
        }
      }
      throw Exception('Failed to load dashboard data');
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Weekly Trends
  // ---------------------------------------------------------------------------

  /// Retrieves day-by-day completion data for a given week.
  ///
  /// [weeksBack] controls how far into the past to look (0 = current week).
  /// Each [WeeklyDataPoint] contains the day label and completion value,
  /// suitable for rendering line or bar charts. Returns an empty list on error.
  Future<List<WeeklyDataPoint>> getWeeklyData({int weeksBack = 0}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/weekly/?weeksBack=$weeksBack'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((json) => WeeklyDataPoint.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Monthly Heatmap
  // ---------------------------------------------------------------------------

  /// Fetches heatmap data for the specified [year] and [month].
  ///
  /// Returns a list of maps, each representing a day with its completion
  /// intensity value. Designed for calendar-style heatmap visualizations.
  /// Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> getMonthlyHeatmap(
    int year,
    int month,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/monthly/?year=$year&month=$month'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['heatmap']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Category Breakdown
  // ---------------------------------------------------------------------------

  /// Retrieves completion statistics grouped by habit category.
  ///
  /// Each entry contains the category name, habit count, and average
  /// completion rate. Useful for pie or bar chart visualizations.
  /// Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> getCategoryBreakdown() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/category-breakdown/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['categories']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
