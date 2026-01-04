import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../models/reminder.dart';

/// ===============================================================
/// HomeController
/// ===============================================================
///
/// Acts as the business logic and state manager for the Home Screen.
///
/// Responsibilities:
/// - Manages user-related data (name, streak)
/// - Handles habit list operations (add, update, delete, toggle)
/// - Calculates daily progress and completion stats
/// - Manages navigation state
/// - Notifies UI when data changes
///
/// Architecture:
/// - Follows MVVM / Controller-based approach
/// - Uses ChangeNotifier for reactive UI updates
///
/// Used with:
/// - Provider or ChangeNotifierProvider
/// - HomePage UI widgets
/// ===============================================================
class HomeController extends ChangeNotifier {
  /// ---------------------------------------------------------------
  /// User Information
  /// ---------------------------------------------------------------
  String userName = "Nikita";
  int currentStreak = 12;

  /// ---------------------------------------------------------------
  /// Progress Tracking
  /// ---------------------------------------------------------------
  double todayProgress = 0.0;
  int completedHabits = 0;
  int totalHabits = 0;

  /// ---------------------------------------------------------------
  /// Bottom Navigation State
  /// ---------------------------------------------------------------
  int selectedIndex = 0;

  /// ---------------------------------------------------------------
  /// Data Collections
  /// ---------------------------------------------------------------
  List<Habit> todayHabits = [];
  List<Reminder> upcomingReminders = [];

  /// ---------------------------------------------------------------
  /// Constructor
  /// ---------------------------------------------------------------
  ///
  /// Initializes the controller with sample data.
  /// In production, this can be replaced with:
  /// - API calls
  /// - Local database retrieval
  HomeController() {
    _initializeSampleData();
  }

  /// ---------------------------------------------------------------
  /// Initialize Sample Data
  /// ---------------------------------------------------------------
  ///
  /// Temporary hardcoded data used for UI development
  /// and testing purposes.
  void _initializeSampleData() {
    todayHabits = [
      Habit(
        id: '1',
        title: 'Morning Meditation',
        time: '6:00 AM',
        category: 'Mindfulness',
        icon: Icons.self_improvement,
        color: const Color(0xFFF59E0B),
        isCompleted: true,
      ),
      Habit(
        id: '2',
        title: 'Read for 30 minutes',
        time: '7:30 AM',
        category: 'Learning',
        icon: Icons.menu_book,
        color: const Color(0xFF8B5CF6),
        isCompleted: true,
      ),
      Habit(
        id: '3',
        title: 'Drink 8 Glasses Water',
        time: '8:00 AM',
        category: 'Health',
        icon: Icons.local_drink,
        color: const Color(0xFF3B82F6),
        isCompleted: false,
      ),
      Habit(
        id: '4',
        title: 'Exercise',
        time: '6:30 PM',
        category: 'Fitness',
        icon: Icons.fitness_center,
        color: const Color(0xFFEC4899),
        isCompleted: false,
      ),
      Habit(
        id: '5',
        title: 'Journal',
        time: '9:00 PM',
        category: 'Mindfulness',
        icon: Icons.edit_note,
        color: const Color(0xFF8B5CF6),
        isCompleted: false,
      ),
    ];

    upcomingReminders = [
      Reminder(
        title: 'Drink Water',
        time: 'In 15 minutes',
        icon: Icons.local_drink,
        color: const Color(0xFF3B82F6),
      ),
      Reminder(
        title: 'Exercise',
        time: 'In 2 hours',
        icon: Icons.fitness_center,
        color: const Color(0xFFEC4899),
      ),
      Reminder(
        title: 'Journal',
        time: 'At 9:00 PM',
        icon: Icons.edit_note,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    _updateProgress();
  }

  /// ---------------------------------------------------------------
  /// Toggle Habit Completion Status
  /// ---------------------------------------------------------------
  ///
  /// Marks a habit as completed or incomplete
  /// and recalculates progress.
  void toggleHabit(int index) {
    if (index >= 0 && index < todayHabits.length) {
      todayHabits[index].isCompleted =
          !todayHabits[index].isCompleted;
      _updateProgress();
      notifyListeners();
    }
  }

  /// ---------------------------------------------------------------
  /// Update Progress Metrics
  /// ---------------------------------------------------------------
  ///
  /// Calculates:
  /// - Total habits
  /// - Completed habits
  /// - Daily progress percentage
  void _updateProgress() {
    totalHabits = todayHabits.length;
    completedHabits =
        todayHabits.where((h) => h.isCompleted).length;
    todayProgress =
        totalHabits > 0 ? completedHabits / totalHabits : 0.0;
  }

  /// ---------------------------------------------------------------
  /// Add New Habit
  /// ---------------------------------------------------------------
  ///
  /// Adds a habit to today's list and updates progress.
  void addHabit(Habit habit) {
    todayHabits.add(habit);
    _updateProgress();
    notifyListeners();
  }

  /// ---------------------------------------------------------------
  /// Update Existing Habit
  /// ---------------------------------------------------------------
  ///
  /// Replaces an existing habit using its unique ID.
  void updateHabit(String id, Habit updatedHabit) {
    final index = todayHabits.indexWhere((h) => h.id == id);
    if (index != -1) {
      todayHabits[index] = updatedHabit;
      _updateProgress();
      notifyListeners();
    }
  }

  /// ---------------------------------------------------------------
  /// Delete Habit
  /// ---------------------------------------------------------------
  ///
  /// Removes a habit permanently from the list.
  void deleteHabit(String id) {
    todayHabits.removeWhere((h) => h.id == id);
    _updateProgress();
    notifyListeners();
  }

  /// ---------------------------------------------------------------
  /// Change Bottom Navigation Index
  /// ---------------------------------------------------------------
  ///
  /// Updates the selected navigation tab.
  void changeNavigationIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  /// ---------------------------------------------------------------
  /// Get Habit by ID
  /// ---------------------------------------------------------------
  ///
  /// Returns a habit if found, otherwise null.
  Habit? getHabitById(String id) {
    try {
      return todayHabits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }
}
