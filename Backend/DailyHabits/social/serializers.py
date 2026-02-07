"""
Social / Community Serializers
"""

from rest_framework import serializers
from django.conf import settings
from .models import (
    Friendship, FeedPost, PostLike, PostComment,
    GroupHabit, GroupMember, ReferralLink, Referral,
)


# ─── User mini-serializer (avoids circular import) ──────────────────────

class MiniUserSerializer(serializers.Serializer):
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
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data

    def get_habitTitle(self, obj):
        return obj.habit.title if obj.habit else None

    def get_groupName(self, obj):
        return obj.group.name if obj.group else None

    def get_isLiked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_recentComments(self, obj):
        comments = obj.comments.select_related('author').order_by('-created_at')[:3]
        return PostCommentSerializer(comments, many=True).data


# ─── Group ──────────────────────────────────────────────────────────────

class GroupMemberSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    role = serializers.CharField()
    currentStreak = serializers.IntegerField()
    joinedAt = serializers.DateTimeField()


class GroupDetailSerializer(serializers.ModelSerializer):
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
        data = super().to_representation(instance)
        data['createdAt'] = data.pop('created_at')
        return data

    def get_memberCount(self, obj):
        return obj.member_count

    def get_myRole(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                membership = obj.members.get(user=request.user, is_active=True)
                return membership.role
            except GroupMember.DoesNotExist:
                return None
        return None


# ─── Referral ───────────────────────────────────────────────────────────

class ReferralStatsSerializer(serializers.Serializer):
    code = serializers.CharField()
    totalInvited = serializers.IntegerField()
    totalJoined = serializers.IntegerField()
    isActive = serializers.BooleanField()
    maxUses = serializers.IntegerField()


# ─── Joined Dashboard ──────────────────────────────────────────────────

class JoinedDashboardSerializer(serializers.Serializer):
    totalGroups = serializers.IntegerField()
    totalFriends = serializers.IntegerField()
    communityStreak = serializers.IntegerField()
    groups = GroupDetailSerializer(many=True)
    recentFriendActivity = FeedPostSerializer(many=True)
