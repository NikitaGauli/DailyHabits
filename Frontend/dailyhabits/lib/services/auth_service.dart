// =============================================================================
// File: auth_service.dart
// Description: Authentication service for the DailyHabits application.
//              Handles user login, registration, Google OAuth, logout, and
//              secure token storage via FlutterSecureStorage. Communicates
//              with the Django REST Framework authentication endpoints.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dailyhabits/services/api_config.dart';

// =============================================================================
// Testable Storage Abstraction
// =============================================================================

/// Minimal key/value storage used by [AuthService] for persisting auth data.
///
/// In production, this is backed by [FlutterSecureStorage]. In unit tests,
/// it can be replaced with an in-memory implementation.
abstract class AuthKeyValueStore {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureAuthStore implements AuthKeyValueStore {
  FlutterSecureAuthStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String? value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

// =============================================================================
// Authentication Service
// =============================================================================

/// Singleton service responsible for all authentication-related operations.
///
/// Provides methods for:
/// - **Login** — Authenticates an existing user with email/password credentials.
/// - **Registration** — Creates a new user account and stores the returned token.
/// - **Google Login** — Sends a Google ID token to the backend for verification.
/// - **Logout** — Clears locally stored authentication tokens and user data.
/// - **Session management** — Checks login state and retrieves stored tokens.
///
/// Tokens are persisted in [FlutterSecureStorage] (encrypted keychain on iOS,
/// EncryptedSharedPreferences on Android) for maximum security.
/// All network calls target the `/api/auth/` Django REST endpoint group.
class AuthService {
  // ---------------------------------------------------------------------------
  // Constants & Singleton
  // ---------------------------------------------------------------------------

  /// Base URL for all authentication endpoints, derived from [ApiConfig].
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

  /// [FlutterSecureStorage] key for the JWT access token.
  static const String _tokenKey = 'auth_token';

  /// [FlutterSecureStorage] key for the serialized user JSON object.
  static const String _userKey = 'user_data';

  /// [FlutterSecureStorage] key for the JWT refresh token.
  static const String _refreshKey = 'refresh_token';

  /// Flag key to track whether migration from SharedPreferences has occurred.
  static const String _migrationKey = 'secure_storage_migrated';

  /// Singleton instance — ensures a single [AuthService] across the app.
  static final AuthService _instance = AuthService._internal();

  /// Factory constructor returns the shared singleton instance.
  factory AuthService() => _instance;

  /// Private named constructor used by the singleton pattern.
  AuthService._internal({http.Client? client, AuthKeyValueStore? store})
      : _client = client ?? http.Client(),
        _store =
            store ??
            FlutterSecureAuthStore(
              const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
              ),
            ),
        _prefsProvider = SharedPreferences.getInstance;

  /// Test-only constructor that allows injecting dependencies.
  @visibleForTesting
  AuthService.forTesting({
    http.Client? client,
    AuthKeyValueStore? store,
    Future<SharedPreferences> Function()? prefsProvider,
  })  : _client = client ?? http.Client(),
        _store = store ?? _InMemoryAuthStore(),
        _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  final http.Client _client;
  final AuthKeyValueStore _store;
  final Future<SharedPreferences> Function() _prefsProvider;

  // ---------------------------------------------------------------------------
  // Public API — Authentication
  // ---------------------------------------------------------------------------

  /// Authenticates an existing user with their [email] and [password].
  ///
  /// Sends a `POST` request to `/auth/login/`. On success the JWT token and
  /// user profile are persisted locally via [_saveAuthData].
  ///
  /// Returns a map with:
  /// - `success: true` and `data` on successful login.
  /// - `success: false` and a human-readable `message` on failure.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$baseUrl/login/';
    debugPrint('AUTH ➜ POST $url');
    try {
      final response = await _client
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

  /// Registers a new user account.
  ///
  /// Sends a `POST` request to `/auth/register/` with the user's [email],
  /// display [name], and [password]. The backend expects `password2` to match
  /// `password` for confirmation.
  ///
  /// Returns a map with:
  /// - `success: true` and `data` on successful registration (HTTP 201).
  /// - `success: false` and a human-readable `message` on failure.
  Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
  ) async {
    final url = '$baseUrl/register/';
    debugPrint('AUTH ➜ POST $url');
    try {
      final response = await _client
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

  /// Authenticates a user via Google OAuth by sending their [idToken],
  /// [email], and [name] to the Django backend for server-side verification.
  ///
  /// Sends a `POST` request to `/auth/google/` with:
  /// ```json
  /// { "id_token": "...", "email": "...", "name": "..." }
  /// ```
  ///
  /// The backend verifies the token against Google's public keys, creates
  /// or retrieves the user, and returns JWT tokens.
  ///
  /// **Privacy:** Only email and name are sent. No avatar/photo URL is
  /// included in the request payload.
  ///
  /// Returns a map with:
  /// - `success: true` and `data` on successful Google authentication.
  /// - `success: false` and a human-readable `message` on failure.
  ///
  /// Security:
  /// - The ID token is verified server-side, never trusted on client alone.
  /// - JWT tokens are stored in encrypted secure storage.
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String email,
    required String name,
  }) async {
    final url = '$baseUrl/google/';
    debugPrint('AUTH ➜ POST $url (Google OAuth)');
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'email': email,
              'name': name,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Google authentication failed.',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Server is not responding. Make sure the backend is running.',
      };
    } catch (e) {
      debugPrint('GOOGLE AUTH ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // Public API — Session Management
  // ---------------------------------------------------------------------------

  /// Logs the user out by clearing all persisted authentication data.
  ///
  /// Removes the JWT token, refresh token, and cached user profile from
  /// [FlutterSecureStorage]. Does **not** call the backend — the token simply
  /// becomes unused on the client side.
  Future<void> logout() async {
    await _store.delete(key: _tokenKey);
    await _store.delete(key: _userKey);
    await _store.delete(key: _refreshKey);
  }

  // ---------------------------------------------------------------------------
  // Password Reset
  // ---------------------------------------------------------------------------

  /// Requests a password-reset email for the given [email].
  ///
  /// The backend always returns a generic success message regardless of
  /// whether the email exists, preventing user enumeration.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/forgot-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final result = <String, dynamic>{
          'success': true,
          'message': data['message'] ?? 'Check your email for reset instructions.',
        };
        // Pass through debug fields (only present when backend DEBUG=True)
        if (data['debug_reset_token'] != null) {
          result['debug_reset_token'] = data['debug_reset_token'];
        }
        if (data['email_delivered'] != null) {
          result['email_delivered'] = data['email_delivered'];
        }
        return result;
      }
      return {'success': false, 'message': _extractErrorMessage(data)};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Validates a password-reset [token] before showing the reset form.
  ///
  /// Returns `{valid: true}` when the token is still usable, or
  /// `{valid: false, message: '…'}` when it has expired or been consumed.
  Future<Map<String, dynamic>> validateResetToken(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/validate-reset-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['valid'] == true) {
        return {'valid': true};
      }
      return {'valid': false, 'message': data['message'] ?? 'Invalid or expired token.'};
    } catch (e) {
      return {'valid': false, 'message': _friendlyError(e)};
    }
  }

  /// Resets the password using the one-time [token].
  ///
  /// On success the backend invalidates all existing JWT sessions, forcing
  /// re-authentication on every device.
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/reset-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Password reset successfully.'};
      }
      return {'success': false, 'message': _extractErrorMessage(data)};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ---------------------------------------------------------------------------
  // OTP-Based Password Reset
  // ---------------------------------------------------------------------------

  /// Requests a 6-digit OTP for password reset.
  ///
  /// The backend always returns a generic success message regardless of
  /// whether the email exists, preventing user enumeration.
  Future<Map<String, dynamic>> requestPasswordResetOTP(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/request-password-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final result = <String, dynamic>{
          'success': true,
          'message': data['message'] ?? 'Check your email for the OTP.',
          'otp_ttl_seconds': data['otp_ttl_seconds'] ?? 600,
        };
        // Pass through debug fields (only present when backend DEBUG=True)
        if (data['debug_otp'] != null) {
          result['debug_otp'] = data['debug_otp'];
        }
        if (data['debug_note'] != null) {
          result['debug_note'] = data['debug_note'];
        }
        return result;
      }
      return {'success': false, 'message': _extractErrorMessage(data)};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Verifies the 6-digit OTP and sets a new password.
  ///
  /// On success the backend invalidates all existing JWT sessions, forcing
  /// re-authentication on every device.
  Future<Map<String, dynamic>> verifyOTPAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/verify-otp-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successfully.',
        };
      }
      return {
        'success': false,
        'message': _extractErrorMessage(data),
        'attempts_remaining': data['attempts_remaining'],
      };
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Retrieves the stored JWT access token, or `null` if not logged in.
  ///
  /// Performs a one-time migration from [SharedPreferences] to
  /// [FlutterSecureStorage] on first call after app update.
  Future<String?> getToken() async {
    await _migrateFromSharedPrefs();
    return await _store.read(key: _tokenKey);
  }

  /// Returns `true` if a JWT token exists in secure storage.
  ///
  /// Note: This does **not** verify token validity with the backend.
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Retrieves the cached user profile as a JSON map, or `null` if absent.
  Future<Map<String, dynamic>?> getUser() async {
    await _migrateFromSharedPrefs();
    final userStr = await _store.read(key: _userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Storage
  // ---------------------------------------------------------------------------

  /// One-time migration of auth tokens from [SharedPreferences] to
  /// [FlutterSecureStorage].
  ///
  /// This ensures that users who previously had tokens stored in plain-text
  /// SharedPreferences are seamlessly migrated to encrypted storage on the
  /// first app launch after the update. The migration flag prevents
  /// re-running on subsequent launches.
  Future<void> _migrateFromSharedPrefs() async {
    final alreadyMigrated = await _store.read(key: _migrationKey);
    if (alreadyMigrated == 'true') return;

    try {
      final prefs = await _prefsProvider();
      final oldToken = prefs.getString('auth_token');
      final oldUser = prefs.getString('user_data');

      if (oldToken != null) {
        await _store.write(key: _tokenKey, value: oldToken);
        await prefs.remove('auth_token');
      }
      if (oldUser != null) {
        await _store.write(key: _userKey, value: oldUser);
        await prefs.remove('user_data');
      }
    } catch (e) {
      debugPrint('AUTH ➜ Migration warning (non-fatal): $e');
    }

    // Mark migration as done regardless — prevents retries on failure
    await _store.write(key: _migrationKey, value: 'true');
  }

  /// Persists the JWT tokens and user profile from an API [data] response.
  ///
  /// Supports multiple token key formats returned by the backend:
  /// - `access` — standard JWT pair response (preferred, from Google auth).
  /// - `token`  — legacy single-token response (from email/password auth).
  /// - `refresh` — refresh token for token rotation.
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    // Backend may return the token under 'access' (JWT pair) or 'token' (legacy)
    if (data.containsKey('access')) {
      await _store.write(key: _tokenKey, value: data['access']?.toString());
    } else if (data.containsKey('token')) {
      await _store.write(key: _tokenKey, value: data['token']?.toString());
    }

    // Store refresh token if present
    if (data.containsKey('refresh')) {
      await _store.write(key: _refreshKey, value: data['refresh']?.toString());
    }

    if (data.containsKey('user')) {
      await _store.write(key: _userKey, value: jsonEncode(data['user']));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Error Handling
  // ---------------------------------------------------------------------------

  /// Extracts a human-readable error message from a DRF error [data] payload.
  ///
  /// Handles multiple response shapes:
  /// 1. Nested `errors` map with field-level arrays (DRF serializer errors).
  /// 2. Top-level `detail` or `message` string.
  /// 3. Flat field-level errors at the root of the JSON object.
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
      if (data.containsKey('message') &&
          data['message'] != 'Registration failed' &&
          data['message'] != 'Invalid data') {
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

  /// Maps raw DRF field keys to user-friendly display labels.
  String _fieldLabel(String key) {
    const labels = {
      'email': 'Email',
      'password': 'Password',
      'password2': 'Confirm password',
      'name': 'Name',
      'non_field_errors': 'Error',
      'detail': 'Error',
      'id_token': 'Google token',
    };
    return labels[key] ?? key;
  }

  /// Converts raw Dart/HTTP exceptions into user-friendly error messages.
  ///
  /// Detects common failure categories:
  /// - **Network unreachable / connection refused** — prompts the user to
  ///   verify that the Django development server is running.
  /// - **SSL / certificate errors** — suggests switching to plain HTTP.
  /// - **Other** — returns a generic connectivity message.
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

class _InMemoryAuthStore implements AuthKeyValueStore {
  final Map<String, String?> _values = <String, String?>{};

  @override
  Future<void> write({required String key, required String? value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
