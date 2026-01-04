import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Platform-aware Base URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/auth';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Use 10.0.2.2 for Android Emulator, or local IP for physical device
      // Ideally this matches the network_security_config.xml
      // Returning the local IP you found earlier as it's safe for physical & emulator (usually)
      // But 10.0.2.2 is safer for emulator specifically if local IP changes.
      // Let's stick to the local IP for consistency with your recent success,
      // but strictly speaking 10.0.2.2 is the emulator standard.
      // If you are running on Emulator, use 10.0.2.2. If physical, use 192.168...
      return 'http://192.168.100.105:8000/api/auth';
    }
    return 'http://127.0.0.1:8000/api/auth';
  }

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Attempt to login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login successful
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        // Login failed
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Register a new user
  Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'password': password,
          'password2': password, // Required by backend serializer
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Registration successful
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        // Registration failed
        return {'success': false, 'message': _extractErrorMessage(data)};
      }
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Logout the user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Optional: Call backend logout endpoint if needed
    // String? token = prefs.getString(_tokenKey);
    // if (token != null) { ... }

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

  // Helper to save token and user data
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Adjust these keys based on your actual API response structure
    // Assuming structure like: { 'access': 'token...', 'user': { ... } }
    if (data.containsKey('access')) {
      await prefs.setString(_tokenKey, data['access']);
    } else if (data.containsKey('token')) {
      // Fallback if key is 'token'
      await prefs.setString(_tokenKey, data['token']);
    }

    if (data.containsKey('user')) {
      await prefs.setString(_userKey, jsonEncode(data['user']));
    }
  }

  // Helper to extract error message from DRF validation errors
  String _extractErrorMessage(dynamic data) {
    if (data is String) return data;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail')) return data['detail'];

      // If it's field errors, join them
      final messages = <String>[];
      data.forEach((key, value) {
        if (value is List) {
          messages.add('$key: ${value.join(", ")}');
        } else {
          messages.add('$key: $value');
        }
      });
      if (messages.isNotEmpty) return messages.join('\n');
    }

    return 'An unknown error occurred';
  }
}
