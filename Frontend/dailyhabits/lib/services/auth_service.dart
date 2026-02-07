import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dailyhabits/services/api_config.dart';

class AuthService {
  /// Centralized base URL from ApiConfig
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Attempt to login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$baseUrl/login/';
    debugPrint('AUTH ➜ POST $url');
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Login failed',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Server is not responding. Make sure the backend is running on port ${ApiConfig.timeout.inSeconds}s.',
      };
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Register a new user
  Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
  ) async {
    final url = '$baseUrl/register/';
    debugPrint('AUTH ➜ POST $url');
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'name': name,
              'password': password,
              'password2': password,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _extractErrorMessage(data)};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Server is not responding. Make sure the backend is running.',
      };
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Logout the user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Get stored auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Save token and user data from API response
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Backend returns 'token' key (JWT access token)
    if (data.containsKey('access')) {
      await prefs.setString(_tokenKey, data['access']);
    } else if (data.containsKey('token')) {
      await prefs.setString(_tokenKey, data['token']);
    }

    if (data.containsKey('user')) {
      await prefs.setString(_userKey, jsonEncode(data['user']));
    }
  }

  /// Extract user-friendly error from DRF validation errors
  String _extractErrorMessage(dynamic data) {
    if (data is String) return data;

    if (data is Map<String, dynamic>) {
      // First check if there are field-level errors from DRF
      if (data.containsKey('errors') && data['errors'] is Map) {
        final messages = <String>[];
        (data['errors'] as Map).forEach((key, value) {
          final label = _fieldLabel(key.toString());
          if (value is List) {
            for (final v in value) {
              messages.add('$label: $v');
            }
          } else {
            messages.add('$label: $value');
          }
        });
        if (messages.isNotEmpty) return messages.join('\n');
      }

      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('message') && data['message'] != 'Registration failed' && data['message'] != 'Invalid data') {
        return data['message'].toString();
      }

      // Fallback: parse top-level field errors
      final messages = <String>[];
      data.forEach((key, value) {
        if (key == 'success' || key == 'message' || key == 'errors') return;
        final label = _fieldLabel(key);
        if (value is List) {
          for (final v in value) {
            messages.add('$label: $v');
          }
        } else if (value is String) {
          messages.add('$label: $value');
        }
      });
      if (messages.isNotEmpty) return messages.join('\n');
    }

    return 'An unknown error occurred';
  }

  String _fieldLabel(String key) {
    const labels = {
      'email': 'Email',
      'password': 'Password',
      'password2': 'Confirm password',
      'name': 'Name',
      'non_field_errors': 'Error',
      'detail': 'Error',
    };
    return labels[key] ?? key;
  }

  /// Convert raw exceptions into user-friendly messages
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('connection refused') ||
        msg.contains('socketexception') ||
        msg.contains('no host specified') ||
        msg.contains('network is unreachable')) {
      return 'Cannot reach the server.\n'
          'Please make sure the Django backend is running:\n'
          'python manage.py runserver';
    }
    if (msg.contains('handshake') || msg.contains('certificate')) {
      return 'SSL error – the backend should use http://, not https://.';
    }
    return 'Connection error. Please check your network.';
  }
}
