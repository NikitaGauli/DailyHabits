// =============================================================================
// File: habit_service.dart
// Description: Core habit management service for the DailyHabits application.
//              Provides full CRUD operations, daily scheduling, completion
//              toggling, skip tracking, category listing, and statistics
//              retrieval through the Django REST Framework backend.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/habit.dart';

// =============================================================================
// Habit Service
// =============================================================================

/// Service layer for all habit-related API interactions.
///
/// Provides methods to:
/// - **CRUD** — Create, read, update, and delete habits.
/// - **Daily schedule** — Fetch today’s habits with completion summaries.
/// - **Completion** — Toggle completion status and skip habits.
/// - **Categories** — Retrieve the list of default habit categories.
/// - **Statistics** — Fetch per-habit stats, overall summaries, and history.
///
/// All requests require a valid JWT token obtained from [AuthService].
class HabitService {
  // ---------------------------------------------------------------------------
  // Configuration & Dependencies
  // ---------------------------------------------------------------------------

  /// Base URL for habit endpoints, derived from [ApiConfig].
  static String get baseUrl => '${ApiConfig.baseUrl}/habits';

  HabitService({AuthService? authService, http.Client? client})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  /// Shared instance of [AuthService] used to retrieve the JWT token.
  final AuthService _authService;

  final http.Client _client;

  /// Builds the standard HTTP headers including the JWT `Authorization` bearer
  /// token and JSON content type.
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Read Operations
  // ---------------------------------------------------------------------------

  /// Fetches all habits for the authenticated user.
  ///
  /// Returns a list of [Habit] objects parsed from the JSON array response.
  /// Throws an [Exception] if the request fails or the server is unreachable.
  Future<List<Habit>> getHabits() async {
    try {
      final headers = await _getHeaders();
      final response =
          await _client.get(Uri.parse('$baseUrl/'), headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Support both legacy list responses and wrapped payloads.
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(Habit.fromJson)
              .toList();
        }

        if (decoded is Map<String, dynamic>) {
          final candidates = [
            decoded['habits'],
            decoded['results'],
            decoded['data'],
            decoded['items'],
          ];

          for (final candidate in candidates) {
            if (candidate is List) {
              return candidate
                  .whereType<Map<String, dynamic>>()
                  .map(Habit.fromJson)
                  .toList();
            }
          }

          if (decoded['data'] is Map<String, dynamic>) {
            final nested = decoded['data'] as Map<String, dynamic>;
            final nestedList = nested['habits'] ?? nested['results'] ?? nested['items'];
            if (nestedList is List) {
              return nestedList
                  .whereType<Map<String, dynamic>>()
                  .map(Habit.fromJson)
                  .toList();
            }
          }
        }

        throw Exception('Unexpected habits response format');
      } else {
        throw Exception('Failed to load habits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Fetches today’s scheduled habits along with a completion summary.
  ///
  /// Returns a map containing:
  /// - `habits` — A `List<Habit>` of habits scheduled for today.
  /// - `summary` — A map with today’s completion statistics (may be `null`).
  ///
  /// Returns an empty list and `null` summary on error instead of throwing.
  Future<Map<String, dynamic>> getTodayHabits() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/today/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> habitsJson = data['habits'];
          final habits = habitsJson
              .map((json) => Habit.fromJson(json))
              .toList();
          return {'habits': habits, 'summary': data['summary']};
        }
      }
      throw Exception('Failed to load today\'s habits');
    } catch (e) {
      debugPrint('Error fetching today habits: $e');
      return {'habits': <Habit>[], 'summary': null};
    }
  }

  // ---------------------------------------------------------------------------
  // Create / Update / Delete Operations
  // ---------------------------------------------------------------------------

  /// Creates a new habit on the backend from the given [habit] model.
  ///
  /// Sends a `POST` request with the serialized habit JSON. Returns the
  /// server-created [Habit] (including its assigned `id`).
  ///
  /// Handles two possible response shapes:
  /// - `{ success: true, habit: {...} }` — standard wrapper.
  /// - Direct habit JSON — fallback for simpler responses.
  Future<Habit> createHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(habit.toJson());

      final response = await _client.post(
        Uri.parse('$baseUrl/'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['habit'] != null) {
          return Habit.fromJson(data['habit']);
        }
        // Fallback if structure is different
        return Habit.fromJson(data);
      } else {
        throw Exception('Failed to create habit: ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Completion & Skip Operations
  // ---------------------------------------------------------------------------

  /// Toggles the completion status of a habit for today.
  ///
  /// Sends a `POST` to `/habits/{id}/toggle-complete/`. The backend flips the
  /// current completion state and returns the updated status.
  Future<Map<String, dynamic>> toggleHabit(
    String id, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/toggle-complete/'),
        headers: headers,
        body: payload != null ? jsonEncode(payload) : null,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to toggle habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Marks a habit as skipped for today with an optional [reason].
  ///
  /// Returns `true` on success (HTTP 200), `false` otherwise.
  Future<bool> skipHabit(String id, {String reason = ''}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/skip/'),
        headers: headers,
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Retrieves the list of default habit categories from the backend.
  ///
  /// Each category is a map containing at minimum a `name` and `icon` key.
  /// Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/categories/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['defaultCategories']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Statistics & History
  // ---------------------------------------------------------------------------

  /// Fetches detailed analytics and statistics for a single habit by [id].
  ///
  /// The returned map includes streak data, completion rate, and trend info.
  Future<Map<String, dynamic>> getStats(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/$id/stats/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Retrieves the aggregate statistics summary across all user habits.
  ///
  /// Includes metrics such as total habits, overall completion rate, and
  /// active streaks. Returns an empty map on failure.
  Future<Map<String, dynamic>> getStatsSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/stats_summary/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Fetches the completion history for a habit over the last [days] days.
  ///
  /// Defaults to a 30-day window. Returns a map containing a `history` list
  /// with daily completion entries. Returns `{'history': []}` on failure.
  Future<Map<String, dynamic>> getHistory(String id, {int days = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/$id/history/?days=$days'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'history': []};
    } catch (e) {
      return {'history': []};
    }
  }

  /// Archives a habit while preserving all logs and stats.
  Future<bool> archiveHabit(String id, {String reason = ''}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/archive/'),
        headers: headers,
        body: jsonEncode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Restores an archived habit back to active state.
  Future<bool> unarchiveHabit(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/unarchive/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Marks a day as missed for a habit. If [date] is omitted, backend uses today.
  Future<Map<String, dynamic>?> markMissed(
    String id, {
    String? date,
    String notes = '',
  }) async {
    try {
      final headers = await _getHeaders();
      final payload = <String, dynamic>{
        'notes': notes,
      };
      if (date != null && date.isNotEmpty) {
        payload['date'] = date;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/$id/mark-missed/'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches missed-day summary across habits for a lookback period.
  Future<Map<String, dynamic>> getMissedDaysSummary({int days = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/missed-days/?days=$days'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'totalMissed': 0, 'habits': [], 'records': []};
    } catch (_) {
      return {'success': false, 'totalMissed': 0, 'habits': [], 'records': []};
    }
  }

  /// Updates an existing habit on the backend using a `PATCH` request.
  ///
  /// Sends only the fields present in [habit.toJson()]. Returns the updated
  /// [Habit] as echoed back by the server.
  Future<Habit> updateHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.patch(
        Uri.parse('$baseUrl/${habit.id}/'),
        headers: headers,
        body: jsonEncode(habit.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['habit'] != null) {
          return Habit.fromJson(data['habit']);
        }
        return Habit.fromJson(data);
      } else {
        throw Exception('Failed to update habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Permanently deletes the habit with the given [id] from the backend.
  ///
  /// Accepts both HTTP 200 and 204 as successful responses.
  Future<void> deleteHabit(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl/$id/'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
