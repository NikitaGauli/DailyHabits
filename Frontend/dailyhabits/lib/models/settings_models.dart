// ==========================================================================
// Settings Models - App Preferences, Privacy, Security, Export & Support
// ==========================================================================

import 'package:flutter/material.dart';

// ==========================================================================
// User App Settings
// ==========================================================================

class UserAppSettings {
  final String theme;
  final String accentColor;
  final bool animationsEnabled;
  final String fontSize;
  final bool compactMode;
  final bool dailySummaryEnabled;
  final String dailySummaryTime;
  final bool quotesEnabled;
  final String quoteFrequency;
  final String quoteTone;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool quietHoursAllowEmergency;
  final bool quietHoursSeparateWeekend;
  final String? quietHoursWeekdayStart;
  final String? quietHoursWeekdayEnd;
  final String? quietHoursWeekendStart;
  final String? quietHoursWeekendEnd;
  final String timezone;
  final String language;
  final String weekStartDay;
  final bool analyticsConsent;
  final bool aiPersonalization;
  final bool hapticFeedback;
  final int autoArchiveDays;
  final String defaultHabitVisibility;

  UserAppSettings({
    this.theme = 'system',
    this.accentColor = 'indigo',
    this.animationsEnabled = true,
    this.fontSize = 'medium',
    this.compactMode = false,
    this.dailySummaryEnabled = true,
    this.dailySummaryTime = '20:00',
    this.quotesEnabled = true,
    this.quoteFrequency = 'morning',
    this.quoteTone = 'calm',
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursAllowEmergency = true,
    this.quietHoursSeparateWeekend = false,
    this.quietHoursWeekdayStart,
    this.quietHoursWeekdayEnd,
    this.quietHoursWeekendStart,
    this.quietHoursWeekendEnd,
    this.timezone = 'UTC',
    this.language = 'en',
    this.weekStartDay = 'monday',
    this.analyticsConsent = true,
    this.aiPersonalization = true,
    this.hapticFeedback = true,
    this.autoArchiveDays = 30,
    this.defaultHabitVisibility = 'private',
  });

  factory UserAppSettings.fromJson(Map<String, dynamic> json) {
    return UserAppSettings(
      theme: json['theme'] ?? 'system',
      accentColor: json['accentColor'] ?? 'indigo',
      animationsEnabled: json['animationsEnabled'] ?? true,
      fontSize: json['fontSize'] ?? 'medium',
      compactMode: json['compactMode'] ?? false,
      dailySummaryEnabled: json['dailySummaryEnabled'] ?? true,
      dailySummaryTime: json['dailySummaryTime'] ?? '20:00',
      quotesEnabled: json['quotesEnabled'] ?? true,
      quoteFrequency: json['quoteFrequency'] ?? 'morning',
      quoteTone: json['quoteTone'] ?? 'calm',
      quietHoursEnabled: json['quietHoursEnabled'] ?? false,
      quietHoursStart: json['quietHoursStart'],
      quietHoursEnd: json['quietHoursEnd'],
      quietHoursAllowEmergency: json['quietHoursAllowEmergency'] ?? true,
      quietHoursSeparateWeekend: json['quietHoursSeparateWeekend'] ?? false,
      quietHoursWeekdayStart: json['quietHoursWeekdayStart'],
      quietHoursWeekdayEnd: json['quietHoursWeekdayEnd'],
      quietHoursWeekendStart: json['quietHoursWeekendStart'],
      quietHoursWeekendEnd: json['quietHoursWeekendEnd'],
      timezone: json['timezone'] ?? 'UTC',
      language: json['language'] ?? 'en',
      weekStartDay: json['weekStartDay'] ?? 'monday',
      analyticsConsent: json['analyticsConsent'] ?? true,
      aiPersonalization: json['aiPersonalization'] ?? true,
      hapticFeedback: json['hapticFeedback'] ?? true,
      autoArchiveDays: json['autoArchiveDays'] ?? 30,
      defaultHabitVisibility: json['defaultHabitVisibility'] ?? 'private',
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'accentColor': accentColor,
        'animationsEnabled': animationsEnabled,
        'fontSize': fontSize,
        'compactMode': compactMode,
        'dailySummaryEnabled': dailySummaryEnabled,
        'dailySummaryTime': dailySummaryTime,
        'quotesEnabled': quotesEnabled,
        'quoteFrequency': quoteFrequency,
        'quoteTone': quoteTone,
        'quietHoursEnabled': quietHoursEnabled,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'quietHoursAllowEmergency': quietHoursAllowEmergency,
        'quietHoursSeparateWeekend': quietHoursSeparateWeekend,
        'quietHoursWeekdayStart': quietHoursWeekdayStart,
        'quietHoursWeekdayEnd': quietHoursWeekdayEnd,
        'quietHoursWeekendStart': quietHoursWeekendStart,
        'quietHoursWeekendEnd': quietHoursWeekendEnd,
        'timezone': timezone,
        'language': language,
        'weekStartDay': weekStartDay,
        'analyticsConsent': analyticsConsent,
        'aiPersonalization': aiPersonalization,
        'hapticFeedback': hapticFeedback,
        'autoArchiveDays': autoArchiveDays,
        'defaultHabitVisibility': defaultHabitVisibility,
      };

  UserAppSettings copyWith({
    String? theme,
    String? accentColor,
    bool? animationsEnabled,
    String? fontSize,
    bool? compactMode,
    bool? dailySummaryEnabled,
    String? dailySummaryTime,
    bool? quotesEnabled,
    String? quoteFrequency,
    String? quoteTone,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? quietHoursAllowEmergency,
    bool? quietHoursSeparateWeekend,
    String? quietHoursWeekdayStart,
    String? quietHoursWeekdayEnd,
    String? quietHoursWeekendStart,
    String? quietHoursWeekendEnd,
    String? timezone,
    String? language,
    String? weekStartDay,
    bool? analyticsConsent,
    bool? aiPersonalization,
    bool? hapticFeedback,
    int? autoArchiveDays,
    String? defaultHabitVisibility,
  }) {
    return UserAppSettings(
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      fontSize: fontSize ?? this.fontSize,
      compactMode: compactMode ?? this.compactMode,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      dailySummaryTime: dailySummaryTime ?? this.dailySummaryTime,
      quotesEnabled: quotesEnabled ?? this.quotesEnabled,
      quoteFrequency: quoteFrequency ?? this.quoteFrequency,
      quoteTone: quoteTone ?? this.quoteTone,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursAllowEmergency: quietHoursAllowEmergency ?? this.quietHoursAllowEmergency,
      quietHoursSeparateWeekend: quietHoursSeparateWeekend ?? this.quietHoursSeparateWeekend,
      quietHoursWeekdayStart: quietHoursWeekdayStart ?? this.quietHoursWeekdayStart,
      quietHoursWeekdayEnd: quietHoursWeekdayEnd ?? this.quietHoursWeekdayEnd,
      quietHoursWeekendStart: quietHoursWeekendStart ?? this.quietHoursWeekendStart,
      quietHoursWeekendEnd: quietHoursWeekendEnd ?? this.quietHoursWeekendEnd,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      aiPersonalization: aiPersonalization ?? this.aiPersonalization,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      autoArchiveDays: autoArchiveDays ?? this.autoArchiveDays,
      defaultHabitVisibility: defaultHabitVisibility ?? this.defaultHabitVisibility,
    );
  }
}

// ==========================================================================
// Privacy Settings Model
// ==========================================================================

class PrivacySettingsModel {
  final String accountVisibility;
  final bool showProfileInSearch;
  final bool showInLeaderboard;
  final String whoCanViewHabits;
  final String whoCanViewStreaks;
  final bool shareProgressWithGroups;
  final String whoCanSendFriendRequests;
  final bool allowGroupInvites;
  final bool showOnlineStatus;
  final bool shareAnonymousUsageData;
  final bool allowAiTraining;

  PrivacySettingsModel({
    this.accountVisibility = 'friends',
    this.showProfileInSearch = true,
    this.showInLeaderboard = true,
    this.whoCanViewHabits = 'friends',
    this.whoCanViewStreaks = 'friends',
    this.shareProgressWithGroups = true,
    this.whoCanSendFriendRequests = 'everyone',
    this.allowGroupInvites = true,
    this.showOnlineStatus = true,
    this.shareAnonymousUsageData = true,
    this.allowAiTraining = false,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      accountVisibility: json['accountVisibility'] ?? 'friends',
      showProfileInSearch: json['showProfileInSearch'] ?? true,
      showInLeaderboard: json['showInLeaderboard'] ?? true,
      whoCanViewHabits: json['whoCanViewHabits'] ?? 'friends',
      whoCanViewStreaks: json['whoCanViewStreaks'] ?? 'friends',
      shareProgressWithGroups: json['shareProgressWithGroups'] ?? true,
      whoCanSendFriendRequests: json['whoCanSendFriendRequests'] ?? 'everyone',
      allowGroupInvites: json['allowGroupInvites'] ?? true,
      showOnlineStatus: json['showOnlineStatus'] ?? true,
      shareAnonymousUsageData: json['shareAnonymousUsageData'] ?? true,
      allowAiTraining: json['allowAiTraining'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountVisibility': accountVisibility,
        'showProfileInSearch': showProfileInSearch,
        'showInLeaderboard': showInLeaderboard,
        'whoCanViewHabits': whoCanViewHabits,
        'whoCanViewStreaks': whoCanViewStreaks,
        'shareProgressWithGroups': shareProgressWithGroups,
        'whoCanSendFriendRequests': whoCanSendFriendRequests,
        'allowGroupInvites': allowGroupInvites,
        'showOnlineStatus': showOnlineStatus,
        'shareAnonymousUsageData': shareAnonymousUsageData,
        'allowAiTraining': allowAiTraining,
      };

  PrivacySettingsModel copyWith({
    String? accountVisibility,
    bool? showProfileInSearch,
    bool? showInLeaderboard,
    String? whoCanViewHabits,
    String? whoCanViewStreaks,
    bool? shareProgressWithGroups,
    String? whoCanSendFriendRequests,
    bool? allowGroupInvites,
    bool? showOnlineStatus,
    bool? shareAnonymousUsageData,
    bool? allowAiTraining,
  }) {
    return PrivacySettingsModel(
      accountVisibility: accountVisibility ?? this.accountVisibility,
      showProfileInSearch: showProfileInSearch ?? this.showProfileInSearch,
      showInLeaderboard: showInLeaderboard ?? this.showInLeaderboard,
      whoCanViewHabits: whoCanViewHabits ?? this.whoCanViewHabits,
      whoCanViewStreaks: whoCanViewStreaks ?? this.whoCanViewStreaks,
      shareProgressWithGroups: shareProgressWithGroups ?? this.shareProgressWithGroups,
      whoCanSendFriendRequests: whoCanSendFriendRequests ?? this.whoCanSendFriendRequests,
      allowGroupInvites: allowGroupInvites ?? this.allowGroupInvites,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      shareAnonymousUsageData: shareAnonymousUsageData ?? this.shareAnonymousUsageData,
      allowAiTraining: allowAiTraining ?? this.allowAiTraining,
    );
  }
}

// ==========================================================================
// Security Settings Model
// ==========================================================================

class SecuritySettingsModel {
  final bool twoFactorEnabled;
  final String twoFactorMethod;
  final bool biometricLockEnabled;
  final bool requireAuthForExport;
  final bool requireAuthForDelete;
  final int sessionTimeoutMinutes;
  final bool loginNotificationEnabled;

  SecuritySettingsModel({
    this.twoFactorEnabled = false,
    this.twoFactorMethod = 'email',
    this.biometricLockEnabled = false,
    this.requireAuthForExport = true,
    this.requireAuthForDelete = true,
    this.sessionTimeoutMinutes = 0,
    this.loginNotificationEnabled = true,
  });

  factory SecuritySettingsModel.fromJson(Map<String, dynamic> json) {
    return SecuritySettingsModel(
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
      twoFactorMethod: json['twoFactorMethod'] ?? 'email',
      biometricLockEnabled: json['biometricLockEnabled'] ?? false,
      requireAuthForExport: json['requireAuthForExport'] ?? true,
      requireAuthForDelete: json['requireAuthForDelete'] ?? true,
      sessionTimeoutMinutes: json['sessionTimeoutMinutes'] ?? 0,
      loginNotificationEnabled: json['loginNotificationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'twoFactorEnabled': twoFactorEnabled,
        'twoFactorMethod': twoFactorMethod,
        'biometricLockEnabled': biometricLockEnabled,
        'requireAuthForExport': requireAuthForExport,
        'requireAuthForDelete': requireAuthForDelete,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
        'loginNotificationEnabled': loginNotificationEnabled,
      };

  SecuritySettingsModel copyWith({
    bool? twoFactorEnabled,
    String? twoFactorMethod,
    bool? biometricLockEnabled,
    bool? requireAuthForExport,
    bool? requireAuthForDelete,
    int? sessionTimeoutMinutes,
    bool? loginNotificationEnabled,
  }) {
    return SecuritySettingsModel(
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      requireAuthForExport: requireAuthForExport ?? this.requireAuthForExport,
      requireAuthForDelete: requireAuthForDelete ?? this.requireAuthForDelete,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      loginNotificationEnabled: loginNotificationEnabled ?? this.loginNotificationEnabled,
    );
  }
}

// ==========================================================================
// Login Session Model
// ==========================================================================

class LoginSessionModel {
  final int id;
  final String sessionKey;
  final String deviceName;
  final String deviceType;
  final String platform;
  final String ipAddress;
  final String? location;
  final bool isCurrent;
  final bool isActive;
  final String createdAt;
  final String lastActiveAt;

  LoginSessionModel({
    required this.id,
    required this.sessionKey,
    required this.deviceName,
    this.deviceType = 'unknown',
    this.platform = 'unknown',
    required this.ipAddress,
    this.location,
    this.isCurrent = false,
    this.isActive = true,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory LoginSessionModel.fromJson(Map<String, dynamic> json) {
    return LoginSessionModel(
      id: json['id'],
      sessionKey: json['sessionKey'] ?? '',
      deviceName: json['deviceName'] ?? 'Unknown Device',
      deviceType: json['deviceType'] ?? 'unknown',
      platform: json['platform'] ?? 'unknown',
      ipAddress: json['ipAddress'] ?? '',
      location: json['location'],
      isCurrent: json['isCurrent'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? '',
      lastActiveAt: json['lastActiveAt'] ?? '',
    );
  }

  IconData get deviceIcon {
    switch (deviceType) {
      case 'mobile':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet;
      case 'desktop':
        return Icons.computer;
      case 'browser':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  String get maskedKey {
    if (sessionKey.length <= 8) return sessionKey;
    return '\u2022\u2022\u2022\u2022${sessionKey.substring(sessionKey.length - 8)}';
  }
}

// ==========================================================================
// Audit Log Entry
// ==========================================================================

class AuditLogEntry {
  final int id;
  final String category;
  final String action;
  final String description;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? ipAddress;
  final String createdAt;

  AuditLogEntry({
    required this.id,
    required this.category,
    required this.action,
    required this.description,
    this.oldValue,
    this.newValue,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      category: json['category'] ?? 'general',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      oldValue: json['oldValue'] is Map ? Map<String, dynamic>.from(json['oldValue']) : null,
      newValue: json['newValue'] is Map ? Map<String, dynamic>.from(json['newValue']) : null,
      ipAddress: json['ipAddress'],
      createdAt: json['createdAt'] ?? '',
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'appearance':
        return 'Appearance';
      case 'privacy':
        return 'Privacy';
      case 'security':
        return 'Security';
      case 'notification':
        return 'Notifications';
      case 'export':
        return 'Data Export';
      case 'account':
        return 'Account';
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'appearance':
        return Icons.palette_outlined;
      case 'privacy':
        return Icons.shield_outlined;
      case 'security':
        return Icons.lock_outlined;
      case 'notification':
        return Icons.notifications_outlined;
      case 'export':
        return Icons.download_outlined;
      case 'account':
        return Icons.person_outlined;
      default:
        return Icons.history;
    }
  }
}

// ==========================================================================
// Export Request Model
// ==========================================================================

class ExportRequest {
  final int id;
  final String format;
  final String dateFrom;
  final String dateTo;
  final String status;
  final String createdAt;
  final String? completedAt;

  ExportRequest({
    required this.id,
    required this.format,
    required this.dateFrom,
    required this.dateTo,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory ExportRequest.fromJson(Map<String, dynamic> json) {
    return ExportRequest(
      id: json['id'],
      format: json['format'],
      dateFrom: json['dateFrom'],
      dateTo: json['dateTo'],
      status: json['status'],
      createdAt: json['createdAt'],
      completedAt: json['completedAt'],
    );
  }
}

// ==========================================================================
// Privacy Policy Model
// ==========================================================================

class PrivacyPolicyModel {
  final String version;
  final String title;
  final String content;
  final String effectiveDate;
  final String lastUpdated;

  PrivacyPolicyModel({
    required this.version,
    required this.title,
    required this.content,
    required this.effectiveDate,
    required this.lastUpdated,
  });

  factory PrivacyPolicyModel.fromJson(Map<String, dynamic> json) {
    return PrivacyPolicyModel(
      version: json['version'] ?? '1.0',
      title: json['title'] ?? 'Privacy Policy',
      content: json['content'] ?? '',
      effectiveDate: json['effectiveDate'] ?? '',
      lastUpdated: json['lastUpdated'] ?? '',
    );
  }
}

// ==========================================================================
// FAQ Model
// ==========================================================================

class FAQItem {
  final int id;
  final String question;
  final String answer;
  final String category;

  FAQItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      category: json['category'] ?? 'General',
    );
  }
}

// ==========================================================================
// Support Ticket Model
// ==========================================================================

class SupportTicket {
  final int id;
  final String subject;
  final String? description;
  final String category;
  final String priority;
  final String status;
  final String? adminResponse;
  final String createdAt;
  final String updatedAt;

  SupportTicket({
    required this.id,
    required this.subject,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      subject: json['subject'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'open',
      adminResponse: json['adminResponse'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Color get statusColor {
    switch (status) {
      case 'open':
        return const Color(0xFF3B82F6);
      case 'in_progress':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}
