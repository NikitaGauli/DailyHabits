// **home_controller.dart** — Business Logic Controller for the Home Screen
//
// This file contains [HomeController], the central [ChangeNotifier] that
// manages all state and business logic for the home dashboard.
//
// Responsibilities include:
//   - Fetching and caching the authenticated user profile.
//   - Loading today's habits, progress metrics, and streak data.
//   - Providing filtered habit lists via category selection.
//   - Toggling habit completion and propagating server responses.
//   - Computing upcoming reminders from habit reminder times.
//   - Managing bottom-navigation tab state.
//   - Coordinating the logout/reset cycle to ensure clean state
//     transitions between user sessions.
//
// **Important:** [HomeController] is registered as a singleton via
// `ChangeNotifierProvider` at app startup. Because it outlives individual
// login sessions, `loadData()` must NOT be called in its constructor
// (there is no auth token yet at that point). Instead, it is invoked from
// `HomePage.initState()` after the user has been authenticated.
//
// See also:
//   - [HomePage] for the UI that consumes this controller.
//   - [HabitService] for REST API interactions.
//   - [AuthService] for authentication and token management.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../services/habit_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../models/reminder.dart';

// =============================================================================
// HomeController
// =============================================================================

/// The primary state-management controller for the home screen.
///
/// Extends [ChangeNotifier] so that widgets wrapped in [Consumer] or
/// `context.watch<HomeController>()` automatically rebuild when data changes.
///
/// This controller is intentionally a **singleton** within the widget tree.
/// It does **not** call [loadData] in its constructor because the auth token
/// may not yet be available.
class HomeController extends ChangeNotifier {
  // ===========================================================================
  // Public State Fields
  // ===========================================================================

  /// Display name of the currently authenticated user.
  String userName = "User";

  /// Number of consecutive days the user has completed all habits.
  int currentStreak = 0;

  /// The user's all-time best streak in days.
  int bestStreak = 0;

  /// Fraction of today's habits that have been completed (0.0 – 1.0).
  double todayProgress = 0.0;

  /// Count of habits marked as completed today.
  int completedHabits = 0;

  /// Total number of habits scheduled for today.
  int totalHabits = 0;

  /// Index of the currently selected bottom-navigation tab.
  int selectedIndex = 0;

  /// Habits specifically scheduled for today.
  List<Habit> todayHabits = [];

  /// Complete list of the user's habits (used in "All Habits" views).
  List<Habit> allHabits = [];

  /// Chronologically sorted list of upcoming reminders for today.
  List<Reminder> upcomingReminders = [];

  /// Map of category names to their habit counts.
  Map<String, int> categoryMap = {};

  /// Currently active category filter; `null` or `'All'` shows everything.
  String? selectedCategory;

  // ===========================================================================
  // Private Dependencies
  // ===========================================================================

  /// Service layer for habit CRUD and toggle operations.
  final HabitService _habitService = HabitService();

  /// Service layer for authentication, user profile, and token management.
  final AuthService _authService = AuthService();

  /// Whether the controller is currently performing an async data load.
  bool isLoading = true;

  /// Raw summary map returned by the habits API (streaks, categories, etc.).
  Map<String, dynamic> summary = {};

  // ===========================================================================
  // Computed Properties
  // ===========================================================================

  /// Filtered habits based on selected category
  List<Habit> get filteredHabits {
    if (selectedCategory == null || selectedCategory == 'All') {
      return todayHabits;
    }
    return todayHabits.where((h) => h.category == selectedCategory).toList();
  }

  /// Category list for filter chips
  List<String> get categories {
    final cats = <String>['All'];
    for (final h in todayHabits) {
      if (!cats.contains(h.category)) cats.add(h.category);
    }
    return cats;
  }

  // NOTE: Do NOT call loadData() in the constructor.
  // The controller is a singleton Provider created at app startup (main.dart),
  // BEFORE any user is logged in. loadData() must only be called after
  // the auth token is set — i.e. when HomePage.initState() fires.
  HomeController();

  // ===========================================================================
  // Category Selection
  // ===========================================================================

  /// Updates the active category filter and triggers a UI rebuild.
  void selectCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

  // ===========================================================================
  // Data Loading
  // ===========================================================================

  /// Fetches the authenticated user's profile, today's habits, all habits,
  /// streak/summary metrics, and upcoming reminders from the backend.
  ///
  /// Called from `HomePage.initState()` and by pull-to-refresh.
  /// Sets [isLoading] to `true` at start and `false` when finished.
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();
    try {
      final user = await _authService.getUser();
      if (user != null && user['name'] != null) {
        userName = user['name'];
      }

      // Fetch today's habits
      final result = await _habitService.getTodayHabits();
      todayHabits = (result['habits'] as List<dynamic>?)?.cast<Habit>() ?? [];
      summary = result['summary'] ?? {};

      // Also fetch all habits for the "All Habits" view
      try {
        allHabits = await _habitService.getHabits();
      } catch (_) {
        allHabits = todayHabits;
      }

      // Update local metrics
      _updateProgress();

      // Update streak from summary
      if (summary.containsKey('currentStreak')) {
        currentStreak = summary['currentStreak'] is int
            ? summary['currentStreak']
            : (summary['currentStreak'] as num).toInt();
      }
      if (summary.containsKey('bestStreak')) {
        bestStreak = summary['bestStreak'] is int
            ? summary['bestStreak']
            : (summary['bestStreak'] as num).toInt();
      }
      if (summary.containsKey('categories')) {
        categoryMap = Map<String, int>.from(
          (summary['categories'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ),
        );
      }

      // Update upcoming reminders from habits
      _updateReminders();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Habit Actions
  // ===========================================================================

  /// Toggle Habit Completion Status
  Future<Map<String, dynamic>?> toggleHabitAsync(Habit habit) async {
    try {
      final response = await _habitService.toggleHabit(habit.id);

      if (response['success'] == true) {
        final isCompleted = response['isCompleted'] ?? false;
        final streak = response['currentStreak'];

        final index = todayHabits.indexWhere((h) => h.id == habit.id);
        if (index != -1) {
          todayHabits[index] = todayHabits[index].copyWith(
            isCompleted: isCompleted,
            completionState: isCompleted
                ? CompletionState.completed
                : CompletionState.pending,
            currentStreak: streak,
          );

          _updateProgress();
          notifyListeners();
        }

        return response;
      }
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
    return null;
  }

  /// Marks a habit as skipped with the given [reason].
  ///
  /// On success the full data set is reloaded to reflect the change.
  Future<void> skipHabitAsync(Habit habit, String reason) async {
    try {
      final success = await _habitService.skipHabit(habit.id, reason: reason);
      if (success) {
        await loadData();
      }
    } catch (e) {
      debugPrint('Skip error: $e');
    }
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  /// Recomputes [totalHabits], [completedHabits], and [todayProgress]
  /// based on the current state of [todayHabits].
  void _updateProgress() {
    totalHabits = todayHabits.length;
    completedHabits = todayHabits.where((h) => h.isCompleted).length;
    todayProgress = totalHabits > 0 ? completedHabits / totalHabits : 0.0;
  }

  /// Scans [todayHabits] for incomplete habits that have a future reminder
  /// time and populates [upcomingReminders] sorted chronologically.
  void _updateReminders() {
    upcomingReminders = [];
    final now = DateTime.now();
    final timeNow = TimeOfDay.fromDateTime(now);

    for (var h in todayHabits) {
      if (h.reminderEnabled && h.reminderTime != null && !h.isCompleted) {
        final rTime = h.reminderTime!;
        // Check if reminder is in the future today
        if (rTime.hour > timeNow.hour ||
            (rTime.hour == timeNow.hour && rTime.minute > timeNow.minute)) {
          final hour = rTime.hourOfPeriod == 0 ? 12 : rTime.hourOfPeriod;
          final period = rTime.period == DayPeriod.am ? 'AM' : 'PM';
          final minute = rTime.minute.toString().padLeft(2, '0');

          upcomingReminders.add(
            Reminder(
              title: h.title,
              time: '$hour:$minute $period',
              icon: h.icon,
              color: h.color,
            ),
          );
        }
      }
    }

    // Sort reminders by time
    upcomingReminders.sort((a, b) => a.time.compareTo(b.time));
  }

  // ===========================================================================
  // CRUD Operations
  // ===========================================================================

  /// Creates a new habit via the API and reloads data on success.
  ///
  /// Rethrows errors so that the UI layer can display user-facing messages.
  Future<void> addNewHabit(Habit habit) async {
    try {
      await _habitService.createHabit(habit);
      await loadData();
    } catch (e) {
      debugPrint('Add error: $e');
      rethrow; // Let the UI layer catch and display the error
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Persists updates to an existing habit and reloads data.
  ///
  /// Rethrows errors for UI-level handling.
  Future<void> updateExistingHabit(Habit updatedHabit) async {
    try {
      await _habitService.updateHabit(updatedHabit);
      await loadData();
    } catch (e) {
      debugPrint('Update error: $e');
      rethrow;
    }
  }

  /// Permanently deletes the habit with the given [id].
  ///
  /// Optimistically removes it from [todayHabits] and recalculates progress
  /// to provide immediate visual feedback.
  Future<void> removeHabit(String id) async {
    try {
      await _habitService.deleteHabit(id);
      todayHabits.removeWhere((h) => h.id == id);
      _updateProgress();
      notifyListeners();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  /// Switches the active bottom-navigation tab to [index].
  void changeNavigationIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  /// Finds and returns the habit matching [id], or `null` if not found.
  Habit? getHabitById(String id) {
    try {
      return todayHabits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // Session Lifecycle
  // ===========================================================================

  /// Clear all in-memory state so the next login starts fresh.
  void reset() {
    userName = 'User';
    currentStreak = 0;
    bestStreak = 0;
    todayProgress = 0.0;
    completedHabits = 0;
    totalHabits = 0;
    selectedIndex = 0;
    todayHabits = [];
    allHabits = [];
    upcomingReminders = [];
    categoryMap = {};
    selectedCategory = null;
    summary = {};
    isLoading = true;
    // Do NOT call notifyListeners() here — logout() will handle navigation.
  }

  /// Resets local state, revokes the auth token, and signs out of Google.
  ///
  /// The navigation to [LoginScreen] is handled by the calling UI layer
  /// (typically `_HomePageState._logout`).
  Future<void> logout() async {
    reset();
    // Sign out from Google if the user was authenticated via Google OAuth
    await GoogleAuthService().signOut();
    notifyListeners();
  }
}
