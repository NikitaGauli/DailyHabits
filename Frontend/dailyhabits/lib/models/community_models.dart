// =============================================================================
// File: community_models.dart
// Description: Data models for enhanced community & social features —
//              group challenges, encouragements, activity feed items,
//              and enriched group detail data.
// =============================================================================

import 'package:flutter/material.dart';

// =============================================================================
// Group Challenge Model
// =============================================================================

/// A challenge within a group that members work towards collectively.
///
/// Parsed from `/social/groups/{id}/challenges/` API responses.
class GroupChallenge {
  final int id;
  final String title;
  final String description;
  final String targetType; // 'completions', 'streak', 'all_done'
  final int targetValue;
  final int currentProgress;
  final double progressPercentage;
  final String status; // 'active', 'completed', 'expired'
  final DateTime startDate;
  final DateTime endDate;
  final int xpReward;
  final int coinReward;
  final int iconCode;
  final int colorValue;
  final String createdBy;
  final bool isActive;
  final DateTime createdAt;

  GroupChallenge({
    required this.id,
    required this.title,
    this.description = '',
    this.targetType = 'completions',
    this.targetValue = 50,
    this.currentProgress = 0,
    this.progressPercentage = 0.0,
    this.status = 'active',
    required this.startDate,
    required this.endDate,
    this.xpReward = 50,
    this.coinReward = 10,
    this.iconCode = 0xE87C,
    this.colorValue = 0xFF4F46E5,
    this.createdBy = '',
    this.isActive = true,
    required this.createdAt,
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  /// Days remaining until challenge expires.
  int get daysRemaining {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Target type as a human-readable label.
  String get targetTypeLabel {
    switch (targetType) {
      case 'completions':
        return 'Total Completions';
      case 'streak':
        return 'Best Streak';
      case 'all_done':
        return 'All Members Done';
      default:
        return targetType;
    }
  }

  /// Status chip color.
  Color get statusColor {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF6366F1);
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  factory GroupChallenge.fromJson(Map<String, dynamic> json) {
    return GroupChallenge(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetType: json['targetType'] ?? 'completions',
      targetValue: json['targetValue'] ?? 50,
      currentProgress: json['currentProgress'] ?? 0,
      progressPercentage: (json['progressPercentage'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      startDate: DateTime.parse(
        json['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: DateTime.parse(
        json['endDate'] ?? DateTime.now().toIso8601String(),
      ),
      xpReward: json['xpReward'] ?? 50,
      coinReward: json['coinReward'] ?? 10,
      iconCode: json['iconCode'] ?? 0xE87C,
      colorValue: json['colorValue'] ?? 0xFF4F46E5,
      createdBy: json['createdBy'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// =============================================================================
// Encouragement Model
// =============================================================================

/// A motivational nudge sent between friends.
///
/// Parsed from `/social/encouragements/` API responses.
class Encouragement {
  final int id;
  final MiniUser fromUser;
  final MiniUser toUser;
  final String encourageType; // 'cheer', 'motivate', 'celebrate', 'remind'
  final String message;
  final String? habitTitle;
  final DateTime createdAt;

  Encouragement({
    required this.id,
    required this.fromUser,
    required this.toUser,
    this.encourageType = 'cheer',
    this.message = '',
    this.habitTitle,
    required this.createdAt,
  });

  /// Emoji for the encouragement type.
  String get emoji {
    switch (encourageType) {
      case 'cheer':
        return '📣';
      case 'motivate':
        return '💪';
      case 'celebrate':
        return '🎉';
      case 'remind':
        return '⏰';
      default:
        return '📣';
    }
  }

  /// Human-readable label.
  String get typeLabel {
    switch (encourageType) {
      case 'cheer':
        return 'Cheered you on!';
      case 'motivate':
        return 'Sent motivation!';
      case 'celebrate':
        return 'Celebrated with you!';
      case 'remind':
        return 'Gave a friendly reminder!';
      default:
        return 'Encouraged you!';
    }
  }

  factory Encouragement.fromJson(Map<String, dynamic> json) {
    return Encouragement(
      id: json['id'] ?? 0,
      fromUser: MiniUser.fromJson(json['fromUser'] ?? {}),
      toUser: MiniUser.fromJson(json['toUser'] ?? {}),
      encourageType: json['encourageType'] ?? 'cheer',
      message: json['message'] ?? '',
      habitTitle: json['habitTitle'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// =============================================================================
// Mini User Model
// =============================================================================

/// Lightweight user representation for nested social objects.
class MiniUser {
  final int id;
  final String name;

  const MiniUser({required this.id, required this.name});

  factory MiniUser.fromJson(Map<String, dynamic> json) {
    return MiniUser(id: json['id'] ?? 0, name: json['name'] ?? 'Unknown');
  }
}

// =============================================================================
// Activity Feed Item Model
// =============================================================================

/// A single item in the unified activity feed.
///
/// Discriminated by [type] which can be 'encouragement', 'reaction',
/// 'comment', or 'group_challenge'. The Flutter UI uses this to choose
/// the appropriate card widget.
class ActivityFeedItem {
  final String type;
  final MiniUser? fromUser;
  final String? encourageType;
  final String? message;
  final String? reactionType;
  final String? content;
  final String? habitTitle;
  final String? groupName;
  final String? challengeTitle;
  final double? progress;
  final String? status;
  final DateTime createdAt;

  ActivityFeedItem({
    required this.type,
    this.fromUser,
    this.encourageType,
    this.message,
    this.reactionType,
    this.content,
    this.habitTitle,
    this.groupName,
    this.challengeTitle,
    this.progress,
    this.status,
    required this.createdAt,
  });

  /// Icon for the feed item type.
  IconData get icon {
    switch (type) {
      case 'encouragement':
        return Icons.celebration;
      case 'reaction':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'group_challenge':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  /// Color for the feed item type.
  Color get typeColor {
    switch (type) {
      case 'encouragement':
        return const Color(0xFFF59E0B);
      case 'reaction':
        return const Color(0xFFEF4444);
      case 'comment':
        return const Color(0xFF3B82F6);
      case 'group_challenge':
        return const Color(0xFF8B5CF6);
      default:
        return Colors.grey;
    }
  }

  /// Human-readable summary line.
  String get summary {
    final name = fromUser?.name ?? 'Someone';
    switch (type) {
      case 'encouragement':
        return '$name sent you a ${encourageType ?? "cheer"}!';
      case 'reaction':
        return '$name reacted to your habit "${habitTitle ?? ""}"';
      case 'comment':
        return '$name commented on "${habitTitle ?? ""}"';
      case 'group_challenge':
        return 'Challenge "${challengeTitle ?? ""}" in ${groupName ?? "group"}';
      default:
        return 'New activity';
    }
  }

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      type: json['type'] ?? '',
      fromUser: json['fromUser'] != null
          ? MiniUser.fromJson(json['fromUser'])
          : null,
      encourageType: json['encourageType'],
      message: json['message'],
      reactionType: json['reactionType'],
      content: json['content'],
      habitTitle: json['habitTitle'],
      groupName: json['groupName'],
      challengeTitle: json['challengeTitle'],
      progress: json['progress'] != null
          ? (json['progress'] as num).toDouble()
          : null,
      status: json['status'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// =============================================================================
// Enriched Group Detail Model
// =============================================================================

/// Full group detail with challenges, leaderboard, stats, and members.
///
/// Parsed from `/social/groups/{id}/detail/` API response.
class EnrichedGroupDetail {
  final int id;
  final String name;
  final String description;
  final String inviteCode;
  final int memberCount;
  final int maxMembers;
  final bool isActive;
  final String creatorName;
  final String? myRole;
  final int iconCode;
  final int colorValue;
  final int totalCompletions;
  final int totalStreaks;
  final List<Map<String, dynamic>> leaderboard;
  final List<GroupChallenge> challenges;
  final List<Map<String, dynamic>> sharedAchievements;
  final List<GroupMemberInfo> members;

  EnrichedGroupDetail({
    required this.id,
    required this.name,
    this.description = '',
    this.inviteCode = '',
    this.memberCount = 0,
    this.maxMembers = 50,
    this.isActive = true,
    this.creatorName = '',
    this.myRole,
    this.iconCode = 0xE7EF,
    this.colorValue = 0xFF4F46E5,
    this.totalCompletions = 0,
    this.totalStreaks = 0,
    this.leaderboard = const [],
    this.challenges = const [],
    this.sharedAchievements = const [],
    this.members = const [],
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  bool get isAdmin => myRole == 'admin';

  factory EnrichedGroupDetail.fromJson(Map<String, dynamic> json) {
    return EnrichedGroupDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      maxMembers: json['maxMembers'] ?? 50,
      isActive: json['isActive'] ?? true,
      creatorName: json['creatorName'] ?? '',
      myRole: json['myRole'],
      iconCode: json['iconCode'] ?? 0xE7EF,
      colorValue: json['colorValue'] ?? 0xFF4F46E5,
      totalCompletions: json['totalCompletions'] ?? 0,
      totalStreaks: json['totalStreaks'] ?? 0,
      leaderboard: List<Map<String, dynamic>>.from(json['leaderboard'] ?? []),
      challenges: (json['challenges'] as List? ?? [])
          .map((c) => GroupChallenge.fromJson(c))
          .toList(),
        sharedAchievements:
          List<Map<String, dynamic>>.from(json['sharedAchievements'] ?? []),
      members: (json['members'] as List? ?? [])
          .map((m) => GroupMemberInfo.fromJson(m))
          .toList(),
    );
  }
}

// =============================================================================
// Group Member Info
// =============================================================================

/// Member info within an enriched group detail.
class GroupMemberInfo {
  final int id;
  final String name;
  final String role;
  final int currentStreak;
  final DateTime joinedAt;

  GroupMemberInfo({
    required this.id,
    required this.name,
    this.role = 'member',
    this.currentStreak = 0,
    required this.joinedAt,
  });

  factory GroupMemberInfo.fromJson(Map<String, dynamic> json) {
    return GroupMemberInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      role: json['role'] ?? 'member',
      currentStreak: json['currentStreak'] ?? 0,
      joinedAt: DateTime.parse(
        json['joinedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
