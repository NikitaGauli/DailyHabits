import 'dart:convert';

import 'package:dailyhabits/models/analytics_summary.dart';
import 'package:dailyhabits/services/analytics_service.dart';
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

  test('AnalyticsService.getWeeklyData parses points', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/analytics/weekly/'));
      expect(request.url.queryParameters['weeksBack'], '0');
      expect(request.headers['Authorization'], 'Bearer test.jwt');

      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'day': 'Mon',
              'date': '2024-01-01T00:00:00.000Z',
              'completed': 3,
              'total': 5,
              'rate': 0.6,
              'isToday': false,
            },
          ],
        }),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    final service = AnalyticsService(authService: auth, client: client);
    final points = await service.getWeeklyData();

    expect(points, hasLength(1));
    final WeeklyDataPoint p = points.first;
    expect(p.day, 'Mon');
    expect(p.completed, 3);
    expect(p.total, 5);
    expect(p.rate, closeTo(0.6, 0.0001));
  });

  test('AnalyticsService.getWeeklyData returns empty list on non-200', () async {
    final auth = AuthService.forTesting(
      store: _TestStore({'auth_token': 'test.jwt'}),
      prefsProvider: SharedPreferences.getInstance,
    );

    final client = MockClient((request) async {
      return http.Response('server error', 500);
    });

    final service = AnalyticsService(authService: auth, client: client);
    final points = await service.getWeeklyData();
    expect(points, isEmpty);
  });
}
