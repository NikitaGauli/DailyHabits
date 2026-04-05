import 'dart:convert';

import 'package:dailyhabits/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestStore implements AuthKeyValueStore {
  _TestStore([Map<String, String?>? initial]) : _values = {...?initial};

  final Map<String, String?> _values;

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    _values[key] = value;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AuthService.login stores access token and user', () async {
    final store = _TestStore();

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, contains('/api/auth/login/'));
      expect(request.headers['Content-Type'], 'application/json');

      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['email'], 'test@example.com');
      expect(payload['password'], 'pw');

      return http.Response(
        jsonEncode({
          'access': 'access.jwt',
          'refresh': 'refresh.jwt',
          'user': {'id': 1, 'email': 'test@example.com', 'name': 'Test User'},
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = AuthService.forTesting(
      client: client,
      store: store,
      prefsProvider: SharedPreferences.getInstance,
    );

    final result = await service.login('test@example.com', 'pw');
    expect(result['success'], true);

    final token = await service.getToken();
    expect(token, 'access.jwt');

    final user = await service.getUser();
    expect(user?['email'], 'test@example.com');
    expect(user?['name'], 'Test User');
  });

  test('AuthService.register returns field error messages on failure', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, contains('/api/auth/register/'));
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Invalid data',
          'errors': {
            'email': ['This field is required.'],
          },
        }),
        400,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = AuthService.forTesting(
      client: client,
      store: _TestStore(),
      prefsProvider: SharedPreferences.getInstance,
    );

    final result = await service.register('', 'Name', 'pw');
    expect(result['success'], false);
    expect((result['message'] as String).toLowerCase(), contains('email'));
  });

  test('AuthService.forgotPassword passes through debug fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, contains('/api/auth/forgot-password/'));
      return http.Response(
        jsonEncode({
          'message': 'If the email exists, a reset link has been sent.',
          'debug_reset_token': 'debug-token-123',
          'email_delivered': false,
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = AuthService.forTesting(
      client: client,
      store: _TestStore(),
      prefsProvider: SharedPreferences.getInstance,
    );

    final result = await service.forgotPassword('Test@Example.com');
    expect(result['success'], true);
    expect(result['debug_reset_token'], 'debug-token-123');
    expect(result['email_delivered'], false);
  });
}
