// =============================================================================
// File: local_notification_service.dart
// Description: Local notification service for the DailyHabits Flutter client.
//              Uses flutter_local_notifications to display system-tray banners
//              when real-time WebSocket events arrive in the foreground.
//
// Architecture:
//   - WebSocket (Django Channels) handles real-time notification delivery.
//   - This service displays native OS notification banners when the app
//     receives a WebSocket event while in the foreground.
//   - Scheduled local notifications provide device-side habit reminders
//     even when the WebSocket is disconnected.
//   - No external push service (Firebase, OneSignal, etc.) is required.
//
// Usage:
//   Called once from [NotificationController.connectWebSocket]:
//     await LocalNotificationService.instance.initialize();
//
//   Show a notification from a WebSocket event:
//     LocalNotificationService.instance.showNotification(appNotification);
//
// Dependencies:
//   - flutter_local_notifications (^18.x)
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:dailyhabits/models/notification_model.dart';

// =============================================================================
// Local Notification Service
// =============================================================================

/// Singleton service that manages local notification display for the
/// DailyHabits app.
///
/// Works in tandem with the WebSocket real-time layer:
///   1. WebSocket delivers notification events from the server.
///   2. [NotificationController] calls [showNotification] to display a
///      native system notification banner.
///   3. User taps → [onNotificationTapped] callback fires for navigation.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance =
      LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback invoked when user taps a notification.
  /// The controller should set this to navigate to the relevant screen.
  void Function(AppNotification notification)? onNotificationTapped;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises the local notification plugin and creates notification
  /// channels.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip initialization on web — local notifications are not supported
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create a high-importance Android notification channel
    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'dailyhabits_default',
        'DailyHabits Notifications',
        description: 'Default notification channel for DailyHabits',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Habit reminders channel — for scheduled reminders
      const remindersChannel = AndroidNotificationChannel(
        'dailyhabits_reminders',
        'Habit Reminders',
        description: 'Scheduled habit reminder notifications',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(remindersChannel);
    }

    _isInitialized = true;
    debugPrint('[LocalNotif] Initialized successfully');
  }

  // ---------------------------------------------------------------------------
  // Show Notification
  // ---------------------------------------------------------------------------

  /// Displays a native system notification banner for a given
  /// [AppNotification] received via WebSocket.
  ///
  /// The notification payload is serialized into the tap payload so the
  /// [onNotificationTapped] callback can reconstruct the notification
  /// for navigation.
  Future<void> showNotification(AppNotification notification) async {
    if (kIsWeb || !_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'dailyhabits_default',
      'DailyHabits Notifications',
      channelDescription: 'Default notification channel for DailyHabits',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Encode notification data as JSON for the tap payload
    final payload = jsonEncode({
      'id': notification.id,
      'type': notification.type,
      'title': notification.title,
      'message': notification.message,
      'status': notification.status,
      'actionType': notification.actionType,
      'actionData': notification.actionData,
    });

    await _localNotifications.show(
      notification.id,
      notification.title,
      notification.message,
      details,
      payload: payload,
    );
  }

  /// Displays a simple notification with title and body text.
  ///
  /// Use this for lightweight alerts that don't originate from a full
  /// [AppNotification] (e.g., connection-state changes, one-off alerts).
  Future<void> showSimple({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'dailyhabits_default',
      'DailyHabits Notifications',
      channelDescription: 'Default notification channel for DailyHabits',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ---------------------------------------------------------------------------
  // Cancel Notifications
  // ---------------------------------------------------------------------------

  /// Cancels a specific notification by [id].
  Future<void> cancel(int id) async {
    if (kIsWeb || !_isInitialized) return;
    await _localNotifications.cancel(id);
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    if (kIsWeb || !_isInitialized) return;
    await _localNotifications.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Tap Handler
  // ---------------------------------------------------------------------------

  /// Handles a tap on a local notification displayed by this service.
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final notification = AppNotification.fromJson(data);
      onNotificationTapped?.call(notification);
    } catch (e) {
      debugPrint('[LocalNotif] Error parsing notification tap payload: $e');
    }
  }
}
