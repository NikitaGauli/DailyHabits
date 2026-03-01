"""
admin_panel/serializers.py — DRF Serializers for Admin API
===========================================================
"""

from django.contrib.auth import get_user_model
from rest_framework import serializers

from achievements.models import Achievement, UserAchievement
from gamification.models import (
    Challenge, LeaderboardEntry, MilestoneReward, XPEvent,
)
from habits.models import Category, Habit, HabitLog, Streak
from notifications.models import Notification
from social.models import FeedPost, GroupHabit, PostComment

from .models import (
    AdminProfile,
    AdminRole,
    AISafetyLog,
    AIUserRestriction,
    AuditLog,
    ContentModerationQueue,
    FeatureFlag,
    NotificationCampaign,
    NotificationTemplate,
    PlatformAnalyticsSnapshot,
    Report,
    SystemSettings,
    UserWarning,
)

User = get_user_model()


# ═══════════════════════════════════════════════════════════════════════════════
#  RBAC
# ═══════════════════════════════════════════════════════════════════════════════

class AdminRoleSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminRole
        fields = [
            'id', 'name', 'display_name', 'description',
            'permissions', 'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class AdminProfileSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source='role.display_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.name', read_only=True)

    class Meta:
        model = AdminProfile
        fields = [
            'id', 'user', 'user_email', 'user_name', 'role', 'role_name',
            'is_active', 'two_factor_enabled', 'last_admin_login',
            'last_admin_ip', 'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'user_email', 'user_name', 'role_name',
            'last_admin_login', 'last_admin_ip', 'created_at', 'updated_at',
        ]


class AdminProfileCreateSerializer(serializers.ModelSerializer):
    """For creating a new admin profile — accepts user ID and role ID."""

    class Meta:
        model = AdminProfile
        fields = ['user', 'role', 'notes']

    def validate_user(self, value):
        if AdminProfile.objects.filter(user=value).exists():
            raise serializers.ValidationError('User already has an admin profile.')
        return value


# ═══════════════════════════════════════════════════════════════════════════════
#  USER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class AdminUserListSerializer(serializers.ModelSerializer):
    """Lightweight user representation for paginated lists."""
    habits_count = serializers.SerializerMethodField()
    is_suspended = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'name', 'profile_image', 'is_active',
            'is_staff', 'is_superuser', 'current_streak',
            'total_habits_completed', 'created_at', 'last_login',
            'habits_count', 'is_suspended',
        ]

    def get_habits_count(self, obj):
        return getattr(obj, '_habits_count', Habit.objects.filter(user=obj, is_deleted=False).count())

    def get_is_suspended(self, obj):
        return not obj.is_active


class AdminUserDetailSerializer(serializers.ModelSerializer):
    """Full user detail for admin inspection."""
    habits = serializers.SerializerMethodField()
    warnings_count = serializers.SerializerMethodField()
    reports_count = serializers.SerializerMethodField()
    achievements_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'name', 'profile_image', 'is_active',
            'is_staff', 'is_superuser', 'current_streak',
            'total_habits_completed', 'created_at', 'updated_at',
            'last_login', 'habits', 'warnings_count', 'reports_count',
            'achievements_count',
        ]

    def get_habits(self, obj):
        habits = Habit.objects.filter(user=obj, is_deleted=False).values(
            'id', 'title', 'status', 'frequency', 'created_at',
        )[:20]
        return list(habits)

    def get_warnings_count(self, obj):
        return UserWarning.objects.filter(user=obj).count()

    def get_reports_count(self, obj):
        return Report.objects.filter(reported_user=obj).count()

    def get_achievements_count(self, obj):
        return UserAchievement.objects.filter(user=obj).count()


class AdminUserEditSerializer(serializers.ModelSerializer):
    """Limited field set for admin-side user edits."""

    class Meta:
        model = User
        fields = ['name', 'is_active', 'is_staff']


# ═══════════════════════════════════════════════════════════════════════════════
#  REPORTS & MODERATION
# ═══════════════════════════════════════════════════════════════════════════════

class ReportSerializer(serializers.ModelSerializer):
    reporter_email = serializers.CharField(source='reporter.email', read_only=True, default='')
    reported_user_email = serializers.CharField(source='reported_user.email', read_only=True, default='')
    assigned_to_email = serializers.CharField(source='assigned_to.email', read_only=True, default='')

    class Meta:
        model = Report
        fields = [
            'id', 'reporter', 'reporter_email', 'reported_user',
            'reported_user_email', 'content_type', 'content_id',
            'category', 'description', 'evidence_urls', 'status',
            'priority', 'assigned_to', 'assigned_to_email', 'resolution',
            'resolution_action', 'resolved_at', 'resolved_by',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'reporter', 'reporter_email', 'reported_user_email',
            'assigned_to_email', 'resolved_at', 'created_at', 'updated_at',
        ]


class ReportResolveSerializer(serializers.Serializer):
    """Payload for resolving a report."""
    status = serializers.ChoiceField(choices=['resolved', 'dismissed', 'escalated'])
    resolution = serializers.CharField(required=True)
    resolution_action = serializers.ChoiceField(
        choices=['none', 'warn', 'suspend', 'ban', 'remove_content'],
        default='none',
    )


class ContentModerationQueueSerializer(serializers.ModelSerializer):
    author_email = serializers.CharField(source='content_author.email', read_only=True, default='')

    class Meta:
        model = ContentModerationQueue
        fields = [
            'id', 'content_type', 'content_id', 'content_preview',
            'content_author', 'author_email', 'status', 'flag_reason',
            'auto_flag_score', 'report', 'reviewed_by', 'reviewed_at',
            'reviewer_notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'author_email', 'created_at', 'updated_at']


class ModerationDecisionSerializer(serializers.Serializer):
    """Payload for approving/rejecting moderation items."""
    action = serializers.ChoiceField(choices=['approve', 'reject'])
    notes = serializers.CharField(required=False, default='')


class UserWarningSerializer(serializers.ModelSerializer):
    issued_by_email = serializers.CharField(source='issued_by.email', read_only=True, default='')
    user_email = serializers.CharField(source='user.email', read_only=True, default='')

    class Meta:
        model = UserWarning
        fields = [
            'id', 'user', 'user_email', 'issued_by', 'issued_by_email',
            'severity', 'reason', 'related_report', 'acknowledged',
            'acknowledged_at', 'expires_at', 'created_at',
        ]
        read_only_fields = ['id', 'user_email', 'issued_by_email', 'issued_by', 'created_at']


class UserWarningCreateSerializer(serializers.Serializer):
    """Issue a new warning to a user."""
    user_id = serializers.IntegerField()
    severity = serializers.ChoiceField(choices=['informal', 'formal', 'final'])
    reason = serializers.CharField()
    report_id = serializers.UUIDField(required=False, allow_null=True)


# ═══════════════════════════════════════════════════════════════════════════════
#  AUDIT LOGS
# ═══════════════════════════════════════════════════════════════════════════════

class AuditLogSerializer(serializers.ModelSerializer):
    admin_email = serializers.CharField(source='admin_user.email', read_only=True, default='')

    class Meta:
        model = AuditLog
        fields = [
            'id', 'admin_user', 'admin_email', 'action',
            'resource_type', 'resource_id', 'description', 'changes',
            'ip_address', 'user_agent', 'metadata', 'severity',
            'created_at',
        ]
        read_only_fields = fields  # Entirely read-only


# ═══════════════════════════════════════════════════════════════════════════════
#  SYSTEM SETTINGS & FEATURE FLAGS
# ═══════════════════════════════════════════════════════════════════════════════

class SystemSettingsSerializer(serializers.ModelSerializer):
    typed_value = serializers.SerializerMethodField()

    class Meta:
        model = SystemSettings
        fields = [
            'id', 'key', 'value', 'value_type', 'typed_value',
            'description', 'category', 'is_public',
            'updated_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'typed_value', 'created_at', 'updated_at']

    def get_typed_value(self, obj):
        try:
            return obj.get_typed_value()
        except (ValueError, TypeError):
            return obj.value


class SystemSettingsUpdateSerializer(serializers.Serializer):
    value = serializers.CharField()
    value_type = serializers.ChoiceField(
        choices=['string', 'integer', 'float', 'boolean', 'json'],
        required=False,
    )


class FeatureFlagSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeatureFlag
        fields = [
            'id', 'key', 'name', 'description', 'is_enabled',
            'rollout_strategy', 'rollout_percentage', 'metadata',
            'updated_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


# ═══════════════════════════════════════════════════════════════════════════════
#  NOTIFICATION TEMPLATES & CAMPAIGNS
# ═══════════════════════════════════════════════════════════════════════════════

class NotificationTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationTemplate
        fields = [
            'id', 'name', 'channel', 'subject', 'title', 'body',
            'metadata', 'is_active', 'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']


class NotificationCampaignSerializer(serializers.ModelSerializer):
    delivery_rate = serializers.FloatField(read_only=True)
    open_rate = serializers.FloatField(read_only=True)

    class Meta:
        model = NotificationCampaign
        fields = [
            'id', 'name', 'template', 'title', 'body',
            'target_audience', 'target_filters', 'status',
            'scheduled_at', 'sent_at', 'total_recipients',
            'delivered_count', 'failed_count', 'opened_count',
            'delivery_rate', 'open_rate',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'sent_at', 'total_recipients', 'delivered_count',
            'failed_count', 'opened_count', 'delivery_rate', 'open_rate',
            'created_by', 'created_at', 'updated_at',
        ]


# ═══════════════════════════════════════════════════════════════════════════════
#  ANALYTICS
# ═══════════════════════════════════════════════════════════════════════════════

class PlatformAnalyticsSnapshotSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformAnalyticsSnapshot
        fields = '__all__'
        read_only_fields = ['id', 'created_at']


class OverviewStatsSerializer(serializers.Serializer):
    """Aggregated dashboard KPIs — not model-backed."""
    total_users = serializers.IntegerField()
    active_users_today = serializers.IntegerField()
    new_users_today = serializers.IntegerField()
    new_users_this_week = serializers.IntegerField()
    total_habits = serializers.IntegerField()
    habits_completed_today = serializers.IntegerField()
    average_completion_rate = serializers.FloatField()
    active_streaks = serializers.IntegerField()
    total_groups = serializers.IntegerField()
    total_challenges_active = serializers.IntegerField()
    pending_reports = serializers.IntegerField()
    open_support_tickets = serializers.IntegerField()
    total_xp_today = serializers.IntegerField()


class GrowthTrendSerializer(serializers.Serializer):
    """Time-series data point for growth charts."""
    date = serializers.DateField()
    total_users = serializers.IntegerField()
    new_users = serializers.IntegerField()
    daily_active_users = serializers.IntegerField()
    completion_rate = serializers.FloatField()


# ═══════════════════════════════════════════════════════════════════════════════
#  AI SAFETY
# ═══════════════════════════════════════════════════════════════════════════════

class AISafetyLogSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True, default='')

    class Meta:
        model = AISafetyLog
        fields = [
            'id', 'user', 'user_email', 'feature', 'input_text',
            'output_text', 'safety_score', 'status', 'flag_reason',
            'reviewed_by', 'reviewed_at', 'metadata', 'created_at',
        ]
        read_only_fields = ['id', 'user_email', 'created_at']


class AIUserRestrictionSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True, default='')

    class Meta:
        model = AIUserRestriction
        fields = [
            'id', 'user', 'user_email', 'feature', 'is_disabled',
            'reason', 'disabled_by', 'created_at', 'expires_at',
        ]
        read_only_fields = ['id', 'user_email', 'disabled_by', 'created_at']


# ═══════════════════════════════════════════════════════════════════════════════
#  GAMIFICATION  (read/edit existing models)
# ═══════════════════════════════════════════════════════════════════════════════

class AdminAchievementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Achievement
        fields = [
            'id', 'name', 'description', 'achievement_type',
            'target_value', 'target_type', 'icon_code', 'color_value',
            'badge_image_url', 'rarity', 'points', 'level_required',
            'order', 'is_active', 'is_hidden', 'created_at',
        ]


class AdminChallengeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Challenge
        fields = [
            'id', 'title', 'description', 'scope', 'status',
            'difficulty', 'criteria', 'start_date', 'end_date',
            'xp_reward', 'coin_reward', 'max_participants',
            'is_featured', 'created_at',
        ]


class AdminMilestoneRewardSerializer(serializers.ModelSerializer):
    class Meta:
        model = MilestoneReward
        fields = [
            'id', 'milestone_type', 'threshold', 'title', 'description',
            'xp_reward', 'coin_reward', 'streak_freeze_reward',
            'icon_code', 'color_value', 'celebration_type', 'is_active',
            'created_at',
        ]


class AdminLeaderboardEntrySerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.name', read_only=True)

    class Meta:
        model = LeaderboardEntry
        fields = [
            'id', 'user', 'user_email', 'user_name', 'board_type',
            'period_start', 'period_end', 'score', 'completions',
            'streak_days', 'consistency_pct', 'rank', 'rank_change',
            'updated_at',
        ]
