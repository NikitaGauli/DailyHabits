import 'dart:convert';

import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/habit_service.dart';
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

  test('HabitService.toggleHabit POSTs to toggle-complete and parses JSON',
      () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, contains('/api/habits/123/toggle-complete/'));
      expect(request.headers['Authorization'], 'Bearer test.jwt');

      return http.Response(
        jsonEncode({'success': true, 'isCompleted': true}),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = HabitService(authService: auth, client: client);
    final data = await service.toggleHabit('123');

    expect(data['success'], true);
    expect(data['isCompleted'], true);
  });

  test('HabitService.skipHabit POSTs reason and returns true on 200', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, contains('/api/habits/5/skip/'));
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['reason'], 'sick');

      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = HabitService(authService: auth, client: client);
    final ok = await service.skipHabit('5', reason: 'sick');
    expect(ok, true);
  });
}
