// =============================================================================
// File: shared_habit.dart
// Description: Data models for the habit sharing feature — shared habits,
//              emoji reactions, and comments.
// =============================================================================

import 'package:flutter/material.dart';

// =============================================================================
// Shared Habit Model
// =============================================================================

/// Represents a habit that has been shared with the current user by a friend.
///
/// Parsed from the `/social/shared-habits/shared-with-me/` API response.
/// Includes the source habit's metadata, the sharer's profile, interaction
/// permissions, and aggregate reaction / comment counts.
class SharedHabit {
  final int id;
  final int habitId;
  final String habitTitle;
  final String habitDescription;
  final String categoryName;
  final int iconCode;
  final int colorValue;
  final String visibility;
  final int currentStreak;
  final int bestStreak;
  final SharedByUser sharedBy;
  final DateTime sharedAt;
  final bool canComment;
  final bool canReact;
  final Map<String, int> reactions;
  final int commentCount;

  SharedHabit({
    required this.id,
    required this.habitId,
    required this.habitTitle,
    this.habitDescription = '',
    this.categoryName = '',
    this.iconCode = 0xE87C,
    this.colorValue = 0xFF4F46E5,
    this.visibility = 'friends_only',
    this.currentStreak = 0,
    this.bestStreak = 0,
    required this.sharedBy,
    required this.sharedAt,
    this.canComment = true,
    this.canReact = true,
    this.reactions = const {},
    this.commentCount = 0,
  });

  /// The Material icon for this habit.
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  /// The UI colour for this habit.
  Color get color => Color(colorValue);

  /// Total reaction count across all types.
  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);

  /// Deserialises from the backend JSON payload.
  factory SharedHabit.fromJson(Map<String, dynamic> json) {
    final reactionsRaw = json['reactions'] as Map<String, dynamic>? ?? {};
    final reactionsMap = reactionsRaw.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    return SharedHabit(
      id: json['id'],
      habitId: json['habitId'],
      habitTitle: json['habitTitle'] ?? '',
      habitDescription: json['habitDescription'] ?? '',
      categoryName: json['categoryName'] ?? '',
      iconCode: json['iconCode'] ?? 0xE87C,
      colorValue: json['colorValue'] ?? 0xFF4F46E5,
      visibility: json['visibility'] ?? 'friends_only',
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      sharedBy: SharedByUser.fromJson(json['sharedBy'] ?? {}),
      sharedAt: DateTime.parse(
        json['sharedAt'] ?? DateTime.now().toIso8601String(),
      ),
      canComment: json['canComment'] ?? true,
      canReact: json['canReact'] ?? true,
      reactions: reactionsMap,
      commentCount: json['commentCount'] ?? 0,
    );
  }
}

// =============================================================================
// Shared-By User (mini profile)
// =============================================================================

/// Lightweight user profile embedded in a [SharedHabit].
class SharedByUser {
  final int id;
  final String name;

  const SharedByUser({required this.id, required this.name});

  factory SharedByUser.fromJson(Map<String, dynamic> json) {
    return SharedByUser(id: json['id'] ?? 0, name: json['name'] ?? 'Unknown');
  }
}

// =============================================================================
// Habit Reaction Model
// =============================================================================

/// A single emoji reaction on a shared habit.
///
/// Five supported types: `like`, `encourage`, `celebrate`, `fire`, `clap`.
class HabitReaction {
  final int id;
  final String reactionType;
  final int userId;
  final String userName;
  final DateTime createdAt;

  HabitReaction({
    required this.id,
    required this.reactionType,
    this.userId = 0,
    this.userName = '',
    required this.createdAt,
  });

  /// Emoji glyph for this reaction type.
  String get emoji {
    switch (reactionType) {
      case 'like':
        return '👍';
      case 'encourage':
        return '💪';
      case 'celebrate':
        return '🎉';
      case 'fire':
        return '🔥';
      case 'clap':
        return '👏';
      default:
        return '👍';
    }
  }

  factory HabitReaction.fromJson(Map<String, dynamic> json) {
    return HabitReaction(
      id: json['id'] ?? 0,
      reactionType: json['reactionType'] ?? 'like',
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// =============================================================================
// Habit Comment Model
// =============================================================================

/// A comment on a shared habit.
class HabitComment {
  final int id;
  final String authorName;
  final int authorId;
  final String content;
  final DateTime createdAt;

  HabitComment({
    required this.id,
    this.authorName = '',
    this.authorId = 0,
    required this.content,
    required this.createdAt,
  });

  factory HabitComment.fromJson(Map<String, dynamic> json) {
    return HabitComment(
      id: json['id'] ?? 0,
      authorName: json['authorName'] ?? json['author'] ?? '',
      authorId: json['authorId'] ?? 0,
      content: json['content'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
