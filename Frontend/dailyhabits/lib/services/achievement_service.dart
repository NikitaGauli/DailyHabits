// =============================================================================
// File: achievement_service.dart
// Description: Achievement and gamification service for the DailyHabits app.
//              Retrieves the user's earned achievements and current level/XP
//              progression from the backend gamification engine.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/achievement.dart';

// =============================================================================
// Achievement Service
// =============================================================================

/// Service responsible for retrieving achievement badges and user level data.
///
/// The gamification system awards achievements based on habit streaks,
/// completion milestones, and other engagement criteria. This service exposes:
/// - **Achievements** — A catalogue of all badges with their unlock status.
/// - **User Level** — The current level, XP progress, and next-level threshold.
///
/// All requests are authenticated via JWT tokens from [AuthService].
class AchievementService {
  // ---------------------------------------------------------------------------
  // Dependencies & Configuration
  // ---------------------------------------------------------------------------

  /// Shared [AuthService] instance for retrieving the JWT token.
  final AuthService _authService = AuthService();

  /// Base URL for achievement endpoints, derived from [ApiConfig].
  String get _baseUrl => '${ApiConfig.baseUrl}/achievements';

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

  /// Fetches the full list of achievements for the authenticated user.
  ///
  /// Each [Achievement] contains the badge metadata and whether the user has
  /// unlocked it. Returns an empty list on any failure.
  Future<List<Achievement>> getAchievements() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['achievements'] as List)
              .map((json) => Achievement.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Retrieves the user’s current level, XP, and progression details.
  ///
  /// Returns a [UserLevel] object containing the numeric level, current XP,
  /// XP required for the next level, and the level title. Returns `null` if
  /// the request fails or the user has no level data yet.
  Future<UserLevel?> getUserLevel() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/level/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return UserLevel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
