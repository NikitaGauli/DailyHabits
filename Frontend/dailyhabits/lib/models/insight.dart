import 'package:flutter/material.dart';

class Insight {
  final String type;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String priority;
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

class MotivationalQuote {
  final String quote;
  final String author;
  final String category;

  MotivationalQuote({
    required this.quote,
    required this.author,
    required this.category,
  });

  factory MotivationalQuote.fromJson(Map<String, dynamic> json) {
    return MotivationalQuote(
      quote: json['quote'],
      author: json['author'],
      category: json['category'],
    );
  }
}

class Recommendation {
  final String type;
  final String title;
  final String message;
  final int? habitId;
  final String? actionType;

  Recommendation({
    required this.type,
    required this.title,
    required this.message,
    this.habitId,
    this.actionType,
  });

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
