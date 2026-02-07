import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// Completion State (replaces simple boolean isCompleted)
/// ---------------------------------------------------------------------------

enum CompletionState {
  pending,
  completed,
  skipped,
  missed;

  Color get color {
    switch (this) {
      case CompletionState.completed:
        return AppColors.success;   // #22C55E
      case CompletionState.skipped:
        return AppColors.warning;   // #F59E0B
      case CompletionState.missed:
        return AppColors.error;     // #EF4444
      case CompletionState.pending:
        return AppColors.lightTextMuted; // neutral gray
    }
  }

  IconData get icon {
    switch (this) {
      case CompletionState.completed:
        return Icons.check_circle_rounded;
      case CompletionState.skipped:
        return Icons.skip_next_rounded;
      case CompletionState.missed:
        return Icons.cancel_rounded;
      case CompletionState.pending:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  String get label {
    switch (this) {
      case CompletionState.completed:
        return 'Completed';
      case CompletionState.skipped:
        return 'Skipped';
      case CompletionState.missed:
        return 'Missed';
      case CompletionState.pending:
        return 'Pending';
    }
  }

  static CompletionState fromString(String? value) {
    switch (value) {
      case 'completed':
        return CompletionState.completed;
      case 'skipped':
        return CompletionState.skipped;
      case 'missed':
        return CompletionState.missed;
      default:
        return CompletionState.pending;
    }
  }
}

/// ---------------------------------------------------------------------------
/// Predefined Habit Categories
/// ---------------------------------------------------------------------------

class HabitCategory {
  final String name;
  final IconData icon;
  final Color color;

  const HabitCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<HabitCategory> predefined = [
    HabitCategory(
      name: 'Health',
      icon: Icons.favorite_rounded,
      color: AppColors.categoryHealth,
    ),
    HabitCategory(
      name: 'Fitness',
      icon: Icons.fitness_center_rounded,
      color: AppColors.categoryFitness,
    ),
    HabitCategory(
      name: 'Study',
      icon: Icons.menu_book_rounded,
      color: AppColors.categoryStudy,
    ),
    HabitCategory(
      name: 'Mindfulness',
      icon: Icons.self_improvement_rounded,
      color: AppColors.categoryMindfulness,
    ),
    HabitCategory(
      name: 'Productivity',
      icon: Icons.trending_up_rounded,
      color: AppColors.categoryProductivity,
    ),
    HabitCategory(
      name: 'Creativity',
      icon: Icons.palette_rounded,
      color: AppColors.categoryCreativity,
    ),
    HabitCategory(
      name: 'Social',
      icon: Icons.people_rounded,
      color: AppColors.categorySocial,
    ),
    HabitCategory(
      name: 'Custom',
      icon: Icons.star_rounded,
      color: AppColors.categoryCustom,
    ),
  ];

  static HabitCategory fromName(String name) {
    return predefined.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => predefined.last,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Motivation Messages (non-gamified, gentle encouragement)
/// ---------------------------------------------------------------------------

class MotivationMessages {
  MotivationMessages._();

  static const List<String> onCompleted = [
    'Well done — every step matters.',
    'One more checked off. Keep it up.',
    'Consistency builds real change.',
    'You showed up today. That counts.',
    'Progress, not perfection.',
    'Day by day, you\'re getting stronger.',
  ];

  static const List<String> onStreak = [
    'You\'re on a roll — keep steady.',
    'Consistency suits you.',
    'Day by day, it\'s adding up.',
    'Steady progress. Real strength.',
  ];

  static const List<String> afterMissed = [
    'One missed day. That\'s all. Start again now.',
    'Don\'t be hard on yourself. Tomorrow is fresh.',
    'Every expert started as a beginner.',
    'Stumbles happen. Getting back up is what counts.',
  ];

  static const List<String> dailyGreetings = [
    'What will you focus on today?',
    'A new day, a new chance.',
    'Small steps, big changes.',
    'Focus on progress today.',
    'Today is yours to shape.',
  ];

  static String random(List<String> pool) {
    return pool[DateTime.now().millisecond % pool.length];
  }
}
class Habit {
  final String id;
  final String title;
  final String? description;
  final String time;
  final String category; // categoryName from backend
  final IconData icon;
  final Color color;
  final String status;
  final String priority;

  // Scheduling
  final String frequency;
  final List<int> customDays;
  final int targetCount;
  final DateTime startDate;
  final DateTime? endDate;

  // Reminders
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;

  // Tracking (Computed properties from backend)
  bool isCompleted;
  CompletionState completionState;
  final int currentStreak;
  final int bestStreak;
  final Streak? streak; // Detailed streak info
  final HabitLog? todayLog; // Today's completion log

  Habit({
    required this.id,
    required this.title,
    this.description,
    required this.time,
    required this.category,
    required this.icon,
    required this.color,
    this.status = 'active',
    this.priority = 'medium',
    this.frequency = 'daily',
    this.customDays = const [],
    this.targetCount = 1,
    required this.startDate,
    this.endDate,
    this.reminderEnabled = false,
    this.reminderTime,
    this.isCompleted = false,
    this.completionState = CompletionState.pending,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.streak,
    this.todayLog,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'].toString(),
      title: json['title'],
      description: json['description'],
      time: json['time'] ?? '',
      category: json['categoryName'] ?? 'General',

      // Visuals
      icon: IconData(json['iconCode'] ?? 0xE87C, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFF4F46E5),

      // Status
      status: json['status'] ?? 'active',
      priority: json['priority'] ?? 'medium',

      // Scheduling
      frequency: json['frequency'] ?? 'daily',
      customDays: (json['customDays'] as List? ?? []).cast<int>(),
      targetCount: json['targetCount'] ?? 1,
      startDate: DateTime.parse(
        json['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,

      // Reminders
      reminderEnabled: json['reminderEnabled'] ?? false,
      reminderTime: json['reminderTime'] != null
          ? _parseTime(json['reminderTime'])
          : null,

      // Tracking
      isCompleted: json['isCompleted'] ?? false,
      completionState: CompletionState.fromString(
        json['completionState'] ?? (json['isCompleted'] == true ? 'completed' : null),
      ),
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      streak: json['streak'] != null ? Streak.fromJson(json['streak']) : null,
      todayLog: json['todayLog'] != null
          ? HabitLog.fromJson(json['todayLog'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'time': time,
      'categoryName': category,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'status': status,
      'priority': priority,
      'frequency': frequency,
      'customDays': customDays,
      'targetCount': targetCount,
      'reminderEnabled': reminderEnabled,
      'reminderTime': reminderTime != null
          ? '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
          : null,
    };
    // Only include id for existing habits (updates)
    if (id.isNotEmpty && id != '0') {
      map['id'] = int.tryParse(id);
    }
    return map;
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? time,
    String? category,
    IconData? icon,
    Color? color,
    String? status,
    String? priority,
    String? frequency,
    List<int>? customDays,
    int? targetCount,
    DateTime? startDate,
    DateTime? endDate,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool? isCompleted,
    CompletionState? completionState,
    int? currentStreak,
    int? bestStreak,
    Streak? streak,
    HabitLog? todayLog,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      targetCount: targetCount ?? this.targetCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completionState: completionState ?? this.completionState,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      streak: streak ?? this.streak,
      todayLog: todayLog ?? this.todayLog,
    );
  }
}

/// Detailed streak information
class Streak {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCompletedDate;
  final int totalCompletions;
  final int totalSkips;
  final int totalMisses;

  Streak({
    required this.currentStreak,
    required this.bestStreak,
    this.lastCompletedDate,
    required this.totalCompletions,
    required this.totalSkips,
    required this.totalMisses,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      currentStreak: json['current_streak'] ?? 0,
      bestStreak: json['best_streak'] ?? 0,
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'])
          : null,
      totalCompletions: json['total_completions'] ?? 0,
      totalSkips: json['total_skips'] ?? 0,
      totalMisses: json['total_misses'] ?? 0,
    );
  }
}

/// Daily log entry
class HabitLog {
  final int id;
  final String status; // completed, skipped, missed
  final CompletionState state;
  final DateTime? completedAt;
  final String? notes;
  final String? reflection;
  final String? mood;

  HabitLog({
    required this.id,
    required this.status,
    CompletionState? state,
    this.completedAt,
    this.notes,
    this.reflection,
    this.mood,
  }) : state = state ?? CompletionState.fromString(status);

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'],
      status: json['status'] ?? 'pending',
      state: CompletionState.fromString(json['status']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      notes: json['notes'],
      reflection: json['reflection'],
      mood: json['mood'],
    );
  }
}
