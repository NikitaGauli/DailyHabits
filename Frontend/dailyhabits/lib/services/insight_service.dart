// =============================================================================
// File: insight_service.dart
// Description: Insight and motivation service for the DailyHabits application.
//              Delivers daily AI-generated insights, motivational quotes, and
//              personalised recommendations from the backend insights engine.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/insight.dart';

// =============================================================================
// Insight Service
// =============================================================================

/// Service responsible for fetching daily insights, motivational quotes, and
/// personalised habit recommendations.
///
/// The backend analyses the user’s habit data to generate:
/// - **Insights** — Data-driven observations about habit patterns.
/// - **Quotes** — Context-aware motivational quotes by category.
/// - **Recommendations** — Actionable suggestions to improve consistency.
///
/// All requests are authenticated via JWT tokens from [AuthService].
class InsightService {
  // ---------------------------------------------------------------------------
  // Dependencies & Configuration
  // ---------------------------------------------------------------------------

  /// Shared [AuthService] instance for retrieving the JWT token.
  final AuthService _authService = AuthService();

  /// Base URL for insight endpoints, derived from [ApiConfig].
  String get _baseUrl => '${ApiConfig.baseUrl}/insights';

  /// Builds authenticated HTTP headers with JSON content type.
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetches the complete daily summary including insights, quote, and
  /// recommendations.
  ///
  /// Returns a map containing:
  /// - `insights`        — `List<Insight>` of data-driven observations.
  /// - `quote`           — A [MotivationalQuote] for the day.
  /// - `recommendations` — `List<Recommendation>` for improvement.
  /// - `comeback`        — Comeback message if the user was inactive.
  /// - `bestTime`        — The optimal time of day for habit completion.
  ///
  /// Returns an empty map on any failure.
  Future<Map<String, dynamic>> getDailySummary() async {
    try {
      final headers = await _getHeaders();
      // Using 'summary' endpoint which aggregates everything
      final response = await http.get(
        Uri.parse('$_baseUrl/summary/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final insights = (data['insights'] as List)
              .map((json) => Insight.fromJson(json))
              .toList();

          final quote = MotivationalQuote.fromJson(data['quote']);

          final recommendations = (data['recommendations'] as List)
              .map((json) => Recommendation.fromJson(json))
              .toList();

          return {
            'insights': insights,
            'quote': quote,
            'recommendations': recommendations,
            'comeback': data['comeback'],
            'bestTime': data['bestTime'],
          };
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Fetches a motivational quote filtered by [category].
  ///
  /// Categories might include `fitness`, `mindfulness`, `productivity`, etc.
  /// Returns `null` if no quote is available or the request fails.
  Future<MotivationalQuote?> getQuote(String category) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/quote/?category=$category'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return MotivationalQuote.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
