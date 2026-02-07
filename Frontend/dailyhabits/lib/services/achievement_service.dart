import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/achievement.dart';

class AchievementService {
  final AuthService _authService = AuthService();

  String get _baseUrl => '${ApiConfig.baseUrl}/achievements';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all achievements
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

  /// Get user level info
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
