// =============================================================================
// File: grow_together_models.dart
// Description: Data models for the Grow Together collaborative habit sharing
//              system — collaborative habits, members, progress, invites,
//              activity feed, reactions, comments, leaderboard & milestones.
// =============================================================================

import 'package:flutter/material.dart';

// =============================================================================
// Mini User
// =============================================================================

/// Lightweight user representation used across the Grow Together feature.
class GTUser {
  final int id;
  final String email;
  final String displayName;

  GTUser({required this.id, required this.email, this.displayName = ''});

  factory GTUser.fromJson(Map<String, dynamic> json) {
    return GTUser(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? json['email'] ?? '',
    );
  }
}

// =============================================================================
// Collaborative Habit
// =============================================================================

/// A habit that multiple users can track together.
class CollaborativeHabit {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final GTUser owner;
  final String frequency;
  final List<int> customDays;
  final int targetCount;
  final String privacy;
  final int maxMembers;
  final int iconCode;
  final int colorValue;
  final String status;
  final int memberCount;
  final int totalCompletions;
  final int xpPerCompletion;
  final int bonusAllCompleteXp;
  final DateTime createdAt;

  // Computed fields from serializer
  final String? myRole;
  final int myStreak;
  final bool todayCompleted;
  final double groupCompletionPercent;
  final List<CollaborativeHabitMember> members;

  CollaborativeHabit({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🎯',
    required this.owner,
    this.frequency = 'daily',
    this.customDays = const [],
    this.targetCount = 1,
    this.privacy = 'friends_only',
    this.maxMembers = 50,
    this.iconCode = 0xE87C,
    this.colorValue = 0xFF4F46E5,
    this.status = 'active',
    this.memberCount = 1,
    this.totalCompletions = 0,
    this.xpPerCompletion = 15,
    this.bonusAllCompleteXp = 25,
    required this.createdAt,
    this.myRole,
    this.myStreak = 0,
    this.todayCompleted = false,
    this.groupCompletionPercent = 0.0,
    this.members = const [],
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  bool get isOwner => myRole == 'owner';
  bool get isAdmin => myRole == 'admin' || myRole == 'owner';

  /// Creates a copy with selectively overridden fields.
  CollaborativeHabit copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    GTUser? owner,
    String? frequency,
    List<int>? customDays,
    int? targetCount,
    String? privacy,
    int? maxMembers,
    int? iconCode,
    int? colorValue,
    String? status,
    int? memberCount,
    int? totalCompletions,
    int? xpPerCompletion,
    int? bonusAllCompleteXp,
    DateTime? createdAt,
    String? myRole,
    int? myStreak,
    bool? todayCompleted,
    double? groupCompletionPercent,
    List<CollaborativeHabitMember>? members,
  }) {
    return CollaborativeHabit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      owner: owner ?? this.owner,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      targetCount: targetCount ?? this.targetCount,
      privacy: privacy ?? this.privacy,
      maxMembers: maxMembers ?? this.maxMembers,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      status: status ?? this.status,
      memberCount: memberCount ?? this.memberCount,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      xpPerCompletion: xpPerCompletion ?? this.xpPerCompletion,
      bonusAllCompleteXp: bonusAllCompleteXp ?? this.bonusAllCompleteXp,
      createdAt: createdAt ?? this.createdAt,
      myRole: myRole ?? this.myRole,
      myStreak: myStreak ?? this.myStreak,
      todayCompleted: todayCompleted ?? this.todayCompleted,
      groupCompletionPercent: groupCompletionPercent ?? this.groupCompletionPercent,
      members: members ?? this.members,
    );
  }

  factory CollaborativeHabit.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    return CollaborativeHabit(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '🎯',
      owner: GTUser.fromJson(json['owner'] ?? {}),
      frequency: json['frequency'] ?? 'daily',
      customDays: (json['customDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      targetCount: json['targetCount'] ?? 1,
      privacy: json['privacy'] ?? 'friends_only',
      maxMembers: json['maxMembers'] ?? 50,
      iconCode: json['iconCode'] ?? 0xE87C,
      colorValue: json['colorValue'] ?? 0xFF4F46E5,
      status: json['status'] ?? 'active',
      memberCount: json['memberCount'] ?? 1,
      totalCompletions: json['totalCompletions'] ?? 0,
      xpPerCompletion: json['xpPerCompletion'] ?? 15,
      bonusAllCompleteXp: json['bonusAllCompleteXp'] ?? 25,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      myRole: json['myRole'],
      myStreak: json['myStreak'] ?? 0,
      todayCompleted: json['todayCompleted'] ?? false,
      groupCompletionPercent:
          (json['groupCompletionPercent'] as num?)?.toDouble() ?? 0.0,
      members: membersJson
          .map((e) =>
              CollaborativeHabitMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// Collaborative Habit Member
// =============================================================================

/// A member in a collaborative habit.
class CollaborativeHabitMember {
  final String id;
  final GTUser user;
  final String role;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final int totalXpEarned;
  final DateTime? lastCompletedDate;
  final DateTime joinedAt;
  final bool isActive;

  CollaborativeHabitMember({
    required this.id,
    required this.user,
    this.role = 'member',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletions = 0,
    this.totalXpEarned = 0,
    this.lastCompletedDate,
    required this.joinedAt,
    this.isActive = true,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';

  factory CollaborativeHabitMember.fromJson(Map<String, dynamic> json) {
    return CollaborativeHabitMember(
      id: json['id'] ?? '',
      user: GTUser.fromJson(json['user'] ?? {}),
      role: json['role'] ?? 'member',
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      totalCompletions: json['totalCompletions'] ?? 0,
      totalXpEarned: json['totalXpEarned'] ?? 0,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.tryParse(json['lastCompletedDate'])
          : null,
      joinedAt: DateTime.tryParse(json['joinedAt'] ?? '') ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }
}

// =============================================================================
// Collaborative Habit Progress
// =============================================================================

/// Daily progress record for one member.
class CollaborativeProgress {
  final String id;
  final GTUser user;
  final String date;
  final bool completed;
  final int completionCount;
  final String note;
  final int xpEarned;
  final DateTime? completedAt;
  final Map<String, int> reactions;
  final int commentCount;

  CollaborativeProgress({
    required this.id,
    required this.user,
    required this.date,
    this.completed = false,
    this.completionCount = 0,
    this.note = '',
    this.xpEarned = 0,
    this.completedAt,
    this.reactions = const {},
    this.commentCount = 0,
  });

  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);

  factory CollaborativeProgress.fromJson(Map<String, dynamic> json) {
    final reactionsRaw = json['reactions'] as Map<String, dynamic>? ?? {};
    return CollaborativeProgress(
      id: json['id'] ?? '',
      user: GTUser.fromJson(json['user'] ?? {}),
      date: json['date'] ?? '',
      completed: json['completed'] ?? false,
      completionCount: json['completionCount'] ?? 0,
      note: json['note'] ?? '',
      xpEarned: json['xpEarned'] ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      reactions:
          reactionsRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      commentCount: json['commentCount'] ?? 0,
    );
  }
}

// =============================================================================
// Habit Invite
// =============================================================================

/// An invitation to join a collaborative habit.
class HabitInvite {
  final String id;
  final String habitId;
  final String habitTitle;
  final String habitEmoji;
  final GTUser invitedBy;
  final String status;
  final String message;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int memberCount;

  HabitInvite({
    required this.id,
    required this.habitId,
    required this.habitTitle,
    this.habitEmoji = '🎯',
    required this.invitedBy,
    this.status = 'pending',
    this.message = '',
    required this.createdAt,
    this.expiresAt,
    this.memberCount = 1,
  });

  bool get isPending => status == 'pending';
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory HabitInvite.fromJson(Map<String, dynamic> json) {
    return HabitInvite(
      id: json['id'] ?? '',
      habitId: json['habitId'] ?? json['collaborativeHabitId'] ?? '',
      habitTitle: json['habitTitle'] ?? json['collaborativeHabitTitle'] ?? '',
      habitEmoji: json['habitEmoji'] ?? '🎯',
      invitedBy: GTUser.fromJson(json['invitedBy'] ?? {}),
      status: json['status'] ?? 'pending',
      message: json['message'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      memberCount: json['memberCount'] ?? 1,
    );
  }
}

// =============================================================================
// Activity Log
// =============================================================================

/// A single entry in the habit activity feed.
class GTActivityLog {
  final String id;
  final String action;
  final String description;
  final GTUser? actor;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  GTActivityLog({
    required this.id,
    required this.action,
    this.description = '',
    this.actor,
    this.metadata = const {},
    required this.createdAt,
  });

  /// Human-readable action label.
  String get actionLabel {
    switch (action) {
      case 'completed':
        return 'completed the habit';
      case 'joined':
        return 'joined the group';
      case 'left':
        return 'left the group';
      case 'streak_milestone':
        return 'hit a streak milestone';
      case 'group_milestone':
        return 'unlocked a group milestone';
      case 'reacted':
        return 'reacted to progress';
      case 'commented':
        return 'commented on progress';
      case 'all_completed':
        return '🎉 All members completed!';
      case 'invite_accepted':
        return 'accepted an invite';
      default:
        return action;
    }
  }

  /// Icon for the action type.
  IconData get actionIcon {
    switch (action) {
      case 'completed':
        return Icons.check_circle;
      case 'joined':
        return Icons.person_add;
      case 'left':
        return Icons.person_remove;
      case 'streak_milestone':
        return Icons.local_fire_department;
      case 'group_milestone':
        return Icons.emoji_events;
      case 'reacted':
        return Icons.favorite;
      case 'commented':
        return Icons.chat_bubble;
      case 'all_completed':
        return Icons.celebration;
      default:
        return Icons.info;
    }
  }

  factory GTActivityLog.fromJson(Map<String, dynamic> json) {
    return GTActivityLog(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      actor: json['actor'] != null ? GTUser.fromJson(json['actor']) : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// =============================================================================
// Progress Comment
// =============================================================================

/// A comment on a progress entry.
class GTProgressComment {
  final String id;
  final GTUser author;
  final String content;
  final DateTime createdAt;

  GTProgressComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  factory GTProgressComment.fromJson(Map<String, dynamic> json) {
    return GTProgressComment(
      id: json['id'] ?? '',
      author: GTUser.fromJson(json['author'] ?? {}),
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// =============================================================================
// Leaderboard Entry
// =============================================================================

/// A single entry in the weekly leaderboard.
class LeaderboardEntry {
  final String id;
  final GTUser user;
  final int rank;
  final int completions;
  final int streakDays;
  final int xpEarned;
  final String weekStart;
  final String weekEnd;

  LeaderboardEntry({
    required this.id,
    required this.user,
    required this.rank,
    this.completions = 0,
    this.streakDays = 0,
    this.xpEarned = 0,
    required this.weekStart,
    required this.weekEnd,
  });

  /// Medal icon for top 3 ranks.
  String get medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] ?? '',
      user: GTUser.fromJson(json['user'] ?? {}),
      rank: json['rank'] ?? 0,
      completions: json['completions'] ?? 0,
      streakDays: json['streakDays'] ?? 0,
      xpEarned: json['xpEarned'] ?? 0,
      weekStart: json['weekStart'] ?? '',
      weekEnd: json['weekEnd'] ?? '',
    );
  }
}

// =============================================================================
// Group Milestone
// =============================================================================

/// A milestone for a collaborative habit group.
class GTGroupMilestone {
  final String id;
  final String milestoneType;
  final String title;
  final String description;
  final int xpReward;
  final bool achieved;
  final DateTime? achievedAt;
  final GTUser? achievedBy;
  final int iconCode;
  final String badgeEmoji;

  GTGroupMilestone({
    required this.id,
    required this.milestoneType,
    required this.title,
    this.description = '',
    this.xpReward = 50,
    this.achieved = false,
    this.achievedAt,
    this.achievedBy,
    this.iconCode = 0xE838,
    this.badgeEmoji = '🏆',
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  /// Human-friendly milestone label.
  String get typeLabel {
    switch (milestoneType) {
      case 'group_streak_7':
        return '7-Day Group Streak';
      case 'group_streak_30':
        return '30-Day Group Streak';
      case 'all_complete_day':
        return '100% Team Completion';
      case 'total_completions_100':
        return '100 Completions';
      case 'total_completions_500':
        return '500 Completions';
      case 'member_streak_30':
        return 'Member 30-Day Streak';
      case 'consistency_30':
        return '30-Day Consistency';
      default:
        return milestoneType;
    }
  }

  factory GTGroupMilestone.fromJson(Map<String, dynamic> json) {
    return GTGroupMilestone(
      id: json['id'] ?? '',
      milestoneType: json['milestoneType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xpReward: json['xpReward'] ?? 50,
      achieved: json['achieved'] ?? false,
      achievedAt: json['achievedAt'] != null
          ? DateTime.tryParse(json['achievedAt'])
          : null,
      achievedBy: json['achievedBy'] != null
          ? GTUser.fromJson(json['achievedBy'])
          : null,
      iconCode: json['iconCode'] ?? 0xE838,
      badgeEmoji: json['badgeEmoji'] ?? '🏆',
    );
  }
}

// =============================================================================
// Dashboard Aggregate
// =============================================================================

/// Dashboard aggregate data for the Grow Together tab.
class GrowTogetherDashboard {
  final List<CollaborativeHabit> myCollaborativeHabits;
  final List<HabitInvite> pendingInvites;
  final List<CollaborativeHabit> discoverableHabits;
  final List<GTActivityLog> recentActivity;
  final int totalActiveHabits;
  final int totalCompletionsToday;
  final int overallGroupStreak;

  GrowTogetherDashboard({
    this.myCollaborativeHabits = const [],
    this.pendingInvites = const [],
    this.discoverableHabits = const [],
    this.recentActivity = const [],
    this.totalActiveHabits = 0,
    this.totalCompletionsToday = 0,
    this.overallGroupStreak = 0,
  });

  factory GrowTogetherDashboard.fromJson(Map<String, dynamic> json) {
    return GrowTogetherDashboard(
      myCollaborativeHabits: (json['myCollaborativeHabits'] as List<dynamic>?)
              ?.map((e) =>
                  CollaborativeHabit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingInvites: (json['pendingInvites'] as List<dynamic>?)
              ?.map((e) => HabitInvite.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      discoverableHabits: (json['discoverableHabits'] as List<dynamic>?)
              ?.map((e) =>
                  CollaborativeHabit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentActivity: (json['recentActivity'] as List<dynamic>?)
              ?.map(
                  (e) => GTActivityLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalActiveHabits: json['totalActiveHabits'] ?? 0,
      totalCompletionsToday: json['totalCompletionsToday'] ?? 0,
      overallGroupStreak: json['overallGroupStreak'] ?? 0,
    );
  }
}

// =============================================================================
// Progress Result (Rich response from logging progress)
// =============================================================================

/// Streak breakdown returned after logging progress.
class StreakInfo {
  final int current;
  final int best;
  final bool increased;

  StreakInfo({this.current = 0, this.best = 0, this.increased = false});

  factory StreakInfo.fromJson(Map<String, dynamic> json) {
    return StreakInfo(
      current: json['current'] ?? 0,
      best: json['best'] ?? 0,
      increased: json['increased'] ?? false,
    );
  }
}

/// XP breakdown returned after logging progress.
class XpBreakdown {
  final int base;
  final double multiplier;
  final int earned;
  final bool streakBonus;

  XpBreakdown({
    this.base = 0,
    this.multiplier = 1.0,
    this.earned = 0,
    this.streakBonus = false,
  });

  factory XpBreakdown.fromJson(Map<String, dynamic> json) {
    return XpBreakdown(
      base: json['base'] ?? 0,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      earned: json['earned'] ?? 0,
      streakBonus: json['streakBonus'] ?? false,
    );
  }
}

/// Group completion status returned after logging progress.
class GroupStatus {
  final int completedMembers;
  final int totalMembers;
  final double percentage;
  final bool allComplete;

  GroupStatus({
    this.completedMembers = 0,
    this.totalMembers = 0,
    this.percentage = 0.0,
    this.allComplete = false,
  });

  factory GroupStatus.fromJson(Map<String, dynamic> json) {
    return GroupStatus(
      completedMembers: json['completedMembers'] ?? 0,
      totalMembers: json['totalMembers'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      allComplete: json['allComplete'] ?? false,
    );
  }
}

/// Rich result returned after logging progress.
class ProgressResult {
  final CollaborativeProgress progress;
  final StreakInfo streak;
  final XpBreakdown xpBreakdown;
  final GroupStatus groupStatus;
  final List<GTGroupMilestone> milestonesUnlocked;

  ProgressResult({
    required this.progress,
    required this.streak,
    required this.xpBreakdown,
    required this.groupStatus,
    this.milestonesUnlocked = const [],
  });

  factory ProgressResult.fromJson(Map<String, dynamic> json) {
    return ProgressResult(
      progress: CollaborativeProgress.fromJson(
          json['progress'] as Map<String, dynamic>? ?? {}),
      streak:
          StreakInfo.fromJson(json['streak'] as Map<String, dynamic>? ?? {}),
      xpBreakdown: XpBreakdown.fromJson(
          json['xpBreakdown'] as Map<String, dynamic>? ?? {}),
      groupStatus: GroupStatus.fromJson(
          json['groupStatus'] as Map<String, dynamic>? ?? {}),
      milestonesUnlocked: (json['milestonesUnlocked'] as List<dynamic>?)
              ?.map((e) =>
                  GTGroupMilestone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// =============================================================================
// Streak Calendar Day
// =============================================================================

/// Single day entry in the streak calendar.
class StreakCalendarDay {
  final DateTime date;
  final bool completed;
  final int completionCount;
  final String note;
  final int xpEarned;
  final bool freezeUsed;

  StreakCalendarDay({
    required this.date,
    this.completed = false,
    this.completionCount = 0,
    this.note = '',
    this.xpEarned = 0,
    this.freezeUsed = false,
  });

  /// Whether the day was "protected" (completed or freeze used).
  bool get isProtected => completed || freezeUsed;

  factory StreakCalendarDay.fromJson(Map<String, dynamic> json) {
    return StreakCalendarDay(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      completed: json['completed'] ?? false,
      completionCount: json['completionCount'] ?? 0,
      note: json['note'] ?? '',
      xpEarned: json['xpEarned'] ?? 0,
      freezeUsed: json['freezeUsed'] ?? false,
    );
  }
}

// =============================================================================
// Streak Calendar
// =============================================================================

/// Full streak calendar response with member stats.
class StreakCalendar {
  final List<StreakCalendarDay> calendar;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final int totalXpEarned;
  final String? lastCompletedDate;
  final int availableFreezes;
  final bool todayCompleted;

  StreakCalendar({
    this.calendar = const [],
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletions = 0,
    this.totalXpEarned = 0,
    this.lastCompletedDate,
    this.availableFreezes = 0,
    this.todayCompleted = false,
  });

  factory StreakCalendar.fromJson(Map<String, dynamic> json) {
    return StreakCalendar(
      calendar: (json['calendar'] as List<dynamic>?)
              ?.map(
                  (e) => StreakCalendarDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      totalCompletions: json['totalCompletions'] ?? 0,
      totalXpEarned: json['totalXpEarned'] ?? 0,
      lastCompletedDate: json['lastCompletedDate'],
      availableFreezes: json['availableFreezes'] ?? 0,
      todayCompleted: json['todayCompleted'] ?? false,
    );
  }
}

// =============================================================================
// Streak Freeze
// =============================================================================

/// A streak freeze token.
class GTStreakFreeze {
  final String id;
  final String status;
  final String source;
  final String? usedOnDate;
  final DateTime? expiresAt;
  final bool isExpired;
  final DateTime createdAt;

  GTStreakFreeze({
    required this.id,
    this.status = 'available',
    this.source = 'earned',
    this.usedOnDate,
    this.expiresAt,
    this.isExpired = false,
    required this.createdAt,
  });

  bool get isAvailable => status == 'available' && !isExpired;

  factory GTStreakFreeze.fromJson(Map<String, dynamic> json) {
    return GTStreakFreeze(
      id: json['id'] ?? '',
      status: json['status'] ?? 'available',
      source: json['source'] ?? 'earned',
      usedOnDate: json['usedOnDate'],
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      isExpired: json['isExpired'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// =============================================================================
// Streak Freeze Info
// =============================================================================

/// Aggregate streak freeze info for a member.
class StreakFreezeInfo {
  final List<GTStreakFreeze> available;
  final List<GTStreakFreeze> used;
  final int availableCount;
  final int usedCount;
  final int maxFreezes;
  final int freezeCostXp;
  final int memberXp;

  StreakFreezeInfo({
    this.available = const [],
    this.used = const [],
    this.availableCount = 0,
    this.usedCount = 0,
    this.maxFreezes = 3,
    this.freezeCostXp = 50,
    this.memberXp = 0,
  });

  bool get canPurchase =>
      availableCount < maxFreezes && memberXp >= freezeCostXp;

  factory StreakFreezeInfo.fromJson(Map<String, dynamic> json) {
    return StreakFreezeInfo(
      available: (json['available'] as List<dynamic>?)
              ?.map(
                  (e) => GTStreakFreeze.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      used: (json['used'] as List<dynamic>?)
              ?.map(
                  (e) => GTStreakFreeze.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableCount: json['availableCount'] ?? 0,
      usedCount: json['usedCount'] ?? 0,
      maxFreezes: json['maxFreezes'] ?? 3,
      freezeCostXp: json['freezeCostXp'] ?? 50,
      memberXp: json['memberXp'] ?? 0,
    );
  }
}
