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

  test('HabitService.getHabits sends auth header and parses list', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/habits/'));
      expect(request.headers['Authorization'], 'Bearer test.jwt');

      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'title': 'Drink Water',
            'description': '8 cups a day',
            'time': '08:00',
            'categoryName': 'Health',
            'iconCode': 0xE87C,
            'colorValue': 0xFF4F46E5,
            'startDate': '2024-01-01T00:00:00.000Z'
          }
        ]),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = HabitService(authService: auth, client: client);
    final habits = await service.getHabits();

    expect(habits, hasLength(1));
    expect(habits.first.id, '1');
    expect(habits.first.title, 'Drink Water');
    expect(habits.first.category, 'Health');
  });
}
