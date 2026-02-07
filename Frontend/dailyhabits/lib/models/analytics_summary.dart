class AnalyticsSummary {
  final int totalHabits;
  final int todayCompleted;
  final double todayRate;
  final int currentStreak;
  final int bestStreak;
  final double avgConsistency;
  final int weeklyCompletions;

  AnalyticsSummary({
    required this.totalHabits,
    required this.todayCompleted,
    required this.todayRate,
    required this.currentStreak,
    required this.bestStreak,
    required this.avgConsistency,
    required this.weeklyCompletions,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalHabits: json['totalHabits'] ?? 0,
      todayCompleted: json['todayCompleted'] ?? 0,
      todayRate: (json['todayRate'] ?? 0).toDouble(),
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      avgConsistency: (json['avgConsistency'] ?? 0).toDouble(),
      weeklyCompletions: json['weeklyCompletions'] ?? 0,
    );
  }
}

class WeeklyDataPoint {
  final String day;
  final DateTime date;
  final int completed;
  final int total;
  final double rate;
  final bool isToday;

  WeeklyDataPoint({
    required this.day,
    required this.date,
    required this.completed,
    required this.total,
    required this.rate,
    required this.isToday,
  });

  factory WeeklyDataPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyDataPoint(
      day: json['day'],
      date: DateTime.parse(json['date']),
      completed: json['completed'],
      total: json['total'],
      rate: (json['rate'] ?? 0).toDouble(),
      isToday: json['isToday'] ?? false,
    );
  }
}
