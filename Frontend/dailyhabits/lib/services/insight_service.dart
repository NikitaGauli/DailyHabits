import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/insight.dart';

class InsightService {
  final AuthService _authService = AuthService();

  String get _baseUrl => '${ApiConfig.baseUrl}/insights';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get daily insights and quote
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

  /// Get specific category quote
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
