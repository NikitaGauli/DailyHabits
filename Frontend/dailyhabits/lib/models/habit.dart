import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Habit Model
/// ---------------------------------------------------------------------------
/// Represents a single user habit within the DailyHabits application.
///
/// Design Intent:
/// • Acts as a domain/entity model for habits
/// • Keeps UI concerns minimal while remaining Flutter-friendly
/// • Supports future persistence via JSON serialization
///
/// Usage:
/// • Display habits in UI lists
/// • Track completion status
/// • Sync with local storage or backend APIs
/// ---------------------------------------------------------------------------
class Habit {
  /// Unique identifier for the habit
  final String id;

  /// Display title of the habit (e.g., "Morning Meditation")
  final String title;

  /// Scheduled time or time label (e.g., "6:00 AM")
  final String time;

  /// Logical grouping/category (e.g., Health, Mindfulness)
  final String category;

  /// Icon representing the habit visually in the UI
  final IconData icon;

  /// Primary color used for styling the habit
  final Color color;

  /// Completion state for the current day
  bool isCompleted;

  /// Creates a new [Habit] instance.
  ///
  /// [isCompleted] defaults to false to represent a fresh daily habit.
  Habit({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    required this.icon,
    required this.color,
    this.isCompleted = false,
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Creates a [Habit] instance from a JSON map.
  ///
  /// This method is intended for:
  /// • Local storage (SharedPreferences / SQLite)
  /// • Remote APIs (REST / Firebase)
  ///
  /// Icon and color values are reconstructed using their raw integer values.
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      title: json['title'],
      time: json['time'],
      category: json['category'],
      icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  /// Converts the [Habit] instance into a JSON-compatible map.
  ///
  /// Useful for:
  /// • Saving habit state
  /// • Syncing data with backend services
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'category': category,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'isCompleted': isCompleted,
    };
  }

  // ---------------------------------------------------------------------------
  // Copy Utility
  // ---------------------------------------------------------------------------

  /// Creates a new [Habit] instance by copying the current one
  /// and selectively overriding provided fields.
  ///
  /// Commonly used for:
  /// • Immutable state updates
  /// • Toggling completion status
  /// • Editing habit details safely
  Habit copyWith({
    String? id,
    String? title,
    String? time,
    String? category,
    IconData? icon,
    Color? color,
    bool? isCompleted,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
