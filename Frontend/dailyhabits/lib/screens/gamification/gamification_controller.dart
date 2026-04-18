// =============================================================================
// File: gamification_controller.dart
// Description: State management controller for the Gamification screens.
//              Manages dashboard, challenges, leaderboard, streak freezes,
//              and daily bonus state via the GamificationService.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/gamification_service.dart';
import '../../models/gamification_models.dart';

// =============================================================================
// Gamification Controller
// =============================================================================

/// Reactive controller for the gamification feature set.
///
/// Extends [ChangeNotifier] so that widgets wrapped in [Consumer] or
/// `context.watch<GamificationController>()` rebuild when data changes.
///
/// This controller is registered as a singleton [ChangeNotifierProvider] in
/// main.dart. [loadData] is NOT called in the constructor — it must be
/// invoked after the user is authenticated (e.g. from initState).
class GamificationController extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final GamificationService _service = GamificationService();

  // ---------------------------------------------------------------------------
  // State Fields
  // ---------------------------------------------------------------------------

  /// Whether any data fetch is in progress.
  bool isLoading = true;

  /// Whether a specific action (buy freeze, claim bonus, etc.) is processing.
  bool isActioning = false;

  /// General error message, if any.
  String? errorMessage;

  /// The composite dashboard data loaded from the API.
  GamificationDashboard? dashboard;

  /// The user's challenges (active + completed).
  List<Challenge> myChallenges = [];

  /// Community challenges available to join.
  List<Challenge> communityChallenges = [];

  /// Full leaderboard data.
  Leaderboard? leaderboard;

  /// Currently selected leaderboard type.
  String leaderboardType = 'weekly';

  /// XP history events.
  List<XPEvent> xpHistory = [];

  /// Whether XP history has more pages.
  bool hasMoreXPHistory = true;
  int _xpHistoryPage = 1;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Does NOT call [loadData] — call it after authentication.
  GamificationController();

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  int get currentLevel => dashboard?.currentLevel ?? 1;
  String get levelName => dashboard?.levelName ?? 'Beginner';
  int get currentXp => dashboard?.currentXp ?? 0;
  int get totalXp => dashboard?.totalXp ?? 0;
  int get xpForNextLevel => dashboard?.xpForNextLevel ?? 150;
  double get xpProgress => dashboard?.xpProgressPercentage ?? 0;

  int get coinBalance => dashboard?.wallet.balance ?? 0;
  int get todayXp => dashboard?.todayXp ?? 0;
  int get weekXp => dashboard?.weekXp ?? 0;
  double get streakMultiplier => dashboard?.streakMultiplier ?? 1.0;

  int get currentStreak => dashboard?.currentStreak ?? 0;
  int get bestStreak => dashboard?.bestStreak ?? 0;
  StreakFreezeInfo? get freezes => dashboard?.freezes;

  bool get loginBonusClaimed => dashboard?.dailyBonus.loginClaimed ?? false;
  bool get allDoneBonusClaimed => dashboard?.dailyBonus.allDoneClaimed ?? false;

  List<Challenge> get activeChallenges => dashboard?.activeChallenges ?? [];
  List<XPEvent> get recentActivity => dashboard?.recentActivity ?? [];

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  /// Loads the gamification dashboard from the backend.
  /// Call this after the user is authenticated.
  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboard = await _service.getDashboard();
      if (dashboard == null) {
        errorMessage = 'Unable to load gamification data';
      }
    } catch (e) {
      debugPrint('GamificationController.loadData error: $e');
      errorMessage = 'Something went wrong. Pull to refresh.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes all loaded data (dashboard + currently active sub-views).
  Future<void> refreshAll() async {
    await Future.wait([
      loadData(),
      if (myChallenges.isNotEmpty || communityChallenges.isNotEmpty)
        loadChallenges(),
      if (leaderboard != null) loadLeaderboard(type: leaderboardType),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Daily Login Bonus
  // ---------------------------------------------------------------------------

  /// Claims the daily login XP bonus. Returns true on success.
  Future<bool> claimDailyLogin() async {
    if (isActioning) return false;
    isActioning = true;
    notifyListeners();

    try {
      final result = await _service.claimDailyLogin();
      if (result != null && result['success'] == true) {
        // Refresh dashboard to reflect new XP/coins
        await loadData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('claimDailyLogin error: $e');
      return false;
    } finally {
      isActioning = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Streak Freezes
  // ---------------------------------------------------------------------------

  /// Purchases a streak freeze token. Returns a result message.
  Future<String> buyStreakFreeze() async {
    if (isActioning) return 'Please wait...';
    isActioning = true;
    notifyListeners();

    try {
      final result = await _service.buyStreakFreeze();
      if (result == null) return 'Network error';

      if (result['success'] == true) {
        await loadData(); // Refresh to get updated balance and freeze count
        return 'Streak freeze purchased!';
      } else {
        return result['error'] ?? 'Unable to purchase';
      }
    } catch (e) {
      return 'Something went wrong';
    } finally {
      isActioning = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Challenges
  // ---------------------------------------------------------------------------

  /// Loads the user's challenges and community challenges.
  Future<void> loadChallenges() async {
    try {
      final results = await Future.wait([
        _service.getMyChallenges(),
        _service.getCommunityChallenges(),
      ]);

      myChallenges = results[0];
      communityChallenges = results[1];
      notifyListeners();
    } catch (e) {
      debugPrint('loadChallenges error: $e');
    }
  }

  /// Creates a new challenge.
  Future<Challenge?> createChallenge({
    required String title,
    required String description,
    required String scope,
    required String difficulty,
    required DateTime startDate,
    required DateTime endDate,
    required int target,
    required String criteriaType,
    int xpReward = 100,
    int coinReward = 20,
    int maxParticipants = 1,
  }) async {
    if (isActioning) return null;
    isActioning = true;
    notifyListeners();

    try {
      final challenge = await _service.createChallenge(
        title: title,
        description: description,
        scope: scope,
        difficulty: difficulty,
        startDate: startDate,
        endDate: endDate,
        target: target,
        criteriaType: criteriaType,
        xpReward: xpReward,
        coinReward: coinReward,
        maxParticipants: maxParticipants,
      );

      if (challenge != null) {
        await loadChallenges();
      }
      return challenge;
    } catch (e) {
      debugPrint('createChallenge error: $e');
      return null;
    } finally {
      isActioning = false;
      notifyListeners();
    }
  }

  /// Joins an existing community challenge.
  Future<bool> joinChallenge(int challengeId) async {
    if (isActioning) return false;
    isActioning = true;
    notifyListeners();

    try {
      final success = await _service.joinChallenge(challengeId);
      if (success) {
        await loadChallenges();
      }
      return success;
    } catch (e) {
      debugPrint('joinChallenge error: $e');
      return false;
    } finally {
      isActioning = false;
      notifyListeners();
    }
  }

  /// Marks a challenge done for today in a gamified way.
  Future<bool> markChallengeDoneToday(int challengeId) async {
    if (isActioning) return false;
    isActioning = true;
    notifyListeners();

    try {
      final result = await _service.markChallengeDoneToday(challengeId);
      final success = result != null && result['success'] == true;
      if (success) {
        await loadData();
        await loadChallenges();
      }
      return success;
    } catch (e) {
      debugPrint('markChallengeDoneToday error: $e');
      return false;
    } finally {
      isActioning = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  /// Loads leaderboard data for the given [type] (weekly/monthly/alltime).
  Future<void> loadLeaderboard({String type = 'weekly'}) async {
    leaderboardType = type;
    try {
      leaderboard = await _service.getLeaderboard(boardType: type);
      notifyListeners();
    } catch (e) {
      debugPrint('loadLeaderboard error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // XP History (Paginated)
  // ---------------------------------------------------------------------------

  /// Loads the first page of XP history.
  Future<void> loadXPHistory() async {
    _xpHistoryPage = 1;
    hasMoreXPHistory = true;
    xpHistory = await _service.getXPHistory(page: 1);
    if (xpHistory.length < 20) hasMoreXPHistory = false;
    notifyListeners();
  }

  /// Loads the next page of XP history (pagination).
  Future<void> loadMoreXPHistory() async {
    if (!hasMoreXPHistory) return;
    _xpHistoryPage++;
    final more = await _service.getXPHistory(page: _xpHistoryPage);
    if (more.isEmpty || more.length < 20) hasMoreXPHistory = false;
    xpHistory.addAll(more);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Milestones
  // ---------------------------------------------------------------------------

  /// Triggers a manual milestone check and returns any new milestones.
  Future<List<MilestoneReward>> checkMilestones() async {
    try {
      final milestones = await _service.checkMilestones();
      if (milestones.isNotEmpty) {
        await loadData(); // Refresh to reflect rewards
      }
      return milestones;
    } catch (e) {
      debugPrint('checkMilestones error: $e');
      return [];
    }
  }
}
