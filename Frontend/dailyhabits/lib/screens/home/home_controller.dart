import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../services/habit_service.dart';
import '../../services/auth_service.dart';
import '../../models/reminder.dart';

class HomeController extends ChangeNotifier {
  String userName = "User";
  int currentStreak = 0;
  int bestStreak = 0;
  double todayProgress = 0.0;
  int completedHabits = 0;
  int totalHabits = 0;
  int selectedIndex = 0;
  List<Habit> todayHabits = [];
  List<Habit> allHabits = [];
  List<Reminder> upcomingReminders = [];
  Map<String, int> categoryMap = {};
  String? selectedCategory;

  final HabitService _habitService = HabitService();
  final AuthService _authService = AuthService();

  bool isLoading = true;
  Map<String, dynamic> summary = {};

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

  void selectCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

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

  /// Skip Habit
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

  void _updateProgress() {
    totalHabits = todayHabits.length;
    completedHabits = todayHabits.where((h) => h.isCompleted).length;
    todayProgress = totalHabits > 0 ? completedHabits / totalHabits : 0.0;
  }

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

  Future<void> updateExistingHabit(Habit updatedHabit) async {
    try {
      await _habitService.updateHabit(updatedHabit);
      await loadData();
    } catch (e) {
      debugPrint('Update error: $e');
      rethrow;
    }
  }

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

  void changeNavigationIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  Habit? getHabitById(String id) {
    try {
      return todayHabits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

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

  Future<void> logout() async {
    reset();
    await _authService.logout();
    notifyListeners();
  }
}
