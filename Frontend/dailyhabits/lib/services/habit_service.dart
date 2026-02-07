import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/habit.dart';

class HabitService {
  /// Centralized base URL from ApiConfig
  static String get baseUrl => '${ApiConfig.baseUrl}/habits';

  final AuthService _authService = AuthService();

  // Helper to get headers with token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all habits
  Future<List<Habit>> getHabits() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Habit.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load habits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Fetch today's scheduled habits
  Future<Map<String, dynamic>> getTodayHabits() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
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

  /// Create a new habit
  Future<Habit> createHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(habit.toJson());

      final response = await http.post(
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

  /// Toggle completion for today
  Future<Map<String, dynamic>> toggleHabit(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/$id/toggle-complete/'),
        headers: headers,
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

  /// Skip a habit for today
  Future<bool> skipHabit(String id, {String reason = ''}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
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

  /// Get available categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
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

  /// Fetch habit analytics/stats
  Future<Map<String, dynamic>> getStats(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
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

  /// Get overall stats summary
  Future<Map<String, dynamic>> getStatsSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
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

  /// Fetch habit completion history
  Future<Map<String, dynamic>> getHistory(String id, {int days = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
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

  /// Update a habit
  Future<Habit> updateHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
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

  /// Delete a habit
  Future<void> deleteHabit(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
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
