// =============================================================================
// File: achievements_controller.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: State management controller for the Achievements screen.
//              Concurrently loads the list of all achievements and the user's
//              current level / XP data from [AchievementService].
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement.dart';

/// Reactive controller that provides achievement and level data to the UI.
///
/// On construction, it immediately initiates [loadData], which fetches
/// achievements and user-level information in parallel. The UI listens
/// via [ChangeNotifier] and rebuilds when the data is ready.
class AchievementsController extends ChangeNotifier {
  /// Backend service for achievement-related API calls.
  final AchievementService _service = AchievementService();

  /// Whether the controller is currently fetching data.
  bool isLoading = true;

  /// Complete list of achievements (both earned and locked).
  List<Achievement> achievements = [];

  /// The current user’s level, XP, and progression metadata.
  UserLevel? userLevel;

  /// Creates the controller and begins loading achievement data immediately.
  AchievementsController() {
    loadData();
  }

  /// Loads achievements and user-level data concurrently from the backend.
  ///
  /// Sets [isLoading] to `true` before the request and `false` after,
  /// notifying listeners at both points to trigger UI rebuilds.
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getAchievements(),
        _service.getUserLevel(),
      ]);

      achievements = results[0] as List<Achievement>;
      userLevel = results[1] as UserLevel?;
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
