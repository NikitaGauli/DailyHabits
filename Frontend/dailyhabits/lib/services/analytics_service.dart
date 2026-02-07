import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/analytics_summary.dart';

class AnalyticsService {
  final AuthService _authService = AuthService();

  String get _baseUrl => '${ApiConfig.baseUrl}/analytics';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get main dashboard analytics
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

  /// Get weekly data
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

  /// Get monthly heatmap data
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

  /// Get category breakdown
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
