// admin/models/admin_models.dart — Data models for the Admin Dashboard
//
// Mirrors the Django admin_panel models for type-safe API consumption.

// ═══════════════════════════════════════════════════════════════════════════════
//  RBAC
// ═══════════════════════════════════════════════════════════════════════════════

class AdminRole {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final List<String> permissions;
  final bool isActive;

  AdminRole({
    required this.id,
    required this.name,
    required this.displayName,
    this.description = '',
    this.permissions = const [],
    this.isActive = true,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) => AdminRole(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    displayName: json['display_name'] ?? '',
    description: json['description'] ?? '',
    permissions: List<String>.from(json['permissions'] ?? []),
    isActive: json['is_active'] ?? true,
  );
}

class AdminProfile {
  final String id;
  final String userEmail;
  final String userName;
  final String roleName;
  final String roleId;
  final bool isActive;
  final bool twoFactorEnabled;
  final String? lastAdminLogin;
  final List<String> permissions;

  AdminProfile({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.roleName,
    required this.roleId,
    this.isActive = true,
    this.twoFactorEnabled = false,
    this.lastAdminLogin,
    this.permissions = const [],
  });

  factory AdminProfile.fromJson(Map<String, dynamic> json) => AdminProfile(
    id: json['id'] ?? '',
    userEmail: json['user_email'] ?? '',
    userName: json['user_name'] ?? '',
    roleName: json['role_name'] ?? '',
    roleId: json['role']?.toString() ?? '',
    isActive: json['is_active'] ?? true,
    twoFactorEnabled: json['two_factor_enabled'] ?? false,
    lastAdminLogin: json['last_admin_login'],
    permissions: List<String>.from(json['permissions'] ?? []),
  );

  bool hasPermission(String perm) {
    if (permissions.contains('*')) return true;
    final namespace = '${perm.split('.')[0]}.*';
    return permissions.contains(perm) || permissions.contains(namespace);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  USER
// ═══════════════════════════════════════════════════════════════════════════════

class AdminUser {
  final int id;
  final String email;
  final String name;
  final String? profileImage;
  final bool isActive;
  final bool isStaff;
  final int currentStreak;
  final int totalHabitsCompleted;
  final String? createdAt;
  final String? lastLogin;
  final int habitsCount;
  final bool isSuspended;

  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.profileImage,
    this.isActive = true,
    this.isStaff = false,
    this.currentStreak = 0,
    this.totalHabitsCompleted = 0,
    this.createdAt,
    this.lastLogin,
    this.habitsCount = 0,
    this.isSuspended = false,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] ?? 0,
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    profileImage: json['profile_image'],
    isActive: json['is_active'] ?? true,
    isStaff: json['is_staff'] ?? false,
    currentStreak: json['current_streak'] ?? 0,
    totalHabitsCompleted: json['total_habits_completed'] ?? 0,
    createdAt: json['created_at'],
    lastLogin: json['last_login'],
    habitsCount: json['habits_count'] ?? 0,
    isSuspended: json['is_suspended'] ?? false,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════

class OverviewStats {
  final int totalUsers;
  final int activeUsersToday;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int totalHabits;
  final int habitsCompletedToday;
  final double averageCompletionRate;
  final int activeStreaks;
  final int totalGroups;
  final int totalChallengesActive;
  final int pendingReports;
  final int openSupportTickets;
  final int totalXpToday;

  OverviewStats({
    this.totalUsers = 0,
    this.activeUsersToday = 0,
    this.newUsersToday = 0,
    this.newUsersThisWeek = 0,
    this.totalHabits = 0,
    this.habitsCompletedToday = 0,
    this.averageCompletionRate = 0,
    this.activeStreaks = 0,
    this.totalGroups = 0,
    this.totalChallengesActive = 0,
    this.pendingReports = 0,
    this.openSupportTickets = 0,
    this.totalXpToday = 0,
  });

  factory OverviewStats.fromJson(Map<String, dynamic> json) => OverviewStats(
    totalUsers: json['total_users'] ?? 0,
    activeUsersToday: json['active_users_today'] ?? 0,
    newUsersToday: json['new_users_today'] ?? 0,
    newUsersThisWeek: json['new_users_this_week'] ?? 0,
    totalHabits: json['total_habits'] ?? 0,
    habitsCompletedToday: json['habits_completed_today'] ?? 0,
    averageCompletionRate: (json['average_completion_rate'] ?? 0).toDouble(),
    activeStreaks: json['active_streaks'] ?? 0,
    totalGroups: json['total_groups'] ?? 0,
    totalChallengesActive: json['total_challenges_active'] ?? 0,
    pendingReports: json['pending_reports'] ?? 0,
    openSupportTickets: json['open_support_tickets'] ?? 0,
    totalXpToday: json['total_xp_today'] ?? 0,
  );
}

class GrowthDataPoint {
  final String date;
  final int totalUsers;
  final int newUsers;
  final int dailyActiveUsers;
  final double completionRate;

  GrowthDataPoint({
    required this.date,
    this.totalUsers = 0,
    this.newUsers = 0,
    this.dailyActiveUsers = 0,
    this.completionRate = 0,
  });

  factory GrowthDataPoint.fromJson(Map<String, dynamic> json) =>
      GrowthDataPoint(
        date: json['date'] ?? '',
        totalUsers: json['total_users'] ?? 0,
        newUsers: json['new_users'] ?? 0,
        dailyActiveUsers: json['daily_active_users'] ?? 0,
        completionRate: (json['completion_rate'] ?? 0).toDouble(),
      );
}

class EngagementMetrics {
  final int periodDays;
  final int totalLogs;
  final int completed;
  final int skipped;
  final int missed;
  final double completionRate;
  final double groupChallengeRating10;
  final int groupChallengesCompleted;
  final int groupChallengesTotal;
  final double individualChallengeRating10;
  final int individualChallengesCompleted;
  final int individualChallengesTotal;
  final List<Map<String, dynamic>> streakDistribution;
  final List<Map<String, dynamic>> topCategories;

  EngagementMetrics({
    this.periodDays = 30,
    this.totalLogs = 0,
    this.completed = 0,
    this.skipped = 0,
    this.missed = 0,
    this.completionRate = 0,
    this.groupChallengeRating10 = 0,
    this.groupChallengesCompleted = 0,
    this.groupChallengesTotal = 0,
    this.individualChallengeRating10 = 0,
    this.individualChallengesCompleted = 0,
    this.individualChallengesTotal = 0,
    this.streakDistribution = const [],
    this.topCategories = const [],
  });

  factory EngagementMetrics.fromJson(
    Map<String, dynamic> json,
  ) => EngagementMetrics(
    periodDays: json['period_days'] ?? 30,
    totalLogs: json['total_logs'] ?? 0,
    completed: json['completed'] ?? 0,
    skipped: json['skipped'] ?? 0,
    missed: json['missed'] ?? 0,
    completionRate: (json['completion_rate'] ?? 0).toDouble(),
    groupChallengeRating10: (json['group_challenge_rating_10'] ?? 0).toDouble(),
    groupChallengesCompleted: json['group_challenges_completed'] ?? 0,
    groupChallengesTotal: json['group_challenges_total'] ?? 0,
    individualChallengeRating10: (json['individual_challenge_rating_10'] ?? 0)
        .toDouble(),
    individualChallengesCompleted: json['individual_challenges_completed'] ?? 0,
    individualChallengesTotal: json['individual_challenges_total'] ?? 0,
    streakDistribution: List<Map<String, dynamic>>.from(
      json['streak_distribution'] ?? [],
    ),
    topCategories: List<Map<String, dynamic>>.from(
      json['top_categories'] ?? [],
    ),
  );
}

class AnalyticsFilters {
  final int days;
  final int compareDays;
  final String category;
  final String segment;
  final String dateFrom;
  final String dateTo;

  AnalyticsFilters({
    this.days = 30,
    this.compareDays = 30,
    this.category = 'all',
    this.segment = 'all',
    this.dateFrom = '',
    this.dateTo = '',
  });

  factory AnalyticsFilters.fromJson(Map<String, dynamic> json) =>
      AnalyticsFilters(
        days: json['days'] ?? 30,
        compareDays: json['compare_days'] ?? 30,
        category: json['category'] ?? 'all',
        segment: json['segment'] ?? 'all',
        dateFrom: json['date_from'] ?? '',
        dateTo: json['date_to'] ?? '',
      );
}

class ComprehensiveAnalyticsReport {
  final AnalyticsFilters filters;
  final Map<String, dynamic> userGrowthEngagement;
  final Map<String, dynamic> habitPerformance;
  final Map<String, dynamic> behavioralInsights;
  final Map<String, dynamic> notificationEffectiveness;
  final Map<String, dynamic> systemUsage;
  final Map<String, dynamic> advancedReporting;
  final Map<String, dynamic> aiInsights;

  ComprehensiveAnalyticsReport({
    required this.filters,
    this.userGrowthEngagement = const {},
    this.habitPerformance = const {},
    this.behavioralInsights = const {},
    this.notificationEffectiveness = const {},
    this.systemUsage = const {},
    this.advancedReporting = const {},
    this.aiInsights = const {},
  });

  factory ComprehensiveAnalyticsReport.fromJson(Map<String, dynamic> json) {
    return ComprehensiveAnalyticsReport(
      filters: AnalyticsFilters.fromJson(
        Map<String, dynamic>.from(json['filters'] ?? {}),
      ),
      userGrowthEngagement: Map<String, dynamic>.from(
        json['user_growth_engagement'] ?? {},
      ),
      habitPerformance: Map<String, dynamic>.from(
        json['habit_performance'] ?? {},
      ),
      behavioralInsights: Map<String, dynamic>.from(
        json['behavioral_insights'] ?? {},
      ),
      notificationEffectiveness: Map<String, dynamic>.from(
        json['notification_effectiveness'] ?? {},
      ),
      systemUsage: Map<String, dynamic>.from(json['system_usage'] ?? {}),
      advancedReporting: Map<String, dynamic>.from(
        json['advanced_reporting'] ?? {},
      ),
      aiInsights: Map<String, dynamic>.from(json['ai_insights'] ?? {}),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  REPORTS & MODERATION
// ═══════════════════════════════════════════════════════════════════════════════

class Report {
  final String id;
  final String reporterEmail;
  final String reportedUserEmail;
  final String contentType;
  final String contentId;
  final String category;
  final String description;
  final String status;
  final String priority;
  final String? assignedToEmail;
  final String? resolution;
  final String? resolutionAction;
  final String? resolvedAt;
  final String createdAt;

  Report({
    required this.id,
    this.reporterEmail = '',
    this.reportedUserEmail = '',
    required this.contentType,
    required this.contentId,
    required this.category,
    this.description = '',
    this.status = 'pending',
    this.priority = 'medium',
    this.assignedToEmail,
    this.resolution,
    this.resolutionAction,
    this.resolvedAt,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] ?? '',
    reporterEmail: json['reporter_email'] ?? '',
    reportedUserEmail: json['reported_user_email'] ?? '',
    contentType: json['content_type'] ?? '',
    contentId: json['content_id'] ?? '',
    category: json['category'] ?? '',
    description: json['description'] ?? '',
    status: json['status'] ?? 'pending',
    priority: json['priority'] ?? 'medium',
    assignedToEmail: json['assigned_to_email'],
    resolution: json['resolution'],
    resolutionAction: json['resolution_action'],
    resolvedAt: json['resolved_at'],
    createdAt: json['created_at'] ?? '',
  );
}

class ModerationItem {
  final String id;
  final String contentType;
  final String contentId;
  final String contentPreview;
  final String authorEmail;
  final String status;
  final String flagReason;
  final double autoFlagScore;
  final String? reviewerNotes;
  final String createdAt;

  ModerationItem({
    required this.id,
    required this.contentType,
    required this.contentId,
    this.contentPreview = '',
    this.authorEmail = '',
    this.status = 'pending',
    this.flagReason = '',
    this.autoFlagScore = 0,
    this.reviewerNotes,
    required this.createdAt,
  });

  factory ModerationItem.fromJson(Map<String, dynamic> json) => ModerationItem(
    id: json['id'] ?? '',
    contentType: json['content_type'] ?? '',
    contentId: json['content_id'] ?? '',
    contentPreview: json['content_preview'] ?? '',
    authorEmail: json['author_email'] ?? '',
    status: json['status'] ?? 'pending',
    flagReason: json['flag_reason'] ?? '',
    autoFlagScore: (json['auto_flag_score'] ?? 0).toDouble(),
    reviewerNotes: json['reviewer_notes'],
    createdAt: json['created_at'] ?? '',
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AUDIT LOG
// ═══════════════════════════════════════════════════════════════════════════════

class AuditLogEntry {
  final String id;
  final String adminEmail;
  final String action;
  final String resourceType;
  final String resourceId;
  final String description;
  final String severity;
  final String? ipAddress;
  final String createdAt;

  AuditLogEntry({
    required this.id,
    this.adminEmail = '',
    required this.action,
    this.resourceType = '',
    this.resourceId = '',
    this.description = '',
    this.severity = 'info',
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: json['id'] ?? '',
    adminEmail: json['admin_email'] ?? '',
    action: json['action'] ?? '',
    resourceType: json['resource_type'] ?? '',
    resourceId: json['resource_id'] ?? '',
    description: json['description'] ?? '',
    severity: json['severity'] ?? 'info',
    ipAddress: json['ip_address'],
    createdAt: json['created_at'] ?? '',
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SYSTEM SETTINGS & FEATURE FLAGS
// ═══════════════════════════════════════════════════════════════════════════════

class SystemSetting {
  final String id;
  final String key;
  final String value;
  final String valueType;
  final dynamic typedValue;
  final String description;
  final String category;
  final bool isPublic;

  SystemSetting({
    required this.id,
    required this.key,
    required this.value,
    this.valueType = 'string',
    this.typedValue,
    this.description = '',
    this.category = 'general',
    this.isPublic = false,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) => SystemSetting(
    id: json['id'] ?? '',
    key: json['key'] ?? '',
    value: json['value'] ?? '',
    valueType: json['value_type'] ?? 'string',
    typedValue: json['typed_value'],
    description: json['description'] ?? '',
    category: json['category'] ?? 'general',
    isPublic: json['is_public'] ?? false,
  );
}

class FeatureFlag {
  final String id;
  final String key;
  final String name;
  final String description;
  final bool isEnabled;
  final String rolloutStrategy;
  final int rolloutPercentage;

  FeatureFlag({
    required this.id,
    required this.key,
    required this.name,
    this.description = '',
    this.isEnabled = false,
    this.rolloutStrategy = 'off',
    this.rolloutPercentage = 0,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) => FeatureFlag(
    id: json['id'] ?? '',
    key: json['key'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    isEnabled: json['is_enabled'] ?? false,
    rolloutStrategy: json['rollout_strategy'] ?? 'off',
    rolloutPercentage: json['rollout_percentage'] ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION CAMPAIGNS
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationCampaign {
  final String id;
  final String name;
  final String title;
  final String body;
  final String targetAudience;
  final String status;
  final String? scheduledAt;
  final String? sentAt;
  final int totalRecipients;
  final int deliveredCount;
  final int failedCount;
  final int openedCount;
  final double deliveryRate;
  final double openRate;
  final String createdAt;

  NotificationCampaign({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    this.targetAudience = 'all',
    this.status = 'draft',
    this.scheduledAt,
    this.sentAt,
    this.totalRecipients = 0,
    this.deliveredCount = 0,
    this.failedCount = 0,
    this.openedCount = 0,
    this.deliveryRate = 0,
    this.openRate = 0,
    required this.createdAt,
  });

  factory NotificationCampaign.fromJson(Map<String, dynamic> json) =>
      NotificationCampaign(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        targetAudience: json['target_audience'] ?? 'all',
        status: json['status'] ?? 'draft',
        scheduledAt: json['scheduled_at'],
        sentAt: json['sent_at'],
        totalRecipients: json['total_recipients'] ?? 0,
        deliveredCount: json['delivered_count'] ?? 0,
        failedCount: json['failed_count'] ?? 0,
        openedCount: json['opened_count'] ?? 0,
        deliveryRate: (json['delivery_rate'] ?? 0).toDouble(),
        openRate: (json['open_rate'] ?? 0).toDouble(),
        createdAt: json['created_at'] ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PAGINATED RESPONSE WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) => PaginatedResponse(
    count: json['count'] ?? 0,
    next: json['next'],
    previous: json['previous'],
    results:
        (json['results'] as List<dynamic>?)
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
