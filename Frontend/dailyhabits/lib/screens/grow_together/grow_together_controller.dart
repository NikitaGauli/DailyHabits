// =============================================================================
// File: grow_together_controller.dart
// Description: ChangeNotifier-based state controller for the Grow Together
//              collaborative habit sharing feature. Manages dashboard, CRUD,
//              invites, progress, social, leaderboard, and milestones state.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/services/grow_together_service.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

// =============================================================================
// Grow Together Controller
// =============================================================================

/// Reactive state controller for the Grow Together feature.
///
/// Orchestrates data loading, CRUD operations, invite management, progress
/// tracking, social interactions, leaderboard, and milestones via the
/// [GrowTogetherService]. Extends [ChangeNotifier] so UI widgets rebuild
/// automatically through Provider.
class GrowTogetherController extends ChangeNotifier {
  final GrowTogetherService _svc = GrowTogetherService();

  // ── Loading & Error State ─────────────────────────────────────────

  bool isLoading = false;
  bool isActionLoading = false;
  String? error;
  String? actionMessage;
  bool actionSuccess = false;

  // ── Dashboard State ───────────────────────────────────────────────

  GrowTogetherDashboard? dashboard;

  // ── Habits State ──────────────────────────────────────────────────

  List<CollaborativeHabit> myHabits = [];
  CollaborativeHabit? selectedHabit;

  // ── Invites State ─────────────────────────────────────────────────

  List<HabitInvite> pendingInvites = [];

  // ── Discover State ────────────────────────────────────────────────

  List<CollaborativeHabit> discoverableHabits = [];
  bool isLoadingDiscover = false;

  // ── Progress State ────────────────────────────────────────────────

  List<CollaborativeProgress> todayProgress = [];
  bool isLoadingProgress = false;

  // ── Members State ─────────────────────────────────────────────────

  List<CollaborativeHabitMember> members = [];
  bool isLoadingMembers = false;

  // ── Feed State ────────────────────────────────────────────────────

  List<GTActivityLog> activityFeed = [];
  List<GTActivityLog> globalFeed = [];
  bool isLoadingFeed = false;
  int _feedPage = 1;
  bool hasMoreFeed = true;

  // ── Leaderboard State ─────────────────────────────────────────────

  List<LeaderboardEntry> leaderboard = [];
  bool isLoadingLeaderboard = false;

  // ── Milestones State ──────────────────────────────────────────────

  List<GTGroupMilestone> milestones = [];
  bool isLoadingMilestones = false;

  // ── Comments State ────────────────────────────────────────────────

  List<GTProgressComment> comments = [];
  bool isLoadingComments = false;

  // ── Streak Calendar State ─────────────────────────────────────────

  StreakCalendar? streakCalendar;
  bool isLoadingCalendar = false;

  // ── Streak Freeze State ───────────────────────────────────────────

  StreakFreezeInfo? freezeInfo;
  bool isLoadingFreezes = false;
  // ── Last Progress Result State (rich response) ────────────────

  ProgressResult? lastProgressResult;
  // ═══════════════════════════════════════════════════════════════
  //  DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  /// Loads the full Grow Together dashboard.
  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _svc.getDashboard();
      dashboard = GrowTogetherDashboard.fromJson(data);
      myHabits = dashboard!.myCollaborativeHabits;
      pendingInvites = dashboard!.pendingInvites;
      discoverableHabits = dashboard!.discoverableHabits;
    } catch (e) {
      error = 'Failed to load dashboard: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  HABITS CRUD
  // ═══════════════════════════════════════════════════════════════

  /// Lists all collaborative habits for the user.
  Future<void> loadMyHabits() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _svc.listHabits();
      final list = data['results'] as List<dynamic>? ?? [];
      myHabits = list
          .map((e) =>
              CollaborativeHabit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load habits: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a single collaborative habit detail.
  Future<void> loadHabitDetail(String id) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _svc.getHabit(id);
      selectedHabit = CollaborativeHabit.fromJson(
          data['habit'] as Map<String, dynamic>);
    } catch (e) {
      error = 'Failed to load habit: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new collaborative habit.
  Future<bool> createHabit({
    required String title,
    String description = '',
    String emoji = '🎯',
    String frequency = 'daily',
    List<int> customDays = const [],
    int targetCount = 1,
    String privacy = 'friends_only',
    int maxMembers = 50,
    int iconCode = 0xE87C,
    int colorValue = 0xFF4F46E5,
    int xpPerCompletion = 15,
    int bonusAllCompleteXp = 25,
    int? sourceHabitId,
  }) async {
    isActionLoading = true;
    actionMessage = null;
    notifyListeners();

    try {
      final data = await _svc.createHabit(
        title: title,
        description: description,
        emoji: emoji,
        frequency: frequency,
        customDays: customDays,
        targetCount: targetCount,
        privacy: privacy,
        maxMembers: maxMembers,
        iconCode: iconCode,
        colorValue: colorValue,
        xpPerCompletion: xpPerCompletion,
        bonusAllCompleteXp: bonusAllCompleteXp,
        sourceHabitId: sourceHabitId,
      );
      final habit = CollaborativeHabit.fromJson(
          data['habit'] as Map<String, dynamic>);
      myHabits.insert(0, habit);
      actionMessage = 'Collaborative habit created!';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to create habit: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INVITES
  // ═══════════════════════════════════════════════════════════════

  /// Sends invitations to friends for the given habit.
  Future<bool> sendInvites({
    required String habitId,
    required List<int> friendIds,
    String message = '',
  }) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.sendInvites(
          habitId: habitId, friendIds: friendIds, message: message);
      actionMessage = 'Invitations sent!';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to send invites: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Accepts an invitation.
  Future<bool> acceptInvite(String inviteId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.acceptInvite(inviteId);
      pendingInvites.removeWhere((i) => i.id == inviteId);
      actionMessage = 'Invitation accepted!';
      actionSuccess = true;
      notifyListeners();
      // Refresh habits list
      loadMyHabits();
      return true;
    } catch (e) {
      actionMessage = 'Failed to accept invite: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Declines an invitation.
  Future<bool> declineInvite(String inviteId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.declineInvite(inviteId);
      pendingInvites.removeWhere((i) => i.id == inviteId);
      actionMessage = 'Invitation declined.';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to decline invite: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Loads pending invitations.
  Future<void> loadPendingInvites() async {
    try {
      final data = await _svc.getMyInvites();
      final list = data['results'] as List<dynamic>? ?? [];
      pendingInvites = list
          .map((e) => HabitInvite.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      error = 'Failed to load invites: $e';
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROGRESS
  // ═══════════════════════════════════════════════════════════════

  /// Logs progress for a collaborative habit.
  /// Returns the rich [ProgressResult] on success.
  Future<bool> logProgress({
    required String habitId,
    String note = '',
    int completionCount = 1,
  }) async {
    isActionLoading = true;
    notifyListeners();

    try {
      final data = await _svc.logProgress(
        habitId: habitId,
        note: note,
        completionCount: completionCount,
      );
      final result = ProgressResult.fromJson(data);
      lastProgressResult = result;
      actionMessage = 'Progress logged! 🎉';
      actionSuccess = true;

      // Update local state with rich response
      if (selectedHabit != null && selectedHabit!.id == habitId) {
        selectedHabit = selectedHabit!.copyWith(
          totalCompletions: selectedHabit!.totalCompletions + 1,
          myStreak: result.streak.current,
          todayCompleted: true,
          groupCompletionPercent: result.groupStatus.percentage,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to log progress: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Loads today's progress for a collaborative habit.
  Future<void> loadTodayProgress(String habitId, {String? date}) async {
    isLoadingProgress = true;
    notifyListeners();

    try {
      final data = await _svc.getProgress(habitId, date: date);
      final list = data['results'] as List<dynamic>? ?? [];
      todayProgress = list
          .map((e) =>
              CollaborativeProgress.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load progress: $e';
    } finally {
      isLoadingProgress = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MEMBERS
  // ═══════════════════════════════════════════════════════════════

  /// Loads members of a collaborative habit.
  Future<void> loadMembers(String habitId) async {
    isLoadingMembers = true;
    notifyListeners();

    try {
      final data = await _svc.getMembers(habitId);
      final list = data['results'] as List<dynamic>? ?? [];
      members = list
          .map((e) => CollaborativeHabitMember.fromJson(
              e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load members: $e';
    } finally {
      isLoadingMembers = false;
      notifyListeners();
    }
  }

  /// Joins a public collaborative habit.
  Future<bool> joinHabit(String habitId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.joinHabit(habitId);
      actionMessage = 'Joined the habit!';
      actionSuccess = true;
      loadMyHabits();
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to join: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Leaves a collaborative habit.
  Future<bool> leaveHabit(String habitId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.leaveHabit(habitId);
      myHabits.removeWhere((h) => h.id == habitId);
      actionMessage = 'Left the habit.';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to leave: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Removes a member (owner/admin only).
  Future<bool> removeMember(String habitId, int userId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.removeMember(habitId, userId);
      members.removeWhere((m) => m.user.id == userId);
      actionMessage = 'Member removed.';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to remove member: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SOCIAL — Reactions & Comments
  // ═══════════════════════════════════════════════════════════════

  /// Toggles a reaction on a progress entry.
  Future<void> toggleReaction(String progressId, String type) async {
    try {
      await _svc.toggleReaction(progressId, type);
      // Refresh progress to reflect new reaction count
      if (selectedHabit != null) {
        loadTodayProgress(selectedHabit!.id);
      }
    } catch (e) {
      actionMessage = 'Failed to react: $e';
      actionSuccess = false;
      notifyListeners();
    }
  }

  /// Loads comments on a progress entry.
  Future<void> loadComments(String progressId) async {
    isLoadingComments = true;
    notifyListeners();

    try {
      final data = await _svc.getComments(progressId);
      final list = data['results'] as List<dynamic>? ?? [];
      comments = list
          .map((e) =>
              GTProgressComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load comments: $e';
    } finally {
      isLoadingComments = false;
      notifyListeners();
    }
  }

  /// Adds a comment on a progress entry.
  Future<bool> addComment(String progressId, String content) async {
    try {
      await _svc.addComment(progressId, content);
      loadComments(progressId);
      return true;
    } catch (e) {
      actionMessage = 'Failed to add comment: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FEED
  // ═══════════════════════════════════════════════════════════════

  /// Loads the activity feed for a specific habit.
  Future<void> loadHabitFeed(String habitId, {bool refresh = false}) async {
    if (refresh) {
      _feedPage = 1;
      activityFeed.clear();
      hasMoreFeed = true;
    }
    if (!hasMoreFeed) return;

    isLoadingFeed = true;
    notifyListeners();

    try {
      final data = await _svc.getHabitFeed(habitId, page: _feedPage);
      final list = data['results'] as List<dynamic>? ?? [];
      final newItems = list
          .map((e) => GTActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
      activityFeed.addAll(newItems);
      hasMoreFeed = newItems.length >= 30;
      _feedPage++;
    } catch (e) {
      error = 'Failed to load feed: $e';
    } finally {
      isLoadingFeed = false;
      notifyListeners();
    }
  }

  /// Loads the global activity feed.
  Future<void> loadGlobalFeed({bool refresh = false}) async {
    if (refresh) {
      globalFeed.clear();
    }

    isLoadingFeed = true;
    notifyListeners();

    try {
      final data = await _svc.getGlobalFeed();
      final list = data['results'] as List<dynamic>? ?? [];
      globalFeed = list
          .map((e) => GTActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load global feed: $e';
    } finally {
      isLoadingFeed = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEADERBOARD
  // ═══════════════════════════════════════════════════════════════

  /// Loads the weekly leaderboard for a collaborative habit.
  Future<void> loadLeaderboard(String habitId) async {
    isLoadingLeaderboard = true;
    notifyListeners();

    try {
      final data = await _svc.getLeaderboard(habitId);
      final list = data['results'] as List<dynamic>? ?? [];
      leaderboard = list
          .map((e) =>
              LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load leaderboard: $e';
    } finally {
      isLoadingLeaderboard = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MILESTONES
  // ═══════════════════════════════════════════════════════════════

  /// Loads group milestones for a collaborative habit.
  Future<void> loadMilestones(String habitId) async {
    isLoadingMilestones = true;
    notifyListeners();

    try {
      final data = await _svc.getMilestones(habitId);
      final list = data['results'] as List<dynamic>? ?? [];
      milestones = list
          .map((e) =>
              GTGroupMilestone.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to load milestones: $e';
    } finally {
      isLoadingMilestones = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  STREAK CALENDAR & FREEZES
  // ═══════════════════════════════════════════════════════════════

  /// Unmarks today's progress (undo completion).
  Future<bool> unmarkProgress({required String habitId}) async {
    isActionLoading = true;
    notifyListeners();

    try {
      final data = await _svc.unmarkProgress(habitId);
      actionMessage = 'Progress unmarked.';
      actionSuccess = true;

      // Update local state using copyWith
      if (selectedHabit != null && selectedHabit!.id == habitId) {
        final newStreak = data['currentStreak'] as int? ?? 0;
        selectedHabit = selectedHabit!.copyWith(
          totalCompletions: selectedHabit!.totalCompletions > 0
              ? selectedHabit!.totalCompletions - 1
              : 0,
          myStreak: newStreak,
          todayCompleted: false,
        );
      }

      lastProgressResult = null;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to unmark progress: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Loads the 30-day streak calendar for a collaborative habit.
  Future<void> loadStreakCalendar(String habitId, {int days = 30}) async {
    isLoadingCalendar = true;
    notifyListeners();

    try {
      final data = await _svc.getStreakCalendar(habitId, days: days);
      streakCalendar = StreakCalendar.fromJson(data);
    } catch (e) {
      error = 'Failed to load streak calendar: $e';
    } finally {
      isLoadingCalendar = false;
      notifyListeners();
    }
  }

  /// Loads streak freeze info for a collaborative habit.
  Future<void> loadStreakFreezes(String habitId) async {
    isLoadingFreezes = true;
    notifyListeners();

    try {
      final data = await _svc.getStreakFreezes(habitId);
      freezeInfo = StreakFreezeInfo.fromJson(data);
    } catch (e) {
      error = 'Failed to load streak freezes: $e';
    } finally {
      isLoadingFreezes = false;
      notifyListeners();
    }
  }

  /// Purchases a streak freeze token using XP.
  Future<bool> purchaseStreakFreeze(String habitId) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.buyStreakFreeze(habitId);
      actionMessage = 'Streak freeze purchased! ❄️';
      actionSuccess = true;
      // Refresh freeze info
      loadStreakFreezes(habitId);
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to purchase freeze: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  /// Uses a streak freeze to protect a missed day.
  Future<bool> useStreakFreeze(String habitId, {String? date}) async {
    isActionLoading = true;
    notifyListeners();

    try {
      final data = await _svc.useStreakFreeze(habitId, date: date);
      final newStreak = data['newStreak'] as int? ?? selectedHabit?.myStreak ?? 0;
      actionMessage = 'Streak freeze used! Your streak is protected. 🛡️';
      actionSuccess = true;

      // Update local streak using copyWith
      if (selectedHabit != null && selectedHabit!.id == habitId) {
        selectedHabit = selectedHabit!.copyWith(myStreak: newStreak);
      }

      // Refresh calendar + freezes
      loadStreakCalendar(habitId);
      loadStreakFreezes(habitId);
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to use freeze: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISCOVER
  // ═══════════════════════════════════════════════════════════════

  /// Discovers public collaborative habits.
  Future<void> loadDiscoverHabits({int limit = 20}) async {
    isLoadingDiscover = true;
    notifyListeners();

    try {
      final data = await _svc.discoverHabits(limit: limit);
      final list = data['results'] as List<dynamic>? ?? [];
      discoverableHabits = list
          .map((e) =>
              CollaborativeHabit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = 'Failed to discover habits: $e';
    } finally {
      isLoadingDiscover = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MODERATION
  // ═══════════════════════════════════════════════════════════════

  /// Reports abuse in a collaborative habit.
  Future<bool> reportAbuse({
    required String habitId,
    required int reportedUserId,
    required String reason,
    required String description,
  }) async {
    isActionLoading = true;
    notifyListeners();

    try {
      await _svc.reportAbuse(
        habitId: habitId,
        reportedUserId: reportedUserId,
        reason: reason,
        description: description,
      );
      actionMessage = 'Report submitted. Thank you.';
      actionSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      actionMessage = 'Failed to submit report: $e';
      actionSuccess = false;
      notifyListeners();
      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  UTILITIES
  // ═══════════════════════════════════════════════════════════════

  /// Clears the action message (call after showing snackbar).
  void clearActionMessage() {
    actionMessage = null;
    notifyListeners();
  }
}
