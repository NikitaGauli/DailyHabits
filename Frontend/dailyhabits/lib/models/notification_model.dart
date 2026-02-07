import 'package:flutter/material.dart';

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final String status;
  final DateTime scheduledTime;
  final DateTime? sentAt;
  final IconData icon;
  final Color color;
  final int? habitId;
  // Social / deep-link fields
  final String actionType;
  final Map<String, dynamic> actionData;
  final int? fromUserId;
  final String? fromUserName;
  final String? fromUserImage;
  final int? groupId;
  final String? groupName;
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

  bool get isRead => status == 'read';
  bool get isSocial =>
      const ['friend_request', 'friend_accepted', 'group_join', 'group_approval',
        'group_challenge', 'social_like', 'social_comment'].contains(type);
  DateTime get createdAt => sentAt ?? scheduledTime;

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

// ─── Smart Tip Model ─────────────────────────────────────────────────────────

class SmartTip {
  final int id;
  final String tipType;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final int? habitId;
  final String? habitTitle;
  final bool isRead;
  final bool isLiked;
  final bool isSaved;
  final bool isDismissed;
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

  factory SmartTip.fromJson(Map<String, dynamic> json) {
    return SmartTip(
      id: json['id'],
      tipType: json['tipType'] ?? 'general',
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

class NotificationSettings {
  final bool notificationsEnabled;
  final bool habitReminders;
  final bool achievementNotifications;
  final bool streakAlerts;
  final bool insightNotifications;
  final bool motivationalQuotes;
  final bool quietHoursEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;

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
  });

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
    );
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'habitReminders': habitReminders,
      'achievementNotifications': achievementNotifications,
      'streakAlerts': streakAlerts,
      'insightNotifications': insightNotifications,
      'motivationalQuotes': motivationalQuotes,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart != null
          ? '${quietHoursStart!.hour}:${quietHoursStart!.minute}'
          : null,
      'quietHoursEnd': quietHoursEnd != null
          ? '${quietHoursEnd!.hour}:${quietHoursEnd!.minute}'
          : null,
    };
  }

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
    );
  }
}
