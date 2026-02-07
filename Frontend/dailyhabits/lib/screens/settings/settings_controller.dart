import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class SettingsController extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  bool isLoading = true;
  NotificationSettings? settings;

  SettingsController() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    isLoading = true;
    notifyListeners();

    try {
      settings = await _notificationService.getSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(NotificationSettings newSettings) async {
    // Optimistic update
    settings = newSettings;
    notifyListeners();

    try {
      final success = await _notificationService.updateSettings(newSettings);
      if (!success) {
        // Revert on failure (reload)
        loadSettings();
        // In a real app, show error toast
      }
    } catch (e) {
      loadSettings();
    }
  }

  void toggleNotifications(bool value) {
    if (settings != null) {
      updateSettings(settings!.copyWith(notificationsEnabled: value));
    }
  }

  void toggleHabitReminders(bool value) {
    if (settings != null) {
      updateSettings(settings!.copyWith(habitReminders: value));
    }
  }

  void toggleStreakAlerts(bool value) {
    if (settings != null) {
      updateSettings(settings!.copyWith(streakAlerts: value));
    }
  }

  void toggleInsightNotifications(bool value) {
    if (settings != null) {
      updateSettings(settings!.copyWith(insightNotifications: value));
    }
  }

  void toggleMotivationalQuotes(bool value) {
    if (settings != null) {
      updateSettings(settings!.copyWith(motivationalQuotes: value));
    }
  }
}
