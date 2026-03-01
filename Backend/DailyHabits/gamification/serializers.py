"""
Gamification Serializers
========================

DRF serializers for the gamification system models. Handles validation,
camelCase field mapping for Flutter, and nested data structures.
"""

from rest_framework import serializers
from .models import (
    XPEvent, StreakFreeze, Challenge, ChallengeParticipant,
    LeaderboardEntry, VirtualCurrency, CurrencyTransaction,
    DailyBonus, MilestoneReward,
)


# =============================================================================
# XP & Currency Serializers
# =============================================================================

class XPEventSerializer(serializers.ModelSerializer):
    """Read-only serializer for XP events (audit trail)."""
    sourceType = serializers.CharField(source='source_type')
    sourceId = serializers.CharField(source='source_id')
    baseAmount = serializers.IntegerField(source='base_amount')
    createdAt = serializers.DateTimeField(source='created_at')

    class Meta:
        model = XPEvent
        fields = [
            'id', 'amount', 'sourceType', 'sourceId',
            'description', 'multiplier', 'baseAmount', 'createdAt',
        ]
        read_only_fields = fields


class WalletSerializer(serializers.ModelSerializer):
    """Read-only wallet overview."""
    totalEarned = serializers.IntegerField(source='total_earned')
    totalSpent = serializers.IntegerField(source='total_spent')

    class Meta:
        model = VirtualCurrency
        fields = ['balance', 'totalEarned', 'totalSpent']
        read_only_fields = fields


class CurrencyTransactionSerializer(serializers.ModelSerializer):
    """Read-only coin transaction record."""
    transactionType = serializers.CharField(source='transaction_type')
    createdAt = serializers.DateTimeField(source='created_at')

    class Meta:
        model = CurrencyTransaction
        fields = [
            'id', 'amount', 'transactionType', 'reason',
            'source', 'createdAt',
        ]
        read_only_fields = fields


# =============================================================================
# Streak Freeze Serializer
# =============================================================================

class StreakFreezeSerializer(serializers.ModelSerializer):
    """Read-only streak freeze details."""
    costCoins = serializers.IntegerField(source='cost_coins')
    purchasedAt = serializers.DateTimeField(source='purchased_at')
    usedAt = serializers.DateTimeField(source='used_at')
    expiresAt = serializers.DateTimeField(source='expires_at')
    protectedDate = serializers.DateField(source='protected_date')

    class Meta:
        model = StreakFreeze
        fields = [
            'id', 'status', 'costCoins', 'purchasedAt',
            'usedAt', 'expiresAt', 'protectedDate',
        ]
        read_only_fields = fields


# =============================================================================
# Challenge Serializers
# =============================================================================

class ChallengeCreateSerializer(serializers.Serializer):
    """Write serializer for creating a new challenge."""
    title = serializers.CharField(max_length=255)
    description = serializers.CharField(required=False, default='')
    scope = serializers.ChoiceField(
        choices=['personal', 'friend', 'community'],
        default='personal',
    )
    difficulty = serializers.ChoiceField(
        choices=['easy', 'medium', 'hard', 'extreme'],
        default='medium',
    )
    criteria = serializers.JSONField()
    start_date = serializers.DateTimeField(required=False)
    end_date = serializers.DateTimeField()
    xp_reward = serializers.IntegerField(default=100, min_value=0, max_value=1000)
    coin_reward = serializers.IntegerField(default=25, min_value=0, max_value=500)
    max_participants = serializers.IntegerField(default=1, min_value=1, max_value=100)
    icon_code = serializers.IntegerField(default=0xE87C)
    color_value = serializers.IntegerField(default=0xFF4F46E5)


class ChallengeSerializer(serializers.ModelSerializer):
    """Read serializer for challenge details."""
    startDate = serializers.DateTimeField(source='start_date')
    endDate = serializers.DateTimeField(source='end_date')
    xpReward = serializers.IntegerField(source='xp_reward')
    coinReward = serializers.IntegerField(source='coin_reward')
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    isFeatured = serializers.BooleanField(source='is_featured')
    inviteCode = serializers.CharField(source='invite_code')
    maxParticipants = serializers.IntegerField(source='max_participants')
    createdBy = serializers.SerializerMethodField()
    participantCount = serializers.SerializerMethodField()

    class Meta:
        model = Challenge
        fields = [
            'id', 'title', 'description', 'scope', 'status',
            'difficulty', 'criteria', 'startDate', 'endDate',
            'xpReward', 'coinReward', 'iconCode', 'colorValue',
            'isFeatured', 'inviteCode', 'maxParticipants',
            'createdBy', 'participantCount',
        ]
        read_only_fields = fields

    def get_createdBy(self, obj):
        return {
            'id': obj.created_by.id,
            'name': obj.created_by.name,
        }

    def get_participantCount(self, obj):
        return obj.participants.count()


class ChallengeParticipantSerializer(serializers.ModelSerializer):
    """Read serializer for challenge participation."""
    progressPercentage = serializers.FloatField(source='progress_percentage')
    completedAt = serializers.DateTimeField(source='completed_at')
    joinedAt = serializers.DateTimeField(source='joined_at')
    userName = serializers.CharField(source='user.name')

    class Meta:
        model = ChallengeParticipant
        fields = [
            'id', 'status', 'progress', 'progressPercentage',
            'completedAt', 'joinedAt', 'userName',
        ]
        read_only_fields = fields


# =============================================================================
# Leaderboard Serializer
# =============================================================================

class LeaderboardEntrySerializer(serializers.ModelSerializer):
    """Read serializer for leaderboard entries."""
    boardType = serializers.CharField(source='board_type')
    periodStart = serializers.DateField(source='period_start')
    streakDays = serializers.IntegerField(source='streak_days')
    consistencyPct = serializers.FloatField(source='consistency_pct')
    rankChange = serializers.IntegerField(source='rank_change')
    userName = serializers.CharField(source='user.name')
    profileImage = serializers.URLField(source='user.profile_image')

    class Meta:
        model = LeaderboardEntry
        fields = [
            'rank', 'rankChange', 'userName', 'profileImage',
            'score', 'completions', 'streakDays', 'consistencyPct',
            'boardType', 'periodStart',
        ]
        read_only_fields = fields


# =============================================================================
# Daily Bonus Serializer
# =============================================================================

class DailyBonusSerializer(serializers.ModelSerializer):
    """Read serializer for daily bonus status."""
    loginBonusClaimed = serializers.BooleanField(source='login_bonus_claimed')
    allDoneBonusClaimed = serializers.BooleanField(source='all_done_bonus_claimed')
    xpEarned = serializers.IntegerField(source='xp_earned')
    coinsEarned = serializers.IntegerField(source='coins_earned')

    class Meta:
        model = DailyBonus
        fields = [
            'date', 'loginBonusClaimed', 'allDoneBonusClaimed',
            'xpEarned', 'coinsEarned',
        ]
        read_only_fields = fields


# =============================================================================
# Milestone Serializer
# =============================================================================

class MilestoneRewardSerializer(serializers.ModelSerializer):
    """Read serializer for milestone reward definitions."""
    milestoneType = serializers.CharField(source='milestone_type')
    xpReward = serializers.IntegerField(source='xp_reward')
    coinReward = serializers.IntegerField(source='coin_reward')
    streakFreezeReward = serializers.IntegerField(source='streak_freeze_reward')
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    celebrationType = serializers.CharField(source='celebration_type')

    class Meta:
        model = MilestoneReward
        fields = [
            'id', 'milestoneType', 'threshold', 'title',
            'description', 'xpReward', 'coinReward',
            'streakFreezeReward', 'iconCode', 'colorValue',
            'celebrationType',
        ]
        read_only_fields = fields
