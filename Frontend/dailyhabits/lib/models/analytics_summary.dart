// ==========================================================================
// Analytics Summary Models — Dashboard Metrics & Weekly Data
// ==========================================================================
//
// This file contains the data models powering the Analytics dashboard:
//
// - [AnalyticsSummary] — High-level aggregate metrics (totals, rates,
//   streaks, and weekly completions).
// - [WeeklyDataPoint] — A single day’s data point within a 7-day chart,
//   used to render the weekly completion bar graph.
//
// Both models are deserialized from the backend analytics API.
// ==========================================================================

// ==========================================================================
// Analytics Summary
// ==========================================================================

// Aggregate metrics summarizing a user’s overall habit performance.
//
// Consumed by the Analytics dashboard header to display at-a-glance
// statistics such as completion rate, current streak, and consistency.
class AnalyticsSummary {
  // Total number of active habits the user is tracking.
  final int totalHabits;

  // Number of habits completed so far today.
  final int todayCompleted;

  // Today’s completion rate as a decimal (0.0 – 1.0).
  final double todayRate;

  // The user’s current consecutive-day streak across all habits.
  final int currentStreak;

  // The all-time best consecutive-day streak.
  final int bestStreak;

  // Average consistency percentage over the tracked period.
  final double avgConsistency;

  // Total completions recorded in the current week.
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

  // Deserializes an [AnalyticsSummary] from a JSON map.
  //
  // All numeric fields default to `0` (or `0.0`) when absent, keeping
  // the dashboard functional even before any habits are tracked.
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

// ==========================================================================
// Weekly Data Point
// ==========================================================================

// A single day’s data point within the weekly analytics chart.
//
// Contains the day label, completion counts, calculated rate, and a flag
// indicating whether this data point represents today (for visual emphasis).
class WeeklyDataPoint {
  // Abbreviated day label (e.g., "Mon", "Tue").
  final String day;

  // The calendar date this data point represents.
  final DateTime date;

  // Number of habits completed on this day.
  final int completed;

  // Total number of habits scheduled for this day.
  final int total;

  // Completion rate as a decimal (0.0 – 1.0).
  final double rate;

  // Whether this data point corresponds to the current day.
  final bool isToday;

  WeeklyDataPoint({
    required this.day,
    required this.date,
    required this.completed,
    required this.total,
    required this.rate,
    required this.isToday,
  });

  // Deserializes a [WeeklyDataPoint] from a JSON map.
  //
  // The [date] field is parsed from an ISO 8601 string; [rate] defaults
  // to `0.0` and [isToday] to `false` when not provided.
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
