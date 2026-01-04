import 'package:flutter/material.dart';

/// ===============================================================
/// Reminder Model
/// ===============================================================
///
/// Represents a reminder associated with a habit.
///
/// This model is responsible for:
/// - Storing reminder-related data
/// - Providing UI representation (icon & color)
/// - Converting reminder data to and from JSON
///
/// Used across:
/// - Home Screen (Upcoming Reminders)
/// - Notification scheduling
/// - Local storage or backend synchronization
/// ===============================================================
class Reminder {
  /// Title or label of the reminder
  final String title;

  /// Scheduled reminder time (e.g., "7:00 AM")
  final String time;

  /// Icon representing the reminder visually
  final IconData icon;

  /// Color used for UI consistency
  final Color color;

  /// ---------------------------------------------------------------
  /// Constructor
  /// ---------------------------------------------------------------
  ///
  /// Creates a [Reminder] instance with required properties.
  Reminder({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });

  /// ---------------------------------------------------------------
  /// fromJson
  /// ---------------------------------------------------------------
  ///
  /// Factory constructor that creates a [Reminder] instance
  /// from a JSON map.
  ///
  /// Used when retrieving reminder data from:
  /// - Local database
  /// - API or backend service
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      title: json['title'],
      time: json['time'],
      icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue']),
    );
  }

  /// ---------------------------------------------------------------
  /// toJson
  /// ---------------------------------------------------------------
  ///
  /// Converts the [Reminder] object into a JSON-compatible map.
  ///
  /// Used for:
  /// - Saving reminders locally
  /// - Sending reminder data to backend services
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
    };
  }
}
