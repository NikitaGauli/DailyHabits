import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement.dart';

class AchievementsController extends ChangeNotifier {
  final AchievementService _service = AchievementService();

  bool isLoading = true;
  List<Achievement> achievements = [];
  UserLevel? userLevel;

  AchievementsController() {
    loadData();
  }

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
