import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/models/habit.dart';

class HabitService {
  // Use 10.0.2.2 for Android emulator
  static const String baseUrl = 'http://10.0.2.2:8000/api/habits';
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

  /// Create a new habit
  Future<Habit> createHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      // Ensure we send colorValue and iconCode
      final body = jsonEncode(habit.toJson());

      final response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return Habit.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create habit: ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  /// Update a habit (toggle completion, etc.)
  Future<Habit> updateHabit(Habit habit) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/${habit.id}/'),
        headers: headers,
        body: jsonEncode(habit.toJson()),
      );

      if (response.statusCode == 200) {
        return Habit.fromJson(jsonDecode(response.body));
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

      if (response.statusCode != 204) {
        throw Exception('Failed to delete habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
