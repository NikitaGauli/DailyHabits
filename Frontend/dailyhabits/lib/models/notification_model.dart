// ==========================================================================
// Notification Models — Alerts, Smart Tips & Notification Preferences
// ==========================================================================
//
// This file defines the data models for the notification subsystem:
//
// - [AppNotification] — A single notification (reminder, social event, or
//   system alert) with deep-link action metadata.
// - [SmartTip] — An AI-generated contextual tip tied to a specific habit.
// - [NotificationSettings] — User preferences controlling which
//   notification types are enabled and quiet-hours configuration.
//
// All models support JSON deserialization from the backend API and provide
// `copyWith` methods for immutable state updates in providers.
// ==========================================================================

import 'package:flutter/material.dart';

// ==========================================================================
// App Notification Model
// ==========================================================================

/// Represents a single notification dispatched to the user.
///
/// Notifications can originate from habit reminders, achievement unlocks,
/// social interactions, or system events. The [actionType] and [actionData]
/// fields enable deep-linking so tapping a notification navigates the user
/// to the relevant screen.
///
/// Social notifications additionally carry [fromUserId], [fromUserName],
/// [groupId], etc., to provide rich context in the notification card.
class AppNotification {
  /// Unique identifier for this notification.
  final int id;

  /// Notification type — e.g., `"reminder"`, `"achievement"`, `"friend_request"`.
  final String type;

  /// Short headline displayed in the notification card.
  final String title;

  /// Detailed body text of the notification.
  final String message;

  /// Read / unread / pending status string.
  final String status;

  /// When the notification is (or was) scheduled to fire.
  final DateTime scheduledTime;

  /// Actual send timestamp, or `null` if still pending.
  final DateTime? sentAt;

  /// Material icon displayed in the notification card.
  final IconData icon;

  /// Accent color used for the notification indicator.
  final Color color;

  /// Optional related habit ID for contextual navigation.
  final int? habitId;

  // ---- Social / deep-link fields ----

  /// Machine-readable action type for deep-linking (e.g., `"open_habit"`).
  final String actionType;

  /// Additional key-value data required by the action handler.
  final Map<String, dynamic> actionData;

  /// User ID of the sender (social notifications).
  final int? fromUserId;

  /// Display name of the sending user.
  final String? fromUserName;

  /// Profile image URL of the sending user.
  final String? fromUserImage;

  /// Group ID for group-related notifications.
  final int? groupId;

  /// Group name for group-related notifications.
  final String? groupName;

  /// Title of the related habit (used in social challenge notifications).
  final String? habitTitle;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.status,
    required this.scheduledTime,
    this.sentAt,
    required this.icon,
    required this.color,
    this.habitId,
    this.actionType = 'none',
    this.actionData = const {},
    this.fromUserId,
    this.fromUserName,
    this.fromUserImage,
    this.groupId,
    this.groupName,
    this.habitTitle,
  });

  /// Deserializes an [AppNotification] from a JSON map returned by the API.
  ///
  /// Handles missing or null fields defensively, defaulting [type] to
  /// `"system"`, [status] to `"pending"`, and [actionData] to an empty map.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'] ?? 'system',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'pending',
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'])
          : DateTime.now(),
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      icon: IconData(json['iconCode'] ?? 0xE7F4, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFF6366F1),
      habitId: json['habitId'],
      actionType: json['actionType'] ?? 'none',
      actionData: json['actionData'] is Map
          ? Map<String, dynamic>.from(json['actionData'])
          : {},
      fromUserId: json['fromUserId'],
      fromUserName: json['fromUserName'],
      fromUserImage: json['fromUserImage'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      habitTitle: json['habitTitle'],
    );
  }

  /// Whether this notification has been read by the user.
  bool get isRead => status == 'read';

  /// Whether this notification originated from a social interaction.
  ///
  /// Checks against a known set of social notification types to determine
  /// if the notification should be displayed in the social feed.
  bool get isSocial =>
      const ['friend_request', 'friend_accepted', 'group_join', 'group_approval',
        'group_challenge', 'social_like', 'social_comment'].contains(type);

  /// Effective creation timestamp — prefers [sentAt], falls back to [scheduledTime].
  DateTime get createdAt => sentAt ?? scheduledTime;

  /// Returns a copy of this notification with the given fields replaced.
  ///
  /// When [isRead] is `true`, the [status] is automatically set to `"read"`,
  /// simplifying read-state toggling from the UI.
  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? message,
    String? status,
    DateTime? scheduledTime,
    DateTime? sentAt,
    IconData? icon,
    Color? color,
    int? habitId,
    bool? isRead,
    String? actionType,
    Map<String, dynamic>? actionData,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      status: isRead == true ? 'read' : (status ?? this.status),
      scheduledTime: scheduledTime ?? this.scheduledTime,
      sentAt: sentAt ?? this.sentAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      habitId: habitId ?? this.habitId,
      actionType: actionType ?? this.actionType,
      actionData: actionData ?? this.actionData,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      fromUserImage: fromUserImage,
      groupId: groupId,
      groupName: groupName,
      habitTitle: habitTitle,
    );
  }
}

// ==========================================================================
// Smart Tip Model
// ==========================================================================

/// An AI-generated contextual tip related to a user’s habit performance.
///
/// Smart tips are surfaced in the notifications tab and can be liked, saved,
/// or dismissed. Each tip is optionally linked to a [habitId] and carries
/// interaction flags ([isRead], [isLiked], [isSaved], [isDismissed]) for
/// state management.
class SmartTip {
  /// Unique identifier for this tip.
  final int id;

  /// Tip category — e.g., `"streak"`, `"consistency"`, `"general"`.
  final String tipType;

  /// Short headline of the tip.
  final String title;

  /// Full tip message body.
  final String message;

  /// Material icon for the tip card.
  final IconData icon;

  /// Accent color for the tip card.
  final Color color;

  /// Optional ID of the related habit.
  final int? habitId;

  /// Optional title of the related habit.
  final String? habitTitle;

  /// Whether the user has viewed this tip.
  final bool isRead;

  /// Whether the user has liked this tip.
  final bool isLiked;

  /// Whether the user has saved this tip for later.
  final bool isSaved;

  /// Whether the user has dismissed this tip.
  final bool isDismissed;

  /// Timestamp when the tip was generated.
  final DateTime createdAt;

  SmartTip({
    required this.id,
    required this.tipType,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.habitId,
    this.habitTitle,
    this.isRead = false,
    this.isLiked = false,
    this.isSaved = false,
    this.isDismissed = false,
    required this.createdAt,
  });

  /// Deserializes a [SmartTip] from a JSON map.
  ///
  /// The backend may provide the category under either `"category"` or
  /// `"tipType"` keys; both are handled with preference for `"category"`.
  factory SmartTip.fromJson(Map<String, dynamic> json) {
    return SmartTip(
      id: json['id'] ?? 0,
      tipType: json['category'] ?? json['tipType'] ?? 'general',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      icon: IconData(json['iconCode'] ?? 0xE3AF, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFF14B8A6),
      habitId: json['habitId'],
      habitTitle: json['habitTitle'],
      isRead: json['isRead'] ?? false,
      isLiked: json['isLiked'] ?? false,
      isSaved: json['isSaved'] ?? false,
      isDismissed: json['isDismissed'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Returns a copy of this [SmartTip] with the given interaction flags replaced.
  SmartTip copyWith({
    bool? isRead,
    bool? isLiked,
    bool? isSaved,
    bool? isDismissed,
  }) {
    return SmartTip(
      id: id,
      tipType: tipType,
      title: title,
      message: message,
      icon: icon,
      color: color,
      habitId: habitId,
      habitTitle: habitTitle,
      isRead: isRead ?? this.isRead,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isDismissed: isDismissed ?? this.isDismissed,
      createdAt: createdAt,
    );
  }
}

// ==========================================================================
// Notification Settings Model
// ==========================================================================

/// User preferences controlling notification delivery.
///
/// Encapsulates toggles for each notification category (reminders,
/// achievements, streaks, insights, quotes) and optional quiet-hours
/// scheduling to suppress notifications during specified time windows.
class NotificationSettings {
  /// Master toggle — when `false`, all notifications are suppressed.
  final bool notificationsEnabled;

  /// Whether habit reminder notifications are delivered.
  final bool habitReminders;

  /// Whether achievement unlock notifications are delivered.
  final bool achievementNotifications;

  /// Whether streak milestone alerts are delivered.
  final bool streakAlerts;

  /// Whether insight notifications are delivered.
  final bool insightNotifications;

  /// Whether daily motivational quote notifications are delivered.
  final bool motivationalQuotes;

  /// Whether quiet hours are active.
  final bool quietHoursEnabled;

  /// Start of the quiet-hours window (notifications muted).
  final TimeOfDay? quietHoursStart;

  /// End of the quiet-hours window (notifications resume).
  final TimeOfDay? quietHoursEnd;

  /// Whether reminders are allowed on Saturdays/Sundays.
  final bool weekendRemindersEnabled;

  /// Optional reminder delivery window start.
  final TimeOfDay? reminderWindowStart;

  /// Optional reminder delivery window end.
  final TimeOfDay? reminderWindowEnd;

  /// Delivery style: instant or digest.
  final String deliveryMode;

  /// Preferred digest delivery time when delivery mode is digest.
  final TimeOfDay? digestTime;

  /// Minimum minutes between notifications.
  final int cooldownMinutes;

  /// IANA timezone identifier used by backend scheduling.
  final String timezone;

  NotificationSettings({
    required this.notificationsEnabled,
    required this.habitReminders,
    required this.achievementNotifications,
    required this.streakAlerts,
    required this.insightNotifications,
    required this.motivationalQuotes,
    required this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.weekendRemindersEnabled = true,
    this.reminderWindowStart,
    this.reminderWindowEnd,
    this.deliveryMode = 'instant',
    this.digestTime,
    this.cooldownMinutes = 30,
    this.timezone = 'UTC',
  });

  /// Deserializes [NotificationSettings] from a JSON map.
  ///
  /// All toggles default to `true` (enabled) except [quietHoursEnabled]
  /// which defaults to `false`, matching the expected first-launch behavior.
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      habitReminders: json['habitReminders'] ?? true,
      achievementNotifications: json['achievementNotifications'] ?? true,
      streakAlerts: json['streakAlerts'] ?? true,
      insightNotifications: json['insightNotifications'] ?? true,
      motivationalQuotes: json['motivationalQuotes'] ?? true,
      quietHoursEnabled: json['quietHoursEnabled'] ?? false,
      quietHoursStart: json['quietHoursStart'] != null
          ? _parseTime(json['quietHoursStart'])
          : null,
      quietHoursEnd: json['quietHoursEnd'] != null
          ? _parseTime(json['quietHoursEnd'])
          : null,
        weekendRemindersEnabled: json['weekendRemindersEnabled'] ?? true,
        reminderWindowStart: json['reminderWindowStart'] != null
          ? _parseTime(json['reminderWindowStart'])
          : null,
        reminderWindowEnd: json['reminderWindowEnd'] != null
          ? _parseTime(json['reminderWindowEnd'])
          : null,
        deliveryMode: json['deliveryMode'] ?? 'instant',
        digestTime: json['digestTime'] != null
          ? _parseTime(json['digestTime'])
          : null,
        cooldownMinutes: (json['cooldownMinutes'] ?? 30) is int
          ? json['cooldownMinutes']
          : int.tryParse('${json['cooldownMinutes']}') ?? 30,
        timezone: json['timezone'] ?? 'UTC',
    );
  }

  /// Parses a time string in `"HH:mm"` format into a [TimeOfDay].
  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  /// Serializes the settings to a JSON-compatible map for API requests.
  ///
  /// Quiet-hours times are formatted as `"H:m"` strings, or `null` when
  /// not configured.
  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'habitReminders': habitReminders,
      'achievementNotifications': achievementNotifications,
      'streakAlerts': streakAlerts,
      'insightNotifications': insightNotifications,
      'motivationalQuotes': motivationalQuotes,
      'quietHoursEnabled': quietHoursEnabled,
        'quietHoursStart': _formatTime(quietHoursStart),
        'quietHoursEnd': _formatTime(quietHoursEnd),
        'weekendRemindersEnabled': weekendRemindersEnabled,
        'reminderWindowStart': _formatTime(reminderWindowStart),
        'reminderWindowEnd': _formatTime(reminderWindowEnd),
        'deliveryMode': deliveryMode,
        'digestTime': _formatTime(digestTime),
        'cooldownMinutes': cooldownMinutes,
        'timezone': timezone,
    };
  }

  /// Returns a copy of these settings with the given fields replaced.
  NotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? habitReminders,
    bool? achievementNotifications,
    bool? streakAlerts,
    bool? insightNotifications,
    bool? motivationalQuotes,
    bool? quietHoursEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? weekendRemindersEnabled,
    TimeOfDay? reminderWindowStart,
    TimeOfDay? reminderWindowEnd,
    String? deliveryMode,
    TimeOfDay? digestTime,
    int? cooldownMinutes,
    String? timezone,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      habitReminders: habitReminders ?? this.habitReminders,
      achievementNotifications:
          achievementNotifications ?? this.achievementNotifications,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      insightNotifications: insightNotifications ?? this.insightNotifications,
      motivationalQuotes: motivationalQuotes ?? this.motivationalQuotes,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      weekendRemindersEnabled: weekendRemindersEnabled ?? this.weekendRemindersEnabled,
      reminderWindowStart: reminderWindowStart ?? this.reminderWindowStart,
      reminderWindowEnd: reminderWindowEnd ?? this.reminderWindowEnd,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      digestTime: digestTime ?? this.digestTime,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      timezone: timezone ?? this.timezone,
    );
  }
}
