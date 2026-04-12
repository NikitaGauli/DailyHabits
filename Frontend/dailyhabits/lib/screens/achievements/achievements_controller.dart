// =============================================================================
// File: achievements_controller.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: State management controller for the Achievements screen.
//              Concurrently loads the list of all achievements and the user's
//              current level / XP data from [AchievementService].
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../services/community_service.dart';
import '../../models/achievement.dart';

/// Reactive controller that provides achievement and level data to the UI.
///
/// On construction, it immediately initiates [loadData], which fetches
/// achievements and user-level information in parallel. The UI listens
/// via [ChangeNotifier] and rebuilds when the data is ready.
class AchievementsController extends ChangeNotifier {
  /// Backend service for achievement-related API calls.
  final AchievementService _service = AchievementService();
  final CommunityService _communityService = CommunityService();

  /// Whether the controller is currently fetching data.
  bool isLoading = true;

  /// Complete list of achievements (both earned and locked).
  List<Achievement> achievements = [];

  /// The current user’s level, XP, and progression metadata.
  UserLevel? userLevel;

  /// Groups available for sharing achievements.
  List<Map<String, dynamic>> myGroups = [];

  bool isSharing = false;
  String? actionMessage;
  bool actionSuccess = false;

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

  Future<void> loadGroupsForSharing() async {
    try {
      final data = await _communityService.getGroups();
      myGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
      notifyListeners();
    } catch (_) {
      myGroups = [];
      notifyListeners();
    }
  }

  Future<bool> shareAchievementToGroup(Achievement achievement, int groupId) async {
    isSharing = true;
    notifyListeners();
    try {
      await _communityService.createPost(
        content: '🏆 I unlocked "${achievement.name}" (+${achievement.points} XP)!',
        postType: 'achievement',
        emoji: '🏆',
        groupId: groupId,
        isPublic: true,
      );
      actionSuccess = true;
      actionMessage = 'Achievement shared to group successfully';
      isSharing = false;
      notifyListeners();
      return true;
    } catch (e) {
      actionSuccess = false;
      actionMessage = e.toString().replaceFirst('Exception: ', '');
      isSharing = false;
      notifyListeners();
      return false;
    }
  }
}
