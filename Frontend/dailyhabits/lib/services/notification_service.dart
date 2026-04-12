// =============================================================================
// File: notification_service.dart
// Description: Notification management service for the DailyHabits application.
//              Handles inbox notifications, smart tips, notification settings,
//              and AI-driven notification intelligence (smart suggestions,
//              streak risk alerts, weekly nudges).
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';
import 'package:dailyhabits/models/notification_model.dart';

// =============================================================================
// Notification Service
// =============================================================================

/// Comprehensive notification service covering four subsystems:
///
/// 1. **Inbox Notifications** — Standard read/unread notification management.
/// 2. **Smart Tips** — AI-curated tips with like, save, and dismiss actions.
/// 3. **Settings** — User-configurable notification preferences.
/// 4. **Notification Intelligence** — Proactive alerts including smart
///    suggestions, streak-risk warnings, and weekly performance nudges.
///
/// All requests are authenticated via JWT tokens from [AuthService].
class NotificationService {
  // ---------------------------------------------------------------------------
  // Dependencies & Configuration
  // ---------------------------------------------------------------------------

  NotificationService({AuthService? authService, http.Client? client})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  /// Shared [AuthService] instance for retrieving the JWT token.
  final AuthService _authService;

  final http.Client _client;

  /// Base URL for standard notification endpoints.
  String get _baseUrl => '${ApiConfig.baseUrl}/notifications';

  /// Base URL for notification preference settings.
  String get _settingsUrl => '${ApiConfig.baseUrl}/notification-settings';

  /// Base URL for AI-generated smart tips.
  String get _smartTipsUrl => '${ApiConfig.baseUrl}/smart-tips';

  /// Builds authenticated HTTP headers with JSON content type.
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  List<dynamic> _normalizeList(dynamic value) {
    if (value is List) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      final candidates = [value['results'], value['items'], value['data'], value['nudges']];
      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate;
        }
      }

      // Single-object fallback for endpoints that return one suggestion payload.
      if (value.isNotEmpty) {
        return [value];
      }
    }

    return const [];
  }

  // ---------------------------------------------------------------------------
  // Inbox Notifications
  // ---------------------------------------------------------------------------

  /// Fetches all notifications for the authenticated user.
  ///
  /// Returns a list of [AppNotification] objects ordered by date (newest first).
  /// Returns an empty list on failure.
  Future<List<AppNotification>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
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

  /// Returns the count of unread notifications.
  ///
  /// Used by badge indicators in the UI. Returns `0` on failure.
  Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
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

  /// Marks a single notification as read by its [id].
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> markAsRead(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_baseUrl/$id/mark-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Marks all notifications as read for the authenticated user.
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_baseUrl/mark-all-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Permanently deletes a notification by its [id].
  ///
  /// Accepts both HTTP 200 and 204 as successful responses.
  Future<bool> deleteNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$_baseUrl/$id/'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Dismisses a notification by its [id] without deleting it.
  ///
  /// Dismissed notifications are hidden from the inbox but retained on the
  /// server for analytics purposes.
  Future<bool> dismissNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_baseUrl/$id/dismiss/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Friend Request Actions (from notification)
  // ---------------------------------------------------------------------------

  /// Accepts a friend request directly from a notification.
  ///
  /// The backend finds the pending friendship associated with the
  /// notification's sender and accepts it.
  Future<bool> acceptFriendRequest(int notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_baseUrl/$notificationId/accept-friend/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Rejects a friend request directly from a notification.
  ///
  /// The backend finds the pending friendship associated with the
  /// notification's sender and rejects it.
  Future<bool> rejectFriendRequest(int notificationId) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_baseUrl/$notificationId/reject-friend/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Smart Tips
  // ---------------------------------------------------------------------------

  /// Fetches the full smart tips payload including intelligence metadata.
  ///
  /// Returns the raw response map containing tips, patterns, and contextual
  /// data. Returns an empty map on failure.
  Future<Map<String, dynamic>> getSmartTipsData() async {
    try {
      final headers = await _getHeaders();
      final responses = await Future.wait([
        _client.get(
          Uri.parse('$_smartTipsUrl/'),
          headers: headers,
        ),
        _client.get(
          Uri.parse('$_intelligenceUrl/streak-risks/'),
          headers: headers,
        ),
        _client.get(
          Uri.parse('$_intelligenceUrl/smart-suggestions/'),
          headers: headers,
        ),
        _client.get(
          Uri.parse('$_intelligenceUrl/weekly-nudges/'),
          headers: headers,
        ),
      ]);

      final tipsRes = responses[0];
      final risksRes = responses[1];
      final suggestionsRes = responses[2];
      final nudgesRes = responses[3];

      final tipsData =
          tipsRes.statusCode == 200 ? _decodeMap(tipsRes.body) : <String, dynamic>{};
      final risksData =
          risksRes.statusCode == 200 ? _decodeMap(risksRes.body) : <String, dynamic>{};
      final suggestionsData = suggestionsRes.statusCode == 200
          ? _decodeMap(suggestionsRes.body)
          : <String, dynamic>{};
      final nudgesData =
          nudgesRes.statusCode == 200 ? _decodeMap(nudgesRes.body) : <String, dynamic>{};

      return {
        'success': true,
        'tips': _normalizeList(tipsData['tips']),
        'streakRisks': _normalizeList(risksData['alerts']),
        'suggestions': _normalizeList(suggestionsData['suggestions']),
        'nudges': _normalizeList(nudgesData['nudges']),
        'rawWeeklyNudges': nudgesData,
      };
    } catch (e) {
      return {};
    }
  }

  /// Fetches the list of AI-generated smart tips as [SmartTip] objects.
  ///
  /// Returns an empty list on failure.
  Future<List<SmartTip>> getSmartTips() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
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

  /// Marks a smart tip as read by its [id].
  Future<bool> markTipRead(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_smartTipsUrl/$id/mark-read/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggles the “liked” state on a smart tip identified by [id].
  Future<bool> toggleTipLike(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_smartTipsUrl/$id/like/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggles the “saved” (bookmarked) state on a smart tip identified by [id].
  Future<bool> toggleTipSave(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_smartTipsUrl/$id/save-tip/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dismisses a smart tip by its [id], removing it from the active list.
  Future<bool> dismissTip(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_smartTipsUrl/$id/dismiss/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Notification Settings
  // ---------------------------------------------------------------------------

  /// Retrieves the user’s notification preferences.
  ///
  /// Returns a [NotificationSettings] object, or `null` if the request fails
  /// or no settings have been configured yet.
  Future<NotificationSettings?> getSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
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

  /// Persists the user’s updated notification [settings] to the backend.
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> updateSettings(NotificationSettings settings) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$_settingsUrl/update/'),
        headers: headers,
        body: jsonEncode(settings.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Notification Intelligence
  // ---------------------------------------------------------------------------

  /// Base URL for the AI-driven notification intelligence subsystem.
  String get _intelligenceUrl =>
      '${ApiConfig.baseUrl}/notification-intelligence';

  /// Fetches AI-generated smart reminder suggestions.
  ///
  /// Suggestions are based on the user’s habit patterns, optimal completion
  /// times, and historical engagement data. Returns an empty list on failure.
  Future<List<dynamic>> getSmartSuggestions() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$_intelligenceUrl/smart-suggestions/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = _decodeMap(response.body);
        return _normalizeList(data['suggestions']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetches habits that are at risk of losing their streak.
  ///
  /// Returns a list of at-risk habit entries with streak details and urgency
  /// levels. Returns an empty list on failure.
  Future<List<dynamic>> getStreakRiskAlerts() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$_intelligenceUrl/streak-risks/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = _decodeMap(response.body);
        return _normalizeList(data['alerts']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Retrieves weekly performance nudges based on the user’s recent activity.
  ///
  /// Nudges include encouragement for improving habits, celebrating progress,
  /// and corrective guidance. Returns an empty map on failure.
  Future<Map<String, dynamic>> getWeeklyNudges() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$_intelligenceUrl/weekly-nudges/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return _decodeMap(response.body);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetches a high-level summary of notification activity and engagement.
  ///
  /// Includes counts of read/unread notifications, tip interactions, and
  /// delivery statistics. Returns an empty map on failure.
  Future<Map<String, dynamic>> getNotificationSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$_intelligenceUrl/summary/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return _decodeMap(response.body);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

}
