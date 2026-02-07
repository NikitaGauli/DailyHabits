import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/notification_model.dart';

class NotificationService {
  final AuthService _authService = AuthService();

  String get _baseUrl => '${ApiConfig.baseUrl}/notifications';
  String get _settingsUrl => '${ApiConfig.baseUrl}/notification-settings';
  String get _smartTipsUrl => '${ApiConfig.baseUrl}/smart-tips';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Inbox Notifications ──────────────────────────────────────

  /// Get notifications
  Future<List<AppNotification>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['notifications'] as List)
              .map((json) => AppNotification.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/unread/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mark as read
  Future<bool> markAsRead(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/$id/mark-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Mark all as read
  Future<bool> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/mark-all-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id/'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Dismiss notification
  Future<bool> dismissNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/$id/dismiss/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Smart Tips ───────────────────────────────────────────────

  /// Get smart tips
  Future<List<SmartTip>> getSmartTips() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_smartTipsUrl/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['tips'] as List)
              .map((json) => SmartTip.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Mark smart tip as read
  Future<bool> markTipRead(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_smartTipsUrl/$id/mark-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggle like on smart tip
  Future<bool> toggleTipLike(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_smartTipsUrl/$id/like/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggle save on smart tip
  Future<bool> toggleTipSave(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_smartTipsUrl/$id/save-tip/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dismiss smart tip
  Future<bool> dismissTip(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_smartTipsUrl/$id/dismiss/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Settings ─────────────────────────────────────────────────

  /// Get settings
  Future<NotificationSettings?> getSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_settingsUrl/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return NotificationSettings.fromJson(data['settings']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update settings
  Future<bool> updateSettings(NotificationSettings settings) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_settingsUrl/update/'),
        headers: headers,
        body: jsonEncode(settings.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Notification Intelligence ────────────────────────────────

  String get _intelligenceUrl =>
      '${ApiConfig.baseUrl}/notification-intelligence';

  /// Get smart reminder suggestions
  Future<List<dynamic>> getSmartSuggestions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_intelligenceUrl/smart-suggestions/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['suggestions'] ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get streak risk alerts
  Future<List<dynamic>> getStreakRiskAlerts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_intelligenceUrl/streak-risks/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['at_risk_habits'] ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get weekly performance nudges
  Future<Map<String, dynamic>> getWeeklyNudges() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_intelligenceUrl/weekly-nudges/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Get notification summary
  Future<Map<String, dynamic>> getNotificationSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_intelligenceUrl/summary/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
