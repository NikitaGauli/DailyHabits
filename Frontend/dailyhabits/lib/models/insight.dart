// ==========================================================================
// Insight Models — Smart Insights, Quotes & Recommendations
// ==========================================================================
//
// This file defines the data models for the Insights feature:
//
// - [Insight] — An AI-generated or rule-based insight surfaced to the user.
// - [MotivationalQuote] — A curated quote with author and category metadata.
// - [Recommendation] — A personalized action suggestion for improving habits.
//
// All models are deserialized from the backend insights API and rendered
// on the Insights screen, home dashboard cards, and notification payloads.
// ==========================================================================

import 'package:flutter/material.dart';

// ==========================================================================
// Insight Model
// ==========================================================================

/// An actionable insight derived from the user’s habit data.
///
/// Insights are typed (e.g., trend, warning, encouragement) and carry a
/// [priority] that determines their display order. An optional [habitId]
/// links the insight to a specific habit for contextual navigation.
class Insight {
  /// The insight category — e.g., `"trend"`, `"warning"`, `"tip"`.
  final String type;

  /// Short headline summarizing the insight.
  final String title;

  /// Full descriptive message explaining the insight.
  final String message;

  /// Material icon displayed alongside the insight card.
  final IconData icon;

  /// Accent color for the insight card background or border.
  final Color color;

  /// Display priority — `"high"`, `"medium"`, or `"low"`.
  final String priority;

  /// Optional ID of the related habit, used for deep-linking.
  final int? habitId;

  Insight({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.priority,
    this.habitId,
  });

  /// Deserializes an [Insight] from a JSON map returned by the API.
  ///
  /// The [icon] and [color] fall back to informational defaults when the
  /// backend does not provide explicit visual metadata.
  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      type: json['type'],
      title: json['title'],
      message: json['message'],
      icon: IconData(json['iconCode'] ?? 0xE88E, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFF3B82F6),
      priority: json['priority'] ?? 'medium',
      habitId: json['habitId'],
    );
  }
}

// ==========================================================================
// Motivational Quote Model
// ==========================================================================

/// A motivational quote displayed to encourage and inspire the user.
///
/// Quotes are categorized (e.g., "persistence", "growth") so the app can
/// filter or rotate them based on the user’s current habit performance.
class MotivationalQuote {
  /// The quote text itself.
  final String quote;

  /// Attribution — the person credited with the quote.
  final String author;

  /// Thematic category used for filtering (e.g., "motivation", "growth").
  final String category;

  MotivationalQuote({
    required this.quote,
    required this.author,
    required this.category,
  });

  /// Deserializes a [MotivationalQuote] from a JSON map.
  factory MotivationalQuote.fromJson(Map<String, dynamic> json) {
    return MotivationalQuote(
      quote: json['quote'],
      author: json['author'],
      category: json['category'],
    );
  }
}

// ==========================================================================
// Recommendation Model
// ==========================================================================

/// A personalized recommendation suggesting an action to improve a habit.
///
/// Recommendations may target a specific habit via [habitId] and include an
/// [actionType] (e.g., `"reschedule"`, `"reduce_target"`) that the UI can
/// use to present a one-tap action button.
class Recommendation {
  /// The recommendation category — e.g., `"schedule"`, `"difficulty"`.
  final String type;

  /// Short headline for the recommendation card.
  final String title;

  /// Detailed explanation or rationale for the suggestion.
  final String message;

  /// Optional ID of the habit this recommendation relates to.
  final int? habitId;

  /// Optional machine-readable action identifier for one-tap actions.
  final String? actionType;

  Recommendation({
    required this.type,
    required this.title,
    required this.message,
    this.habitId,
    this.actionType,
  });

  /// Deserializes a [Recommendation] from a JSON map.
  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: json['type'],
      title: json['title'],
      message: json['message'],
      habitId: json['habitId'],
      actionType: json['actionType'],
    );
  }
}
