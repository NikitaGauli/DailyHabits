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

  test('NotificationService.getUnreadCount returns unreadCount', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/notifications/unread/'));
      expect(request.headers['Authorization'], 'Bearer test.jwt');

      return http.Response(
        jsonEncode({'unreadCount': 7}),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = NotificationService(authService: auth, client: client);
    final count = await service.getUnreadCount();
    expect(count, 7);
  });

  test('NotificationService.getNotifications parses list', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/notifications/'));

      return http.Response(
        jsonEncode({
          'success': true,
          'notifications': [
            {
              'id': 1,
              'type': 'reminder',
              'title': 'Hydrate',
              'message': 'Drink a glass of water',
              'status': 'unread',
              'scheduledTime': '2024-01-01T10:00:00.000Z',
              'iconCode': 0xE7F4,
              'colorValue': 0xFF6366F1,
              'actionType': 'none',
              'actionData': {},
            }
          ]
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = NotificationService(authService: auth, client: client);
    final notifications = await service.getNotifications();

    expect(notifications, hasLength(1));
    expect(notifications.first.id, 1);
    expect(notifications.first.title, 'Hydrate');
    expect(notifications.first.isRead, false);
  });

  test('NotificationService.getUnreadCount returns 0 on exception', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      throw Exception('network');
    });

    final service = NotificationService(authService: auth, client: client);
    expect(await service.getUnreadCount(), 0);
  });
}
