"""
Grow Together — Serializers
============================

DRF serializers for the collaborative habit sharing system.
All output uses camelCase to match the Flutter frontend contract.
"""

from rest_framework import serializers
from .models import (
    CollaborativeHabit,
    CollaborativeHabitMember,
    CollaborativeHabitProgress,
    HabitInvite,
    HabitActivityLog,
    ProgressReaction,
    ProgressComment,
    WeeklyLeaderboard,
    GroupMilestone,
    AbuseReport,
    StreakFreeze,
)


# ═══════════════════════════════════════════════════════════════════════════
#  MINI USER (re-used inline)
# ═══════════════════════════════════════════════════════════════════════════

class GTMiniUserSerializer(serializers.Serializer):
    """Lightweight read-only user representation for nested embedding."""
    id = serializers.IntegerField()
    name = serializers.CharField()
    email = serializers.EmailField()
    profileImage = serializers.URLField(source='profile_image', allow_null=True)


# ═══════════════════════════════════════════════════════════════════════════
#  COLLABORATIVE HABIT
# ═══════════════════════════════════════════════════════════════════════════

class CollaborativeHabitCreateSerializer(serializers.Serializer):
    """Write serializer for creating a new collaborative habit."""
    title = serializers.CharField(max_length=255)
    description = serializers.CharField(required=False, default='')
    emoji = serializers.CharField(required=False, default='🎯')
    frequency = serializers.ChoiceField(
        choices=['daily', 'weekly', 'custom'], default='daily',
    )
    customDays = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False, default=[],
    )
    targetCount = serializers.IntegerField(min_value=1, default=1)
    privacy = serializers.ChoiceField(
        choices=['private', 'friends_only', 'public'], default='friends_only',
    )
    maxMembers = serializers.IntegerField(min_value=2, max_value=500, default=50)
    iconCode = serializers.IntegerField(required=False, default=0xE87C)
    colorValue = serializers.IntegerField(required=False, default=0xFF4F46E5)
    sourceHabitId = serializers.IntegerField(required=False, allow_null=True)
    groupId = serializers.IntegerField(required=False, allow_null=True)
    friendIds = serializers.ListField(
        child=serializers.IntegerField(),
        required=False, default=[],
        help_text='Friends to invite immediately upon creation.',
    )


class CollaborativeHabitSerializer(serializers.ModelSerializer):
    """Read serializer for collaborative habits."""
    owner = GTMiniUserSerializer(read_only=True)
    memberCount = serializers.IntegerField(source='member_count', read_only=True)
    totalCompletions = serializers.IntegerField(source='total_completions', read_only=True)
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    maxMembers = serializers.IntegerField(source='max_members')
    targetCount = serializers.IntegerField(source='target_count')
    customDays = serializers.JSONField(source='custom_days')
    xpPerCompletion = serializers.IntegerField(source='xp_per_completion')
    bonusAllCompleteXp = serializers.IntegerField(source='bonus_all_complete_xp')
    isActive = serializers.BooleanField(source='is_active')
    sourceHabitId = serializers.SerializerMethodField()
    groupId = serializers.SerializerMethodField()
    myRole = serializers.SerializerMethodField()
    myStreak = serializers.SerializerMethodField()
    todayCompleted = serializers.SerializerMethodField()
    groupCompletionPercent = serializers.SerializerMethodField()

    class Meta:
        model = CollaborativeHabit
        fields = [
            'id', 'title', 'description', 'emoji', 'owner',
            'frequency', 'customDays', 'targetCount',
            'privacy', 'maxMembers', 'status',
            'iconCode', 'colorValue', 'isActive',
            'memberCount', 'totalCompletions',
            'xpPerCompletion', 'bonusAllCompleteXp',
            'sourceHabitId', 'groupId',
            'myRole', 'myStreak', 'todayCompleted',
            'groupCompletionPercent',
            'created_at', 'updated_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        data['updatedAt'] = data.pop('updated_at')
        return data

    def get_sourceHabitId(self, obj):
        return obj.source_habit_id

    def get_groupId(self, obj):
        return obj.group_id

    def get_myRole(self, obj):
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            member = getattr(obj, '_my_membership', None)
            if member:
                return member.role
            try:
                m = obj.members.get(user=request.user, is_active=True)
                return m.role
            except CollaborativeHabitMember.DoesNotExist:
                return None
        return None

    def get_myStreak(self, obj):
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            member = getattr(obj, '_my_membership', None)
            if member:
                return member.current_streak
            try:
                m = obj.members.get(user=request.user, is_active=True)
                return m.current_streak
            except CollaborativeHabitMember.DoesNotExist:
                return 0
        return 0

    def get_todayCompleted(self, obj):
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            from django.utils import timezone
            today = timezone.now().date()
            return obj.progress_records.filter(
                user=request.user, date=today, completed=True,
            ).exists()
        return False

    def get_groupCompletionPercent(self, obj):
        """Percentage of active members who completed today."""
        from django.utils import timezone
        today = timezone.now().date()
        active = obj.members.filter(is_active=True).count()
        if active == 0:
            return 0.0
        completed = obj.progress_records.filter(
            date=today, completed=True,
        ).values('user').distinct().count()
        return round(completed / active * 100, 1)


# ═══════════════════════════════════════════════════════════════════════════
#  MEMBER
# ═══════════════════════════════════════════════════════════════════════════

class CollaborativeHabitMemberSerializer(serializers.ModelSerializer):
    """Read serializer for collaborative habit members."""
    user = GTMiniUserSerializer(read_only=True)
    currentStreak = serializers.IntegerField(source='current_streak')
    bestStreak = serializers.IntegerField(source='best_streak')
    totalCompletions = serializers.IntegerField(source='total_completions')
    totalXpEarned = serializers.IntegerField(source='total_xp_earned')
    lastCompletedDate = serializers.DateField(source='last_completed_date', allow_null=True)
    todayCompleted = serializers.SerializerMethodField()

    class Meta:
        model = CollaborativeHabitMember
        fields = [
            'id', 'user', 'role', 'currentStreak', 'bestStreak',
            'totalCompletions', 'totalXpEarned', 'lastCompletedDate',
            'todayCompleted', 'is_active', 'joined_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['isActive'] = data.pop('is_active')
        data['joinedAt'] = data.pop('joined_at')
        return data

    def get_todayCompleted(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        return obj.progress_records.filter(date=today, completed=True).exists()


# ═══════════════════════════════════════════════════════════════════════════
#  PROGRESS
# ═══════════════════════════════════════════════════════════════════════════

class ProgressRecordSerializer(serializers.Serializer):
    """Write serializer for logging progress."""
    note = serializers.CharField(required=False, default='', max_length=500)
    completionCount = serializers.IntegerField(required=False, default=1)


class CollaborativeProgressSerializer(serializers.ModelSerializer):
    """Read serializer for progress records."""
    user = GTMiniUserSerializer(read_only=True)
    completionCount = serializers.IntegerField(source='completion_count')
    xpEarned = serializers.IntegerField(source='xp_earned')
    reactionCounts = serializers.SerializerMethodField()
    commentCount = serializers.SerializerMethodField()

    class Meta:
        model = CollaborativeHabitProgress
        fields = [
            'id', 'user', 'date', 'completed', 'completionCount',
            'note', 'xpEarned', 'reactionCounts', 'commentCount',
            'completed_at', 'created_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['completedAt'] = data.pop('completed_at')
        data['createdAt'] = data.pop('created_at')
        return data

    def get_reactionCounts(self, obj):
        counts = {}
        for r in obj.reactions.all():
            counts[r.reaction_type] = counts.get(r.reaction_type, 0) + 1
        return counts

    def get_commentCount(self, obj):
        return obj.comments.count()


# ═══════════════════════════════════════════════════════════════════════════
#  INVITE
# ═══════════════════════════════════════════════════════════════════════════

class InviteCreateSerializer(serializers.Serializer):
    """Write serializer for sending invitations."""
    friendIds = serializers.ListField(
        child=serializers.IntegerField(), min_length=1,
    )
    message = serializers.CharField(required=False, default='', max_length=300)


class HabitInviteSerializer(serializers.ModelSerializer):
    """Read serializer for habit invitations."""
    invitedBy = GTMiniUserSerializer(source='invited_by', read_only=True)
    invitedUser = GTMiniUserSerializer(source='invited_user', read_only=True)
    habitTitle = serializers.CharField(source='collaborative_habit.title', read_only=True)
    habitEmoji = serializers.CharField(source='collaborative_habit.emoji', read_only=True)
    habitId = serializers.UUIDField(source='collaborative_habit.id', read_only=True)
    memberCount = serializers.IntegerField(
        source='collaborative_habit.member_count', read_only=True,
    )
    isExpired = serializers.BooleanField(source='is_expired', read_only=True)

    class Meta:
        model = HabitInvite
        fields = [
            'id', 'invitedBy', 'invitedUser', 'habitTitle', 'habitEmoji',
            'habitId', 'memberCount', 'status', 'message',
            'isExpired', 'created_at', 'responded_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        data['respondedAt'] = data.pop('responded_at')
        return data


# ═══════════════════════════════════════════════════════════════════════════
#  ACTIVITY LOG
# ═══════════════════════════════════════════════════════════════════════════

class HabitActivityLogSerializer(serializers.ModelSerializer):
    """Read serializer for activity log entries."""
    actor = GTMiniUserSerializer(read_only=True)
    targetUser = GTMiniUserSerializer(source='target_user', read_only=True, allow_null=True)

    class Meta:
        model = HabitActivityLog
        fields = [
            'id', 'actor', 'targetUser', 'action',
            'description', 'metadata', 'created_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


# ═══════════════════════════════════════════════════════════════════════════
#  REACTIONS & COMMENTS
# ═══════════════════════════════════════════════════════════════════════════

class ProgressReactionSerializer(serializers.ModelSerializer):
    """Read serializer for progress reactions."""
    user = GTMiniUserSerializer(read_only=True)
    reactionType = serializers.CharField(source='reaction_type')

    class Meta:
        model = ProgressReaction
        fields = ['id', 'user', 'reactionType', 'created_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class ProgressCommentSerializer(serializers.ModelSerializer):
    """Read serializer for progress comments."""
    author = GTMiniUserSerializer(read_only=True)

    class Meta:
        model = ProgressComment
        fields = ['id', 'author', 'content', 'created_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


# ═══════════════════════════════════════════════════════════════════════════
#  LEADERBOARD
# ═══════════════════════════════════════════════════════════════════════════

class WeeklyLeaderboardSerializer(serializers.ModelSerializer):
    """Read serializer for weekly leaderboard entries."""
    user = GTMiniUserSerializer(read_only=True)
    weekStart = serializers.DateField(source='week_start')
    weekEnd = serializers.DateField(source='week_end')
    streakDays = serializers.IntegerField(source='streak_days')
    xpEarned = serializers.IntegerField(source='xp_earned')

    class Meta:
        model = WeeklyLeaderboard
        fields = [
            'id', 'user', 'rank', 'completions',
            'streakDays', 'xpEarned', 'weekStart', 'weekEnd',
        ]


# ═══════════════════════════════════════════════════════════════════════════
#  MILESTONE
# ═══════════════════════════════════════════════════════════════════════════

class GroupMilestoneSerializer(serializers.ModelSerializer):
    """Read serializer for group milestones."""
    milestoneType = serializers.CharField(source='milestone_type')
    xpReward = serializers.IntegerField(source='xp_reward')
    achievedAt = serializers.DateTimeField(source='achieved_at', allow_null=True)
    achievedBy = GTMiniUserSerializer(source='achieved_by', read_only=True, allow_null=True)
    iconCode = serializers.IntegerField(source='icon_code')
    badgeEmoji = serializers.CharField(source='badge_emoji')

    class Meta:
        model = GroupMilestone
        fields = [
            'id', 'milestoneType', 'title', 'description',
            'xpReward', 'achieved', 'achievedAt', 'achievedBy',
            'iconCode', 'badgeEmoji',
        ]


# ═══════════════════════════════════════════════════════════════════════════
#  ABUSE REPORT
# ═══════════════════════════════════════════════════════════════════════════

class AbuseReportCreateSerializer(serializers.Serializer):
    """Write serializer for filing abuse reports."""
    reportedUserId = serializers.IntegerField()
    reason = serializers.ChoiceField(
        choices=['spam', 'harassment', 'inappropriate', 'impersonation', 'other'],
    )
    description = serializers.CharField(max_length=1000)


class AbuseReportSerializer(serializers.ModelSerializer):
    """Read serializer for abuse reports."""
    reporter = GTMiniUserSerializer(read_only=True)
    reportedUser = GTMiniUserSerializer(source='reported_user', read_only=True)

    class Meta:
        model = AbuseReport
        fields = [
            'id', 'reporter', 'reportedUser', 'reason',
            'description', 'status', 'created_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


# ═══════════════════════════════════════════════════════════════════════════
#  DASHBOARD (aggregate)
# ═══════════════════════════════════════════════════════════════════════════

class GrowTogetherDashboardSerializer(serializers.Serializer):
    """Aggregate dashboard for the Grow Together feature."""
    myCollaborativeHabits = CollaborativeHabitSerializer(many=True)
    pendingInvites = HabitInviteSerializer(many=True)
    discoverableHabits = CollaborativeHabitSerializer(many=True)
    recentActivity = HabitActivityLogSerializer(many=True)
    totalActiveHabits = serializers.IntegerField()
    totalCompletionsToday = serializers.IntegerField()
    overallGroupStreak = serializers.IntegerField()


# ═══════════════════════════════════════════════════════════════════════════
#  STREAK FREEZE
# ═══════════════════════════════════════════════════════════════════════════

class StreakFreezeSerializer(serializers.ModelSerializer):
    """Read serializer for streak freeze tokens."""
    usedOnDate = serializers.DateField(source='used_on_date', allow_null=True)
    expiresAt = serializers.DateTimeField(source='expires_at', allow_null=True)
    isExpired = serializers.BooleanField(source='is_expired', read_only=True)

    class Meta:
        model = StreakFreeze
        fields = [
            'id', 'status', 'source', 'usedOnDate',
            'expiresAt', 'isExpired', 'created_at',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class StreakFreezeInfoSerializer(serializers.Serializer):
    """Aggregate streak freeze info for a member."""
    available = StreakFreezeSerializer(many=True)
    used = StreakFreezeSerializer(many=True)
    availableCount = serializers.IntegerField()
    usedCount = serializers.IntegerField()
    maxFreezes = serializers.IntegerField()
    freezeCostXp = serializers.IntegerField()
    memberXp = serializers.IntegerField()


# ═══════════════════════════════════════════════════════════════════════════
#  STREAK CALENDAR
# ═══════════════════════════════════════════════════════════════════════════

class StreakCalendarDaySerializer(serializers.Serializer):
    """Single day entry in the streak calendar."""
    date = serializers.CharField()
    completed = serializers.BooleanField()
    completionCount = serializers.IntegerField()
    note = serializers.CharField(allow_blank=True)
    xpEarned = serializers.IntegerField()
    freezeUsed = serializers.BooleanField()


class StreakCalendarSerializer(serializers.Serializer):
    """Full streak calendar response with member stats."""
    calendar = StreakCalendarDaySerializer(many=True)
    currentStreak = serializers.IntegerField()
    bestStreak = serializers.IntegerField()
    totalCompletions = serializers.IntegerField()
    totalXpEarned = serializers.IntegerField()
    lastCompletedDate = serializers.CharField(allow_null=True)
    availableFreezes = serializers.IntegerField()
    todayCompleted = serializers.BooleanField()


class UnmarkProgressResponseSerializer(serializers.Serializer):
    """Response after unmarking progress."""
    currentStreak = serializers.IntegerField()
    bestStreak = serializers.IntegerField()
    totalCompletions = serializers.IntegerField()
    totalXpEarned = serializers.IntegerField()
    xpDeducted = serializers.IntegerField()


class ProgressResultSerializer(serializers.Serializer):
    """Rich response after logging progress — full breakdown."""
    progress = CollaborativeProgressSerializer()
    streak = serializers.DictField()
    xpBreakdown = serializers.DictField()
    groupStatus = serializers.DictField()
    milestonesUnlocked = GroupMilestoneSerializer(many=True)


class TodayStatusSerializer(serializers.Serializer):
    """Response for the today-status endpoint."""
    completed = serializers.BooleanField()
    completedAt = serializers.DateTimeField(allow_null=True)
    completionCount = serializers.IntegerField()
    note = serializers.CharField(allow_blank=True)
    xpEarned = serializers.IntegerField()
    currentStreak = serializers.IntegerField()
    bestStreak = serializers.IntegerField()


class GroupProgressSerializer(serializers.Serializer):
    """Response for the group-progress endpoint."""
    date = serializers.CharField()
    completedMembers = serializers.IntegerField()
    totalMembers = serializers.IntegerField()
    percentage = serializers.FloatField()
    allComplete = serializers.BooleanField()
    memberStatuses = serializers.ListField(child=serializers.DictField())
