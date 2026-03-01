// ==========================================================================
// Achievement Model — Gamification & Progression Data
// ==========================================================================
//
// This file defines the data models for the achievement / gamification
// subsystem of DailyHabits:
//
// - [Achievement] — A single earnable achievement with rarity, points,
//   and user-specific unlock status.
// - [UserLevel] — The user’s current XP level, progress, and total
//   achievement count.
//
// Both models are deserialized from the backend achievements API and
// consumed by the Achievements screen and profile summary widgets.
// ==========================================================================

import 'package:flutter/material.dart';

// ==========================================================================
// Achievement Model
// ==========================================================================

/// Represents an individual achievement that a user can earn.
///
/// Achievements are categorized by [type] (e.g., streak, completion) and
/// [rarity] (common, rare, epic, legendary). Each carries [points] that
/// contribute to the user’s overall XP and level progression.
///
/// The [isEarned] flag and [earnedAt] timestamp indicate whether the
/// current user has unlocked the achievement, while [earnedValue] tracks
/// the user’s progress toward [targetValue].
class Achievement {
  /// Unique identifier for the achievement.
  final int id;

  /// Human-readable name displayed in the UI (e.g., "Week Warrior").
  final String name;

  /// Short description explaining how to earn this achievement.
  final String description;

  /// Achievement category — e.g., `"streak"`, `"completion"`, `"general"`.
  final String type;

  /// Rarity tier — `"common"`, `"rare"`, `"epic"`, or `"legendary"`.
  final String rarity;

  /// XP points awarded when the achievement is earned.
  final int points;

  /// Icon displayed alongside the achievement in the UI.
  final IconData icon;

  /// Accent color used for the achievement badge.
  final Color color;

  /// The numeric target required to earn this achievement.
  final int targetValue;

  // ---- User-specific status ----

  /// Whether the current user has earned this achievement.
  final bool isEarned;

  /// Timestamp when the user earned the achievement, or `null` if not earned.
  final DateTime? earnedAt;

  /// The user’s current progress value toward [targetValue].
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

  /// Deserializes an [Achievement] from a JSON map returned by the API.
  ///
  /// Missing fields fall back to safe defaults so that partially-populated
  /// responses (e.g., for locked achievements) are handled gracefully.
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

// ==========================================================================
// User Level Model
// ==========================================================================

/// Represents the user’s current gamification level and XP progress.
///
/// Used by the profile header and achievements screen to display the
/// user’s rank, current XP bar, and total achievements earned.
class UserLevel {
  /// The user’s numeric level (starts at 1).
  final int currentLevel;

  /// Descriptive name for the current level (e.g., "Beginner", "Expert").
  final String levelName;

  /// XP accumulated at the current level.
  final int currentXp;

  /// Total lifetime XP earned across all levels.
  final int totalXp;

  /// XP required to advance to the next level.
  final int xpForNextLevel;

  /// Progress toward the next level as a percentage (0.0 – 100.0).
  final double xpProgressPercentage;

  /// Total number of achievements unlocked by the user.
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

  /// Deserializes a [UserLevel] from a JSON map returned by the API.
  ///
  /// All fields default to safe starting values so a fresh user without
  /// any XP history still receives a valid [UserLevel] instance.
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
