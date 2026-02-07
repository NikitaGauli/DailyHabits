import 'package:flutter/material.dart';

class Achievement {
  final int id;
  final String name;
  final String description;
  final String type; // streak, completion, etc.
  final String rarity; // common, rare, epic, legendary
  final int points;
  final IconData icon;
  final Color color;
  final int targetValue;

  // User status
  final bool isEarned;
  final DateTime? earnedAt;
  final int earnedValue;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
    required this.points,
    required this.icon,
    required this.color,
    required this.targetValue,
    this.isEarned = false,
    this.earnedAt,
    this.earnedValue = 0,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'] ?? 'general',
      rarity: json['rarity'] ?? 'common',
      points: json['points'] ?? 0,
      icon: IconData(json['iconCode'] ?? 0xE87C, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFFFFD700),
      targetValue: json['targetValue'] ?? 0,

      // User specific
      isEarned: json['isEarned'] ?? false,
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'])
          : null,
      earnedValue: json['earnedValue'] ?? 0,
    );
  }
}

class UserLevel {
  final int currentLevel;
  final String levelName;
  final int currentXp;
  final int totalXp;
  final int xpForNextLevel;
  final double xpProgressPercentage;
  final int totalAchievements;

  UserLevel({
    required this.currentLevel,
    required this.levelName,
    required this.currentXp,
    required this.totalXp,
    required this.xpForNextLevel,
    required this.xpProgressPercentage,
    required this.totalAchievements,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      currentLevel: json['currentLevel'] ?? 1,
      levelName: json['levelName'] ?? 'Beginner',
      currentXp: json['currentXp'] ?? 0,
      totalXp: json['totalXp'] ?? 0,
      xpForNextLevel: json['xpForNextLevel'] ?? 100,
      xpProgressPercentage: (json['xpProgressPercentage'] ?? 0).toDouble(),
      totalAchievements: json['totalAchievements'] ?? 0,
    );
  }
}
