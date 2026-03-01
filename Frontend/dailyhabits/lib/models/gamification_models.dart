// =============================================================================
// File: gamification_models.dart
// Description: Data models for the gamification system — XP, levels, coins,
//              challenges, leaderboard, streak freezes, milestones, daily bonus.
//              All models are deserialized from the Django REST API.
// =============================================================================

import 'package:flutter/material.dart';

// =============================================================================
// XP Event — Immutable audit record of every XP grant
// =============================================================================

/// A single XP gain/deduction event from the audit ledger.
class XPEvent {
  final int id;
  final int amount;
  final String sourceType;
  final String sourceId;
  final String description;
  final double multiplier;
  final int baseAmount;
  final DateTime createdAt;

  const XPEvent({
    required this.id,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
    required this.description,
    required this.multiplier,
    required this.baseAmount,
    required this.createdAt,
  });

  factory XPEvent.fromJson(Map<String, dynamic> json) {
    return XPEvent(
      id: json['id'] ?? 0,
      amount: json['amount'] ?? 0,
      sourceType: json['sourceType'] ?? json['source'] ?? '',
      sourceId: json['sourceId'] ?? '',
      description: json['description'] ?? '',
      multiplier: (json['multiplier'] ?? 1.0).toDouble(),
      baseAmount: json['baseAmount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Human-friendly label for the source type.
  String get sourceLabel {
    switch (sourceType) {
      case 'habit_completion':
        return 'Habit Completed';
      case 'streak_bonus':
        return 'Streak Bonus';
      case 'daily_all_done':
        return 'All Habits Done';
      case 'weekly_bonus':
        return 'Weekly Bonus';
      case 'achievement':
        return 'Achievement';
      case 'challenge':
        return 'Challenge';
      case 'level_up_bonus':
        return 'Level Up';
      case 'daily_login':
        return 'Daily Login';
      case 'referral':
        return 'Referral';
      default:
        return 'XP Earned';
    }
  }

  /// Icon for the source type.
  IconData get sourceIcon {
    switch (sourceType) {
      case 'habit_completion':
        return Icons.check_circle_rounded;
      case 'streak_bonus':
        return Icons.local_fire_department_rounded;
      case 'daily_all_done':
        return Icons.done_all_rounded;
      case 'weekly_bonus':
        return Icons.calendar_month_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'challenge':
        return Icons.flag_rounded;
      case 'level_up_bonus':
        return Icons.arrow_upward_rounded;
      case 'daily_login':
        return Icons.login_rounded;
      default:
        return Icons.stars_rounded;
    }
  }
}

// =============================================================================
// Wallet — Virtual currency (coins) balance
// =============================================================================

/// The user's virtual currency wallet.
class Wallet {
  final int balance;
  final int totalEarned;
  final int totalSpent;

  const Wallet({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      balance: json['balance'] ?? 0,
      totalEarned: json['totalEarned'] ?? 0,
      totalSpent: json['totalSpent'] ?? 0,
    );
  }
}

// =============================================================================
// Coin Transaction — Audit record of every coin credit/debit
// =============================================================================

class CoinTransaction {
  final int id;
  final int amount;
  final String transactionType;
  final String reason;
  final String source;
  final DateTime createdAt;

  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.reason,
    required this.source,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    return CoinTransaction(
      id: json['id'] ?? 0,
      amount: json['amount'] ?? 0,
      transactionType: json['transactionType'] ?? '',
      reason: json['reason'] ?? '',
      source: json['source'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isCredit => transactionType == 'credit';
}

// =============================================================================
// Streak Freeze — Purchasable streak protection
// =============================================================================

class StreakFreezeInfo {
  final int available;
  final int max;
  final int cost;
  final List<StreakFreezeToken> freezes;

  const StreakFreezeInfo({
    required this.available,
    required this.max,
    required this.cost,
    required this.freezes,
  });

  factory StreakFreezeInfo.fromJson(Map<String, dynamic> json) {
    return StreakFreezeInfo(
      available: json['available'] ?? 0,
      max: json['max'] ?? 3,
      cost: json['cost'] ?? 50,
      freezes: (json['freezes'] as List?)
              ?.map((f) => StreakFreezeToken.fromJson(f))
              .toList() ??
          [],
    );
  }
}

class StreakFreezeToken {
  final int id;
  final DateTime purchasedAt;
  final DateTime? expiresAt;

  const StreakFreezeToken({
    required this.id,
    required this.purchasedAt,
    this.expiresAt,
  });

  factory StreakFreezeToken.fromJson(Map<String, dynamic> json) {
    return StreakFreezeToken(
      id: json['id'] ?? 0,
      purchasedAt: DateTime.parse(json['purchased_at'] ?? json['purchasedAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expires_at'] != null || json['expiresAt'] != null
          ? DateTime.parse(json['expires_at'] ?? json['expiresAt'])
          : null,
    );
  }
}

// =============================================================================
// Challenge — Time-bound gamification goal
// =============================================================================

class Challenge {
  final int id;
  final String title;
  final String description;
  final String scope;
  final String difficulty;
  final Map<String, dynamic> criteria;
  final DateTime startDate;
  final DateTime endDate;
  final int xpReward;
  final int coinReward;
  final IconData icon;
  final Color color;
  final String status;
  final int progress;
  final double progressPercentage;
  final int target;
  final DateTime? completedAt;
  final int participantCount;
  final int maxParticipants;
  final String? timeRemaining;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.scope,
    required this.difficulty,
    required this.criteria,
    required this.startDate,
    required this.endDate,
    required this.xpReward,
    required this.coinReward,
    required this.icon,
    required this.color,
    required this.status,
    required this.progress,
    required this.progressPercentage,
    required this.target,
    this.completedAt,
    required this.participantCount,
    required this.maxParticipants,
    this.timeRemaining,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      scope: json['scope'] ?? 'personal',
      difficulty: json['difficulty'] ?? 'medium',
      criteria: json['criteria'] ?? {},
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      xpReward: json['xpReward'] ?? 0,
      coinReward: json['coinReward'] ?? 0,
      icon: IconData(json['iconCode'] ?? 0xE87C, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFF4F46E5),
      status: json['status'] ?? 'active',
      progress: json['progress'] ?? 0,
      progressPercentage: (json['progressPercentage'] ?? 0).toDouble(),
      target: json['target'] ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      participantCount: json['participantCount'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 1,
      timeRemaining: json['timeRemaining'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPersonal => scope == 'personal';
  bool get isFriend => scope == 'friend';
  bool get isCommunity => scope == 'community';

  /// Difficulty color for visual indication.
  Color get difficultyColor {
    switch (difficulty) {
      case 'easy':
        return const Color(0xFF22C55E);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      case 'extreme':
        return const Color(0xFF9400D3);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get difficultyLabel {
    return difficulty[0].toUpperCase() + difficulty.substring(1);
  }
}

// =============================================================================
// Leaderboard Entry — Ranked user in a leaderboard
// =============================================================================

class LeaderboardEntry {
  final int rank;
  final int rankChange;
  final int userId;
  final String userName;
  final String? profileImage;
  final int score;
  final int completions;
  final int streakDays;
  final double consistencyPct;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.rankChange,
    required this.userId,
    required this.userName,
    this.profileImage,
    required this.score,
    required this.completions,
    required this.streakDays,
    required this.consistencyPct,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      rankChange: json['rankChange'] ?? 0,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      profileImage: json['profileImage'],
      score: json['score'] ?? 0,
      completions: json['completions'] ?? 0,
      streakDays: json['streakDays'] ?? 0,
      consistencyPct: (json['consistencyPct'] ?? 0).toDouble(),
      isCurrentUser: json['isCurrentUser'] ?? false,
    );
  }

  /// +/- indicator for rank change.
  String get rankChangeText {
    if (rankChange > 0) return '+$rankChange';
    if (rankChange < 0) return '$rankChange';
    return '-';
  }

  Color get rankChangeColor {
    if (rankChange > 0) return const Color(0xFF22C55E);
    if (rankChange < 0) return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }
}

// =============================================================================
// Leaderboard — Full leaderboard response
// =============================================================================

class Leaderboard {
  final String boardType;
  final String periodStart;
  final List<LeaderboardEntry> entries;
  final LeaderboardUserRank? userRank;

  const Leaderboard({
    required this.boardType,
    required this.periodStart,
    required this.entries,
    this.userRank,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      boardType: json['boardType'] ?? 'weekly',
      periodStart: json['periodStart'] ?? '',
      entries: (json['entries'] as List?)
              ?.map((e) => LeaderboardEntry.fromJson(e))
              .toList() ??
          [],
      userRank: json['userRank'] != null
          ? LeaderboardUserRank.fromJson(json['userRank'])
          : null,
    );
  }
}

class LeaderboardUserRank {
  final int? rank;
  final int rankChange;
  final int score;

  const LeaderboardUserRank({
    this.rank,
    required this.rankChange,
    required this.score,
  });

  factory LeaderboardUserRank.fromJson(Map<String, dynamic> json) {
    return LeaderboardUserRank(
      rank: json['rank'],
      rankChange: json['rankChange'] ?? 0,
      score: json['score'] ?? 0,
    );
  }
}

// =============================================================================
// Daily Bonus Status
// =============================================================================

class DailyBonusStatus {
  final bool loginClaimed;
  final bool allDoneClaimed;

  const DailyBonusStatus({
    required this.loginClaimed,
    required this.allDoneClaimed,
  });

  factory DailyBonusStatus.fromJson(Map<String, dynamic> json) {
    return DailyBonusStatus(
      loginClaimed: json['loginClaimed'] ?? false,
      allDoneClaimed: json['allDoneClaimed'] ?? false,
    );
  }
}

// =============================================================================
// Milestone Reward — Reward definition for reaching milestones
// =============================================================================

class MilestoneReward {
  final String title;
  final String description;
  final int xp;
  final int coins;
  final int freezes;
  final IconData icon;
  final Color color;
  final String celebration;

  const MilestoneReward({
    required this.title,
    required this.description,
    required this.xp,
    required this.coins,
    required this.freezes,
    required this.icon,
    required this.color,
    required this.celebration,
  });

  factory MilestoneReward.fromJson(Map<String, dynamic> json) {
    return MilestoneReward(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xp: json['xp'] ?? json['xpReward'] ?? 0,
      coins: json['coins'] ?? json['coinReward'] ?? 0,
      freezes: json['freezes'] ?? json['streakFreezeReward'] ?? 0,
      icon: IconData(json['iconCode'] ?? 0xE838, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] ?? 0xFFFFD700),
      celebration: json['celebration'] ?? json['celebrationType'] ?? 'confetti',
    );
  }
}

// =============================================================================
// Gamification Dashboard — Composite data model
// =============================================================================

/// Composite model representing the full gamification state for a user.
/// Assembled from the `/api/gamification/` dashboard endpoint.
class GamificationDashboard {
  // Level & XP
  final int currentLevel;
  final String levelName;
  final int currentXp;
  final int totalXp;
  final int xpForNextLevel;
  final double xpProgressPercentage;

  // Wallet
  final Wallet wallet;

  // XP Summary
  final int todayXp;
  final int weekXp;
  final double streakMultiplier;

  // Streaks
  final int currentStreak;
  final int bestStreak;
  final StreakFreezeInfo freezes;

  // Challenges
  final List<Challenge> activeChallenges;
  final int totalActiveChallenges;

  // Daily bonus
  final DailyBonusStatus dailyBonus;

  // Stats
  final int totalCompletions;
  final int totalAchievements;
  final int daysActive;

  // Recent activity
  final List<XPEvent> recentActivity;

  const GamificationDashboard({
    required this.currentLevel,
    required this.levelName,
    required this.currentXp,
    required this.totalXp,
    required this.xpForNextLevel,
    required this.xpProgressPercentage,
    required this.wallet,
    required this.todayXp,
    required this.weekXp,
    required this.streakMultiplier,
    required this.currentStreak,
    required this.bestStreak,
    required this.freezes,
    required this.activeChallenges,
    required this.totalActiveChallenges,
    required this.dailyBonus,
    required this.totalCompletions,
    required this.totalAchievements,
    required this.daysActive,
    required this.recentActivity,
  });

  factory GamificationDashboard.fromJson(Map<String, dynamic> json) {
    final level = json['level'] ?? {};
    final walletData = json['wallet'] ?? {};
    final xpData = json['xp'] ?? {};
    final streakData = json['streaks'] ?? {};
    final challengeData = json['challenges'] ?? {};
    final bonusData = json['dailyBonus'] ?? {};
    final statsData = json['stats'] ?? {};
    final activityList = json['recentActivity'] as List? ?? [];

    return GamificationDashboard(
      currentLevel: level['currentLevel'] ?? 1,
      levelName: level['levelName'] ?? 'Beginner',
      currentXp: level['currentXp'] ?? 0,
      totalXp: level['totalXp'] ?? 0,
      xpForNextLevel: level['xpForNextLevel'] ?? 150,
      xpProgressPercentage: (level['xpProgressPercentage'] ?? 0).toDouble(),

      wallet: Wallet.fromJson(walletData),

      todayXp: xpData['todayXp'] ?? 0,
      weekXp: xpData['weekXp'] ?? 0,
      streakMultiplier: (xpData['streakMultiplier'] ?? 1.0).toDouble(),

      currentStreak: streakData['currentStreak'] ?? 0,
      bestStreak: streakData['bestStreak'] ?? 0,
      freezes: StreakFreezeInfo.fromJson(streakData['freezes'] ?? {}),

      activeChallenges: (challengeData['active'] as List?)
              ?.map((c) => Challenge.fromJson(c))
              .toList() ??
          [],
      totalActiveChallenges: challengeData['totalActive'] ?? 0,

      dailyBonus: DailyBonusStatus.fromJson(bonusData),

      totalCompletions: statsData['totalCompletions'] ?? 0,
      totalAchievements: statsData['totalAchievements'] ?? 0,
      daysActive: statsData['daysActive'] ?? 0,

      recentActivity: activityList.map((e) => XPEvent.fromJson(e)).toList(),
    );
  }
}

// =============================================================================
// Gamification Result — Response from habit completion
// =============================================================================

/// Result returned inline with habit toggle-complete when gamification is active.
class GamificationResult {
  final int xpEarned;
  final int coinsEarned;
  final double multiplier;
  final Map<String, dynamic>? allDoneBonus;
  final List<MilestoneReward> milestones;

  const GamificationResult({
    required this.xpEarned,
    required this.coinsEarned,
    required this.multiplier,
    this.allDoneBonus,
    required this.milestones,
  });

  factory GamificationResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GamificationResult(
        xpEarned: 0,
        coinsEarned: 0,
        multiplier: 1.0,
        milestones: [],
      );
    }
    return GamificationResult(
      xpEarned: json['xpEarned'] ?? 0,
      coinsEarned: json['coinsEarned'] ?? 0,
      multiplier: (json['multiplier'] ?? 1.0).toDouble(),
      allDoneBonus: json['allDoneBonus'],
      milestones: (json['milestones'] as List?)
              ?.map((m) => MilestoneReward.fromJson(m))
              .toList() ??
          [],
    );
  }

  bool get hasMilestones => milestones.isNotEmpty;
  bool get hasAllDoneBonus => allDoneBonus != null && allDoneBonus!['awarded'] == true;
  int get totalXp => xpEarned + (hasAllDoneBonus ? (allDoneBonus!['xp'] ?? 0) as int : 0);
}
