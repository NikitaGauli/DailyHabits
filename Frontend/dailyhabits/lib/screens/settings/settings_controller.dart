import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../models/notification_model.dart';
import '../../models/settings_models.dart';

/// Central state-management controller for the entire Settings feature.
///
/// Manages: notification settings, app settings, privacy, security,
/// login sessions, audit logs, profile, exports, privacy policy,
/// FAQs, support tickets, and account deletion.
class SettingsController extends ChangeNotifier {
  // ─── Services ──────────────────────────────────────────────────
  final NotificationService _notificationService = NotificationService();
  final SettingsService _settingsService = SettingsService();

  // ─── Observable State ──────────────────────────────────────────
  bool isLoading = true;
  String? error;

  // Core settings
  NotificationSettings? notifSettings;
  UserAppSettings? appSettings;
  Map<String, dynamic>? profile;

  // Privacy & Security
  PrivacySettingsModel? privacySettings;
  SecuritySettingsModel? securitySettings;
  List<LoginSessionModel> loginSessions = [];
  List<AuditLogEntry> auditLogs = [];

  // Support & Data
  PrivacyPolicyModel? privacyPolicy;
  List<FAQItem> faqs = [];
  List<SupportTicket> tickets = [];
  List<ExportRequest> exports = [];

  // Sub-page loading states
  bool isLoadingPrivacy = false;
  bool isLoadingSecurity = false;
  bool isLoadingSessions = false;
  bool isLoadingAuditLogs = false;

  // ─── Initialization ────────────────────────────────────────────
  SettingsController() {
    loadAll();
  }

  /// Fetches notification settings, app settings, and profile in parallel.
  Future<void> loadAll() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _notificationService.getSettings(),
        _settingsService.getSettings(),
        _settingsService.getProfile(),
      ]);
      notifSettings = results[0] as NotificationSettings?;
      appSettings = results[1] as UserAppSettings? ?? UserAppSettings();
      profile = results[2] as Map<String, dynamic>?;
    } catch (e) {
      error = 'Failed to load settings';
      debugPrint('SettingsController error: ');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROFILE
  // ═══════════════════════════════════════════════════════════════

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final success = await _settingsService.updateProfile(fields);
    if (success) {
      profile = {...?profile, ...fields};
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOTIFICATION SETTINGS (optimistic updates)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _updateNotifSettings(NotificationSettings ns) async {
    final old = notifSettings;
    notifSettings = ns;
    notifyListeners();
    final ok = await _notificationService.updateSettings(ns);
    if (!ok) {
      notifSettings = old;
      notifyListeners();
    }
  }

  void toggleNotifications(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(notificationsEnabled: v));
    }
  }

  void toggleHabitReminders(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(habitReminders: v));
    }
  }

  void toggleStreakAlerts(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(streakAlerts: v));
    }
  }

  void toggleInsightNotifications(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(insightNotifications: v));
    }
  }

  void toggleMotivationalQuotes(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(motivationalQuotes: v));
    }
  }

  void toggleAchievementNotifications(bool v) {
    if (notifSettings != null) {
      _updateNotifSettings(notifSettings!.copyWith(achievementNotifications: v));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  APP SETTINGS (appearance, quotes, daily summary, quiet hours, advanced)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _updateAppSettings(Map<String, dynamic> fields) async {
    final ok = await _settingsService.updateSettings(fields);
    if (ok) {
      appSettings = UserAppSettings.fromJson({
        ...appSettings!.toJson(),
        ...fields,
      });
      notifyListeners();
    }
  }

  // Appearance
  void setTheme(String theme) => _updateAppSettings({'theme': theme});
  void setAccentColor(String color) => _updateAppSettings({'accentColor': color});
  void setAnimationsEnabled(bool v) => _updateAppSettings({'animationsEnabled': v});
  void setFontSize(String size) => _updateAppSettings({'fontSize': size});
  void setCompactMode(bool v) => _updateAppSettings({'compactMode': v});

  // Daily Summary
  void setDailySummaryEnabled(bool v) => _updateAppSettings({'dailySummaryEnabled': v});
  void setDailySummaryTime(String t) => _updateAppSettings({'dailySummaryTime': t});

  // Quotes
  void setQuotesEnabled(bool v) => _updateAppSettings({'quotesEnabled': v});
  void setQuoteFrequency(String f) => _updateAppSettings({'quoteFrequency': f});
  void setQuoteTone(String t) => _updateAppSettings({'quoteTone': t});

  // Quiet Hours
  void setQuietHoursEnabled(bool v) => _updateAppSettings({'quietHoursEnabled': v});
  void setQuietHoursStart(String t) => _updateAppSettings({'quietHoursStart': t});
  void setQuietHoursEnd(String t) => _updateAppSettings({'quietHoursEnd': t});
  void setQuietHoursAllowEmergency(bool v) => _updateAppSettings({'quietHoursAllowEmergency': v});
  void setQuietHoursSeparateWeekend(bool v) => _updateAppSettings({'quietHoursSeparateWeekend': v});
  void setQuietHoursWeekdayStart(String t) => _updateAppSettings({'quietHoursWeekdayStart': t});
  void setQuietHoursWeekdayEnd(String t) => _updateAppSettings({'quietHoursWeekdayEnd': t});
  void setQuietHoursWeekendStart(String t) => _updateAppSettings({'quietHoursWeekendStart': t});
  void setQuietHoursWeekendEnd(String t) => _updateAppSettings({'quietHoursWeekendEnd': t});

  // Advanced
  void setLanguage(String lang) => _updateAppSettings({'language': lang});
  void setWeekStartDay(String day) => _updateAppSettings({'weekStartDay': day});
  void setAnalyticsConsent(bool v) => _updateAppSettings({'analyticsConsent': v});
  void setAiPersonalization(bool v) => _updateAppSettings({'aiPersonalization': v});
  void setHapticFeedback(bool v) => _updateAppSettings({'hapticFeedback': v});
  void setAutoArchiveDays(int days) => _updateAppSettings({'autoArchiveDays': days});
  void setDefaultHabitVisibility(String v) => _updateAppSettings({'defaultHabitVisibility': v});

  // ═══════════════════════════════════════════════════════════════
  //  PRIVACY SETTINGS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadPrivacySettings() async {
    isLoadingPrivacy = true;
    notifyListeners();
    privacySettings = await _settingsService.getPrivacySettings() ?? PrivacySettingsModel();
    isLoadingPrivacy = false;
    notifyListeners();
  }

  Future<void> _updatePrivacySettings(Map<String, dynamic> fields) async {
    final ok = await _settingsService.updatePrivacySettings(fields);
    if (ok) {
      privacySettings = PrivacySettingsModel.fromJson({
        ...privacySettings!.toJson(),
        ...fields,
      });
      notifyListeners();
    }
  }

  void setAccountVisibility(String v) => _updatePrivacySettings({'accountVisibility': v});
  void setShowProfileInSearch(bool v) => _updatePrivacySettings({'showProfileInSearch': v});
  void setShowInLeaderboard(bool v) => _updatePrivacySettings({'showInLeaderboard': v});
  void setWhoCanViewHabits(String v) => _updatePrivacySettings({'whoCanViewHabits': v});
  void setWhoCanViewStreaks(String v) => _updatePrivacySettings({'whoCanViewStreaks': v});
  void setShareProgressWithGroups(bool v) => _updatePrivacySettings({'shareProgressWithGroups': v});
  void setWhoCanSendFriendRequests(String v) => _updatePrivacySettings({'whoCanSendFriendRequests': v});
  void setAllowGroupInvites(bool v) => _updatePrivacySettings({'allowGroupInvites': v});
  void setShowOnlineStatus(bool v) => _updatePrivacySettings({'showOnlineStatus': v});
  void setShareAnonymousUsageData(bool v) => _updatePrivacySettings({'shareAnonymousUsageData': v});
  void setAllowAiTraining(bool v) => _updatePrivacySettings({'allowAiTraining': v});

  // ═══════════════════════════════════════════════════════════════
  //  SECURITY SETTINGS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadSecuritySettings() async {
    isLoadingSecurity = true;
    notifyListeners();
    securitySettings = await _settingsService.getSecuritySettings() ?? SecuritySettingsModel();
    isLoadingSecurity = false;
    notifyListeners();
  }

  Future<void> _updateSecuritySettings(Map<String, dynamic> fields) async {
    final ok = await _settingsService.updateSecuritySettings(fields);
    if (ok) {
      securitySettings = SecuritySettingsModel.fromJson({
        ...securitySettings!.toJson(),
        ...fields,
      });
      notifyListeners();
    }
  }

  void setTwoFactorEnabled(bool v) => _updateSecuritySettings({'twoFactorEnabled': v});
  void setTwoFactorMethod(String m) => _updateSecuritySettings({'twoFactorMethod': m});
  void setBiometricLockEnabled(bool v) => _updateSecuritySettings({'biometricLockEnabled': v});
  void setRequireAuthForExport(bool v) => _updateSecuritySettings({'requireAuthForExport': v});
  void setRequireAuthForDelete(bool v) => _updateSecuritySettings({'requireAuthForDelete': v});
  void setSessionTimeoutMinutes(int m) => _updateSecuritySettings({'sessionTimeoutMinutes': m});
  void setLoginNotificationEnabled(bool v) => _updateSecuritySettings({'loginNotificationEnabled': v});

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _settingsService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LOGIN SESSIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadLoginSessions() async {
    isLoadingSessions = true;
    notifyListeners();
    loginSessions = await _settingsService.getLoginSessions();
    isLoadingSessions = false;
    notifyListeners();
  }

  Future<bool> revokeSession(int sessionId) async {
    final ok = await _settingsService.revokeSession(sessionId);
    if (ok) {
      loginSessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> revokeAllSessions() async {
    final ok = await _settingsService.revokeAllSessions();
    if (ok) {
      loginSessions.removeWhere((s) => !s.isCurrent);
      notifyListeners();
    }
    return ok;
  }

  // ═══════════════════════════════════════════════════════════════
  //  AUDIT LOGS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadAuditLogs({String? category}) async {
    isLoadingAuditLogs = true;
    notifyListeners();
    auditLogs = await _settingsService.getAuditLogs(category: category);
    isLoadingAuditLogs = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  EXPORTS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadExports() async {
    exports = await _settingsService.getExports();
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestExport({
    required String format,
    required String dateFrom,
    required String dateTo,
  }) async {
    final result = await _settingsService.requestExport(
      format: format,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (result['success'] == true) {
      await loadExports();
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRIVACY POLICY, FAQS, SUPPORT TICKETS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadPrivacyPolicy() async {
    privacyPolicy = await _settingsService.getPrivacyPolicy();
    notifyListeners();
  }

  Future<void> loadFAQs() async {
    faqs = await _settingsService.getFAQs();
    notifyListeners();
  }

  Future<void> loadTickets() async {
    tickets = await _settingsService.getTickets();
    notifyListeners();
  }

  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'medium',
  }) async {
    final result = await _settingsService.createTicket(
      subject: subject,
      description: description,
      category: category,
      priority: priority,
    );
    if (result['success'] == true) {
      await loadTickets();
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACCOUNT DELETION
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> requestAccountDeletion({String reason = ''}) async {
    return _settingsService.requestDeletion(reason: reason);
  }
}
