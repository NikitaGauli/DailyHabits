import 'dart:convert';

import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/notification_service.dart';
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

  test('NotificationService.getSmartSuggestions returns suggestions list',
      () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        contains('/api/notification-intelligence/smart-suggestions/'),
      );
      expect(request.headers['Authorization'], 'Bearer test.jwt');

      return http.Response(
        jsonEncode({
          'success': true,
          'suggestions': [
            {'habitId': 1, 'time': '08:00'}
          ]
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = NotificationService(authService: auth, client: client);
    final suggestions = await service.getSmartSuggestions();

    expect(suggestions, hasLength(1));
    expect((suggestions.first as Map)['habitId'], 1);
  });

  test('NotificationService.getStreakRiskAlerts reads backend alerts key',
      () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/notification-intelligence/streak-risks/'));

      return http.Response(
        jsonEncode({
          'success': true,
          'alerts': [
            {'habitId': 2, 'risk': 'high'}
          ]
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = NotificationService(authService: auth, client: client);
    final alerts = await service.getStreakRiskAlerts();

    expect(alerts, hasLength(1));
    expect((alerts.first as Map)['habitId'], 2);
  });
}
