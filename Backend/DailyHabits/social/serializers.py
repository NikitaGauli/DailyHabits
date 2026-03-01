"""
Social / Community Serializers
==============================

DRF serializers that translate between Django ORM models and the camelCase
JSON contract consumed by the Flutter frontend.

Key conventions:
- All ``datetime`` fields are exposed as ``createdAt`` / ``joinedAt`` etc.
- Nested user references use the lightweight ``MiniUserSerializer`` to
  avoid circular imports with the ``authentication`` app.
- Read-heavy endpoints embed related data (e.g. recent comments inside a
  feed post) to minimise round-trips from the mobile client.

Sections:
    1. User mini-serializer
    2. Friendship serializers
    3. Feed post & comment serializers
    4. Group serializers
    5. Referral stats serializer
    6. Joined dashboard (aggregate) serializer
"""

from rest_framework import serializers
from django.conf import settings
from .models import (
    Friendship, FeedPost, PostLike, PostComment,
    GroupHabit, GroupMember, ReferralLink, Referral,
    SharedHabit, HabitReaction, HabitComment,
    GroupChallenge, Encouragement,
)


# ═══════════════════════════════════════════════════════════════════════════
#  USER MINI-SERIALIZER
# ═══════════════════════════════════════════════════════════════════════════


class MiniUserSerializer(serializers.Serializer):
    """
    Lightweight read-only user representation embedded in social responses.

    Avoids importing the full ``authentication.serializers`` module to
    prevent circular dependencies. Maps snake_case model fields to the
    camelCase JSON contract expected by the Flutter client.
    """

    id = serializers.IntegerField()
    name = serializers.CharField()
    email = serializers.EmailField()
    profileImage = serializers.URLField(source='profile_image', allow_null=True)
    currentStreak = serializers.IntegerField(source='current_streak')


# ─── Friendship ─────────────────────────────────────────────────────────

class FriendshipSerializer(serializers.ModelSerializer):
    fromUser = MiniUserSerializer(source='from_user', read_only=True)
    toUser = MiniUserSerializer(source='to_user', read_only=True)

    class Meta:
        model = Friendship
        fields = ['id', 'fromUser', 'toUser', 'status', 'created_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class FriendSerializer(serializers.Serializer):
    """Represents a confirmed friend (the other user)."""
    id = serializers.IntegerField()
    name = serializers.CharField()
    email = serializers.EmailField()
    profileImage = serializers.URLField(allow_null=True)
    currentStreak = serializers.IntegerField()
    totalHabitsCompleted = serializers.IntegerField()
    friendshipId = serializers.IntegerField()


# ─── Feed Post ──────────────────────────────────────────────────────────

class PostCommentSerializer(serializers.ModelSerializer):
    author = MiniUserSerializer(read_only=True)

    class Meta:
        model = PostComment
        fields = ['id', 'author', 'content', 'created_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class FeedPostSerializer(serializers.ModelSerializer):
    """
    Rich serializer for community feed posts.

    Includes nested author info, denormalized counts, resolved habit/group
    names, a per-request ``isLiked`` flag, and the three most recent
    comments pre-loaded to avoid N+1 queries on the feed list endpoint.

    Computed fields:
        - ``habitTitle``: Title of the linked habit, if any.
        - ``groupName``: Name of the linked group, if any.
        - ``isLiked``: Whether the requesting user has liked this post.
        - ``recentComments``: Last 3 comments (newest first).
    """

    author = MiniUserSerializer(read_only=True)
    likeCount = serializers.IntegerField(source='like_count', read_only=True)
    commentCount = serializers.IntegerField(source='comment_count', read_only=True)
    postType = serializers.CharField(source='post_type')
    habitTitle = serializers.SerializerMethodField()
    groupName = serializers.SerializerMethodField()
    isLiked = serializers.SerializerMethodField()
    recentComments = serializers.SerializerMethodField()

    class Meta:
        model = FeedPost
        fields = [
            'id', 'author', 'postType', 'content', 'emoji',
            'habitTitle', 'groupName',
            'likeCount', 'commentCount', 'isLiked',
            'recentComments', 'metadata', 'created_at',
        ]

    def to_representation(self, instance):
        """Rename ``created_at`` to ``createdAt`` in the output."""
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data

    def get_habitTitle(self, obj):
        """Return the linked habit's title, or ``None``."""
        return obj.habit.title if obj.habit else None

    def get_groupName(self, obj):
        """Return the linked group's name, or ``None``."""
        return obj.group.name if obj.group else None

    def get_isLiked(self, obj):
        """Check whether the requesting user has liked this post."""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_recentComments(self, obj):
        """Return the 3 most recent comments, newest first."""
        comments = obj.comments.select_related('author').order_by('-created_at')[:3]
        return PostCommentSerializer(comments, many=True).data


# ═══════════════════════════════════════════════════════════════════════════
#  GROUP SERIALIZERS
# ═══════════════════════════════════════════════════════════════════════════


class GroupMemberSerializer(serializers.Serializer):
    """
    Flat representation of a group member for leaderboard / members list.

    Includes the member's role within the group and their current
    streak to power leaderboard displays.
    """

    id = serializers.IntegerField()
    name = serializers.CharField()
    role = serializers.CharField()
    currentStreak = serializers.IntegerField()
    joinedAt = serializers.DateTimeField()


class GroupDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for a ``GroupHabit``.

    Exposes all group metadata (invite code, capacity, visual identity)
    plus two computed fields:
        - ``memberCount``: current number of active members.
        - ``myRole``: the requesting user's role (``admin``, ``member``,
          or ``None`` if not a member).
    """

    memberCount = serializers.SerializerMethodField()
    creatorName = serializers.CharField(source='creator.name', read_only=True)
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    inviteCode = serializers.CharField(source='invite_code')
    maxMembers = serializers.IntegerField(source='max_members')
    isActive = serializers.BooleanField(source='is_active')
    myRole = serializers.SerializerMethodField()

    class Meta:
        model = GroupHabit
        fields = [
            'id', 'name', 'description', 'inviteCode',
            'memberCount', 'maxMembers', 'isActive',
            'creatorName', 'myRole',
            'iconCode', 'colorValue', 'created_at',
        ]

    def to_representation(self, instance):
        """Rename ``created_at`` to ``createdAt`` in the output."""
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data

    def get_memberCount(self, obj):
        """Return the current active member count for this group."""
        return obj.member_count

    def get_myRole(self, obj):
        """Return the requesting user's role in this group, or ``None``."""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                membership = obj.members.get(user=request.user, is_active=True)
                return membership.role
            except GroupMember.DoesNotExist:
                return None
        return None


# ═══════════════════════════════════════════════════════════════════════════
#  REFERRAL SERIALIZER
# ═══════════════════════════════════════════════════════════════════════════


class ReferralStatsSerializer(serializers.Serializer):
    """
    Summary statistics for a user's referral link.

    Provides the referral code, usage counts, and active/max-use limits
    for display in the referral dashboard widget.
    """

    code = serializers.CharField()
    totalInvited = serializers.IntegerField()
    totalJoined = serializers.IntegerField()
    isActive = serializers.BooleanField()
    maxUses = serializers.IntegerField()


# ═══════════════════════════════════════════════════════════════════════════
#  JOINED DASHBOARD (AGGREGATE) SERIALIZER
# ═══════════════════════════════════════════════════════════════════════════


class JoinedDashboardSerializer(serializers.Serializer):
    """
    Aggregated community dashboard payload.

    Combines group membership summaries, friend counts, the user's
    community streak, and the latest friend activity into a single
    response object for the *Community* tab in the Flutter app.
    """

    totalGroups = serializers.IntegerField()
    totalFriends = serializers.IntegerField()
    communityStreak = serializers.IntegerField()
    groups = GroupDetailSerializer(many=True)
    recentFriendActivity = FeedPostSerializer(many=True)


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT SHARING SERIALIZERS
# ═══════════════════════════════════════════════════════════════════════════


class SharedHabitSerializer(serializers.ModelSerializer):
    """
    Write serializer for creating / managing habit shares.

    Used by ``POST /api/habits/{id}/share/`` to share a habit with
    selected friends. The ``friendIds`` field accepts a list of user
    IDs to share with — the view handles bulk creation.

    ``shared_by`` and ``habit`` are injected by the view's
    ``perform_create`` rather than supplied in the request body.
    """

    sharedWith = MiniUserSerializer(source='shared_with', read_only=True)
    sharedBy = MiniUserSerializer(source='shared_by', read_only=True)

    class Meta:
        model = SharedHabit
        fields = [
            'id', 'sharedBy', 'sharedWith',
            'can_comment', 'can_react', 'shared_at',
        ]
        read_only_fields = ['id', 'shared_at']

    def to_representation(self, instance):
        """Rename ``shared_at`` → ``sharedAt``."""
        data = super().to_representation(instance)
        data['sharedAt'] = data.pop('shared_at')
        data['canComment'] = data.pop('can_comment')
        data['canReact'] = data.pop('can_react')
        return data


class HabitReactionSerializer(serializers.ModelSerializer):
    """
    Serializer for emoji reactions on shared habits.

    Used by ``POST /api/habits/{id}/react/`` to toggle reactions.
    The ``user`` and ``habit`` are injected by the view.
    """

    user = MiniUserSerializer(read_only=True)
    reactionType = serializers.CharField(source='reaction_type')

    class Meta:
        model = HabitReaction
        fields = ['id', 'user', 'reactionType', 'created_at']
        read_only_fields = ['id', 'created_at']

    def to_representation(self, instance):
        """Rename ``created_at`` → ``createdAt``."""
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class HabitCommentSerializer(serializers.ModelSerializer):
    """
    Serializer for comments on shared habits.

    Used by ``GET / POST /api/habits/{id}/comments/`` for reading
    and creating comments. Embeds the author's mini profile for
    display in comment threads.
    """

    author = MiniUserSerializer(read_only=True)

    class Meta:
        model = HabitComment
        fields = ['id', 'author', 'content', 'created_at']
        read_only_fields = ['id', 'created_at']

    def to_representation(self, instance):
        """Rename ``created_at`` → ``createdAt``."""
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class SharedHabitDetailSerializer(serializers.Serializer):
    """
    Rich read-only serializer for displaying shared habits in the feed.

    Combines habit details, owner info, sharing metadata, reaction
    counts by type, recent comments, and the requesting user's own
    reaction state into a single payload.

    This serializer is NOT backed by a single model — it is assembled
    manually in the service layer from a ``SharedHabit`` queryset with
    prefetched relations.
    """

    id = serializers.IntegerField()
    habitId = serializers.IntegerField()
    habitTitle = serializers.CharField()
    habitDescription = serializers.CharField(allow_null=True)
    habitIcon = serializers.IntegerField()
    habitColor = serializers.IntegerField()
    habitFrequency = serializers.CharField()
    habitVisibility = serializers.CharField()

    # Owner info
    owner = MiniUserSerializer()

    # Current streak of the shared habit
    currentStreak = serializers.IntegerField()

    # Sharing metadata
    sharedAt = serializers.DateTimeField()
    canComment = serializers.BooleanField()
    canReact = serializers.BooleanField()

    # Engagement data
    reactionCounts = serializers.DictField(
        child=serializers.IntegerField(),
        help_text='Mapping of reaction_type → count',
    )
    myReactions = serializers.ListField(
        child=serializers.CharField(),
        help_text='List of reaction types the current user has applied.',
    )
    commentCount = serializers.IntegerField()
    recentComments = HabitCommentSerializer(many=True)


# ═══════════════════════════════════════════════════════════════════════════
#  GROUP CHALLENGE SERIALIZERS
# ═══════════════════════════════════════════════════════════════════════════


class GroupChallengeSerializer(serializers.ModelSerializer):
    """
    Serializer for group challenges.

    Exposes challenge metadata, progress, and reward info in camelCase
    for direct consumption by the Flutter client's challenge cards.
    """

    createdBy = MiniUserSerializer(source='created_by', read_only=True)
    targetType = serializers.CharField(source='target_type')
    targetValue = serializers.IntegerField(source='target_value')
    currentProgress = serializers.IntegerField(source='current_progress', read_only=True)
    progressPercentage = serializers.FloatField(
        source='progress_percentage', read_only=True,
    )
    startDate = serializers.DateTimeField(source='start_date')
    endDate = serializers.DateTimeField(source='end_date')
    xpReward = serializers.IntegerField(source='xp_reward')
    coinReward = serializers.IntegerField(source='coin_reward')
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    isActive = serializers.BooleanField(source='is_active', read_only=True)

    class Meta:
        model = GroupChallenge
        fields = [
            'id', 'title', 'description', 'targetType', 'targetValue',
            'currentProgress', 'progressPercentage', 'status',
            'startDate', 'endDate', 'xpReward', 'coinReward',
            'iconCode', 'colorValue', 'isActive', 'createdBy',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'currentProgress', 'status']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data


class GroupChallengeCreateSerializer(serializers.Serializer):
    """Write serializer for creating a group challenge."""

    title = serializers.CharField(max_length=200)
    description = serializers.CharField(required=False, default='')
    targetType = serializers.ChoiceField(
        choices=['completions', 'streak', 'all_done'],
    )
    targetValue = serializers.IntegerField(min_value=1)
    startDate = serializers.DateTimeField(required=False)
    endDate = serializers.DateTimeField(required=False)
    xpReward = serializers.IntegerField(required=False, default=50)
    coinReward = serializers.IntegerField(required=False, default=10)


# ═══════════════════════════════════════════════════════════════════════════
#  ENCOURAGEMENT SERIALIZERS
# ═══════════════════════════════════════════════════════════════════════════


class EncouragementSerializer(serializers.ModelSerializer):
    """Read serializer for encouragement messages."""

    fromUser = MiniUserSerializer(source='from_user', read_only=True)
    toUser = MiniUserSerializer(source='to_user', read_only=True)
    encourageType = serializers.CharField(source='encourage_type')
    habitTitle = serializers.SerializerMethodField()

    class Meta:
        model = Encouragement
        fields = [
            'id', 'fromUser', 'toUser', 'encourageType',
            'message', 'habitTitle', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data

    def get_habitTitle(self, obj):
        return obj.habit.title if obj.habit else None


class EncouragementCreateSerializer(serializers.Serializer):
    """Write serializer for sending encouragement."""

    toUserId = serializers.IntegerField()
    encourageType = serializers.ChoiceField(
        choices=['cheer', 'motivate', 'celebrate', 'remind'],
        required=False,
    )
    message = serializers.CharField(required=False, default='')
    habitId = serializers.IntegerField(required=False, allow_null=True)


# ═══════════════════════════════════════════════════════════════════════════
#  ACTIVITY FEED SERIALIZER
# ═══════════════════════════════════════════════════════════════════════════


class ActivityFeedItemSerializer(serializers.Serializer):
    """
    Generic serializer for the unified activity feed.

    Supports multiple activity types (encouragement, reaction, comment,
    group_challenge) with a shared ``type`` discriminator field. The
    Flutter client uses this field to decide which card widget to render.
    """

    type = serializers.CharField()
    fromUser = serializers.DictField(required=False)
    encourageType = serializers.CharField(required=False)
    message = serializers.CharField(required=False)
    reactionType = serializers.CharField(required=False)
    content = serializers.CharField(required=False)
    habitTitle = serializers.CharField(required=False, allow_null=True)
    groupName = serializers.CharField(required=False)
    challengeTitle = serializers.CharField(required=False)
    progress = serializers.FloatField(required=False)
    status = serializers.CharField(required=False)
    createdAt = serializers.CharField()


# ═══════════════════════════════════════════════════════════════════════════
#  ENRICHED GROUP DETAIL SERIALIZER
# ═══════════════════════════════════════════════════════════════════════════


class EnrichedGroupDetailSerializer(serializers.Serializer):
    """
    Extended group detail with challenges, leaderboard, and stats.
    """

    id = serializers.IntegerField()
    name = serializers.CharField()
    description = serializers.CharField()
    inviteCode = serializers.CharField()
    memberCount = serializers.IntegerField()
    maxMembers = serializers.IntegerField()
    isActive = serializers.BooleanField()
    creatorName = serializers.CharField()
    myRole = serializers.CharField(allow_null=True)
    iconCode = serializers.IntegerField()
    colorValue = serializers.IntegerField()
    totalCompletions = serializers.IntegerField()
    totalStreaks = serializers.IntegerField()
    leaderboard = serializers.ListField()
    challenges = serializers.ListField()
    members = serializers.ListField()

