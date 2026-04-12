import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dailyhabits/models/habit.dart';
import 'package:dailyhabits/models/habit_analysis.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/services/auth_service.dart';
import 'package:http/http.dart' as http;

class RecommendationService {
  RecommendationService({AuthService? authService, http.Client? client})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  String get _baseUrl => ApiConfig.baseUrl;

  static const String _logTag = 'RecommendationService';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _logResponse(String endpoint, http.Response response) {
    final body = response.body;
    final preview = body.length > 400 ? '${body.substring(0, 400)}...' : body;
    developer.log(
      '[$endpoint] status=${response.statusCode} body=$preview',
      name: _logTag,
    );
  }

  String _extractErrorMessage(String endpoint, http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }

        final detail = decoded['detail']?.toString();
        if (detail != null && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Ignore parse failures and return fallback below.
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Your session expired. Please sign in again.';
    }

    return 'Request failed for $endpoint (HTTP ${response.statusCode}).';
  }

  Never _throwNetworkError(String endpoint, Object error) {
    if (error is SocketException) {
      throw Exception('Connection error. Please check your internet and try again.');
    }

    if (error is HttpException) {
      throw Exception('Service is temporarily unavailable. Please try again.');
    }

    throw Exception('Unexpected error while calling $endpoint. ${error.toString()}');
  }

  Map<String, dynamic> _decodeJsonMap(String endpoint, String body) {
    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      developer.log(
        '[$endpoint] decodedType=Map keys=${decoded.keys.toList()}',
        name: _logTag,
      );
      return decoded;
    }

    throw Exception(
      'Unexpected response type for $endpoint. Expected JSON object but got ${decoded.runtimeType}.',
    );
  }

  Map<String, dynamic> _extractAnalysisData(Map<String, dynamic> decoded) {
    final rawData = decoded['data'];

    if (rawData is Map<String, dynamic>) {
      return rawData;
    }

    if (rawData is List && rawData.isNotEmpty && rawData.first is Map<String, dynamic>) {
      developer.log(
        '[analysis] data was List; using first element for compatibility.',
        name: _logTag,
      );
      return rawData.first as Map<String, dynamic>;
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Invalid prediction response format: data must be an object.',
    );
  }

  List<dynamic> _extractHistoryList(Map<String, dynamic> decoded) {
    final candidates = [
      decoded['results'],
      decoded['data'],
      decoded['history'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate;
      }
    }

    throw Exception(
      'Invalid history response format: expected a list in results/data/history.',
    );
  }

  Map<String, dynamic> _sampleFromHabit(Habit habit) {
    final streak = habit.streak?.currentStreak ?? habit.currentStreak;

    final totalCompletions = habit.streak?.totalCompletions ?? 0;
    final totalSkips = habit.streak?.totalSkips ?? 0;
    final totalMisses = habit.streak?.totalMisses ?? 0;
    final total = totalCompletions + totalSkips + totalMisses;
    final completionRate = total > 0 ? (totalCompletions / total) * 100.0 : 0.0;

    return {
      'frequency': habit.frequency,
      'completion_rate': completionRate,
      'streak': streak,
      'category': habit.category,
    };
  }

  Future<HabitAnalysisResult> analyzeHabits(List<Habit> habits) async {
    const endpoint = '/predict-habits/';
    try {
      final headers = await _getHeaders();
      final payload = {
        'habits': habits.map(_sampleFromHabit).toList(),
      };

      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(payload),
      );

      _logResponse(endpoint, response);

      if (response.statusCode != 200) {
        throw Exception(_extractErrorMessage(endpoint, response));
      }

      final decoded = _decodeJsonMap(endpoint, response.body);
      if (decoded['success'] != true) {
        throw Exception(decoded['message']?.toString() ?? 'Prediction failed.');
      }

      final data = _extractAnalysisData(decoded);
      return HabitAnalysisResult.fromJson(data);
    } on FormatException {
      throw Exception('Received invalid prediction data from server.');
    } catch (error) {
      _throwNetworkError(endpoint, error);
    }
  }

  Future<HabitAnalysisResult> analyzeFromServerData() async {
    const endpoint = '/predict-habits/auto/';
    try {
      final headers = await _getHeaders();

      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      );

      _logResponse(endpoint, response);

      if (response.statusCode != 200) {
        throw Exception(_extractErrorMessage(endpoint, response));
      }

      final decoded = _decodeJsonMap(endpoint, response.body);
      if (decoded['success'] != true) {
        throw Exception(decoded['message']?.toString() ?? 'Automatic prediction failed.');
      }

      final data = _extractAnalysisData(decoded);
      return HabitAnalysisResult.fromJson(data);
    } on FormatException {
      throw Exception('Received invalid automatic prediction data from server.');
    } catch (error) {
      _throwNetworkError(endpoint, error);
    }
  }

  Future<List<HabitAnalysisHistoryItem>> getHistory({int limit = 20}) async {
    const endpoint = '/predict-habits/history/';
    try {
      final headers = await _getHeaders();

      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint?limit=$limit'),
        headers: headers,
      );

      _logResponse(endpoint, response);

      if (response.statusCode != 200) {
        throw Exception(_extractErrorMessage(endpoint, response));
      }

      final decoded = _decodeJsonMap(endpoint, response.body);
      if (decoded['success'] == false) {
        throw Exception(decoded['message']?.toString() ?? 'Failed to load analysis history.');
      }

      final results = _extractHistoryList(decoded);
      return results
          .whereType<Map<String, dynamic>>()
          .map(HabitAnalysisHistoryItem.fromJson)
          .toList();
    } on FormatException {
      throw Exception('Received invalid analysis history data from server.');
    } catch (error) {
      _throwNetworkError(endpoint, error);
    }
  }
}
