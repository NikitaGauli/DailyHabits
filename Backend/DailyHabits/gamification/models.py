"""
Gamification Models — Extended Gamification System
===================================================

Extends the existing achievements system with:
    • XPEvent            — Granular XP transaction ledger (audit trail)
    • StreakFreeze       — Purchasable streak protection tokens
    • Challenge          — Time-bound personal / friend / community goals
    • ChallengeParticipant — Join table for challenge participants
    • LeaderboardEntry   — Weekly / all-time / friends rankings
    • VirtualCurrency    — Soft-currency wallet (coins)
    • CurrencyTransaction — Full transaction log for coins
    • DailyBonus         — Login / daily-completion bonus tracker
    • MilestoneReward    — Level-up and streak milestone reward definitions

The existing achievements app (Achievement, UserAchievement, UserLevel,
Reward, UserReward) remains untouched. This module adds complementary
tables that reference the same User model but live in their own app for
clean separation of concerns.

Design decisions:
    - All XP mutations go through XPEvent for full auditability.
    - StreakFreeze implements a token economy: users spend coins to buy
      freeze tokens, which are automatically consumed when a streak
      would otherwise break.
    - Challenges support three scopes: personal, friend, community.
    - Leaderboard entries are denormalized for fast reads and rebuilt
      periodically by a scheduled task.
    - VirtualCurrency uses optimistic locking via balance checks to
      prevent overdraft race conditions.
"""

from __future__ import annotations

from django.db import models
from django.conf import settings
from django.utils import timezone


# =============================================================================
# XP Event Ledger
# =============================================================================

class XPEvent(models.Model):
    """
    Immutable XP transaction record.

    Every XP gain or deduction is recorded as an event, providing a
    complete audit trail. The ``source_type`` field categorises the
    origin of the XP change for analytics dashboards.

    Sources:
        habit_completion — Completing a daily habit
        streak_bonus     — Maintaining a streak milestone
        daily_all_done   — Completing ALL habits in a day
        weekly_bonus     — 7-day consistency bonus
        achievement      — Earning a new achievement badge
        challenge        — Completing a challenge goal
        level_up_bonus   — Bonus XP on leveling up
        daily_login      — Daily login bonus
        referral         — Referred a new user
    """
    SOURCE_TYPES = [
        ('habit_completion', 'Habit Completion'),
        ('streak_bonus', 'Streak Bonus'),
        ('daily_all_done', 'All Habits Completed'),
        ('weekly_bonus', 'Weekly Consistency Bonus'),
        ('achievement', 'Achievement Earned'),
        ('challenge', 'Challenge Completed'),
        ('level_up_bonus', 'Level Up Bonus'),
        ('daily_login', 'Daily Login'),
        ('referral', 'Referral Bonus'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='xp_events',
    )
    amount = models.IntegerField()                                       # Can be negative for corrections
    source_type = models.CharField(max_length=50, choices=SOURCE_TYPES)
    source_id = models.CharField(max_length=100, blank=True, default='')  # FK hint (habit id, achievement id, etc.)
    description = models.CharField(max_length=255, blank=True, default='')

    # Multiplier applied (e.g. streak multiplier)
    multiplier = models.FloatField(default=1.0)
    base_amount = models.IntegerField(default=0)                          # Pre-multiplier amount

    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = 'xp_events'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'source_type']),
            models.Index(fields=['user', 'created_at']),
        ]

    def __str__(self):
        return f"{self.user.email} +{self.amount}XP ({self.source_type})"


# =============================================================================
# Streak Freeze System
# =============================================================================

class StreakFreeze(models.Model):
    """
    A consumable token that protects a streak from breaking on one missed day.

    Users purchase freeze tokens using virtual coins. When the nightly
    streak-check job detects a missed day, it auto-consumes an available
    freeze before resetting the streak.

    States:
        available — Ready to be consumed
        used      — Consumed to protect a streak
        expired   — Was not used before its expiry date
    """
    STATUS_CHOICES = [
        ('available', 'Available'),
        ('used', 'Used'),
        ('expired', 'Expired'),
    ]

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='streak_freezes',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='available')
    cost_coins = models.IntegerField(default=50)                          # Price paid
    purchased_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)              # Optional auto-expiry
    protected_date = models.DateField(null=True, blank=True)              # Date where freeze was consumed

    class Meta:
        db_table = 'streak_freezes'
        ordering = ['-purchased_at']

    def __str__(self):
        return f"{self.user.email} freeze ({self.status})"

    def consume(self, date=None):
        """Mark this freeze as used, recording the protected date."""
        self.status = 'used'
        self.used_at = timezone.now()
        self.protected_date = date or timezone.now().date()
        self.save()


# =============================================================================
# Challenge System
# =============================================================================

class Challenge(models.Model):
    """
    A time-bound gamification challenge.

    Challenges provide short-term goals beyond daily habits. They can be
    personal (solo), friend-based (1v1 or small group), or community-wide.

    Criteria are stored as a JSON object to support flexible goal types:
        {"type": "completions", "target": 35, "period_days": 7}
        {"type": "streak", "target": 7}
        {"type": "all_done_days", "target": 5, "period_days": 7}
    """
    SCOPE_CHOICES = [
        ('personal', 'Personal'),
        ('friend', 'Friend Challenge'),
        ('community', 'Community'),
    ]
    STATUS_CHOICES = [
        ('upcoming', 'Upcoming'),
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('expired', 'Expired'),
    ]
    DIFFICULTY_CHOICES = [
        ('easy', 'Easy'),
        ('medium', 'Medium'),
        ('hard', 'Hard'),
        ('extreme', 'Extreme'),
    ]

    id = models.BigAutoField(primary_key=True)
    title = models.CharField(max_length=255)
    description = models.TextField()
    scope = models.CharField(max_length=20, choices=SCOPE_CHOICES, default='personal')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='upcoming')
    difficulty = models.CharField(max_length=20, choices=DIFFICULTY_CHOICES, default='medium')

    # --- Goal criteria (flexible JSON) ---
    criteria = models.JSONField(default=dict)
    # e.g. {"type": "completions", "target": 35, "period_days": 7}

    # --- Time bounds ---
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()

    # --- Rewards ---
    xp_reward = models.IntegerField(default=100)
    coin_reward = models.IntegerField(default=25)
    badge_reward = models.ForeignKey(
        'achievements.Achievement',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='challenges',
    )

    # --- Social ---
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_challenges',
    )
    max_participants = models.IntegerField(default=1)                      # 1 = personal
    invite_code = models.CharField(max_length=20, blank=True, unique=True, null=True)

    # --- Display ---
    icon_code = models.IntegerField(default=0xE87C)
    color_value = models.BigIntegerField(default=0xFF4F46E5)

    is_featured = models.BooleanField(default=False)                       # Shown in discover feed
    created_at = models.DateTimeField(auto_now_add=True)

    # Reverse FK from ChallengeParticipant (related_name='participants')
    participants: models.Manager[ChallengeParticipant]

    class Meta:
        db_table = 'challenges'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['scope', 'status']),
            models.Index(fields=['status', 'end_date']),
        ]

    def __str__(self):
        return f"{self.title} ({self.scope})"

    @property
    def is_active(self):
        now = timezone.now()
        return self.start_date <= now <= self.end_date and self.status == 'active'

    @property
    def time_remaining(self):
        """Return timedelta until challenge ends, or zero if expired."""
        remaining = self.end_date - timezone.now()
        return remaining if remaining.total_seconds() > 0 else timezone.timedelta(0)


class ChallengeParticipant(models.Model):
    """
    A user participating in a challenge.

    Tracks individual progress toward the challenge goal and records
    completion status with timestamps.
    """
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('withdrawn', 'Withdrawn'),
    ]

    id = models.BigAutoField(primary_key=True)
    challenge = models.ForeignKey(
        Challenge,
        on_delete=models.CASCADE,
        related_name='participants',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='challenge_participations',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    progress = models.IntegerField(default=0)                              # Current progress value
    progress_percentage = models.FloatField(default=0.0)                   # 0.0–100.0
    completed_at = models.DateTimeField(null=True, blank=True)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'challenge_participants'
        unique_together = ('challenge', 'user')
        ordering = ['-progress_percentage']

    def __str__(self):
        return f"{self.user.email} in {self.challenge.title} ({self.status})"


# =============================================================================
# Leaderboard System
# =============================================================================

class LeaderboardEntry(models.Model):
    """
    Denormalized leaderboard row for fast ranked queries.

    Leaderboards are rebuilt periodically (e.g. every hour or on relevant
    events) by a scheduled task. Keeping them denormalized avoids expensive
    aggregation queries on every page load.

    Board types:
        weekly   — Resets every Monday
        monthly  — Resets on the 1st
        alltime  — Never resets
        friends  — Scoped to a user's friend list (virtual; filtered at query time)
    """
    BOARD_TYPES = [
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
        ('alltime', 'All Time'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='leaderboard_entries',
    )
    board_type = models.CharField(max_length=20, choices=BOARD_TYPES)
    period_start = models.DateField()                                      # Start of the ranking period
    period_end = models.DateField()                                        # End of the ranking period

    # --- Metrics ---
    score = models.IntegerField(default=0)                                 # Primary ranking metric (XP)
    completions = models.IntegerField(default=0)                           # Habit completions in period
    streak_days = models.IntegerField(default=0)                           # Best streak in period
    consistency_pct = models.FloatField(default=0.0)                       # Avg consistency %

    # --- Rank (computed) ---
    rank = models.IntegerField(default=0)
    rank_change = models.IntegerField(default=0)                           # +/- positions since last refresh

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'leaderboard_entries'
        unique_together = ('user', 'board_type', 'period_start')
        ordering = ['board_type', 'rank']
        indexes = [
            models.Index(fields=['board_type', 'period_start', 'rank']),
        ]

    def __str__(self):
        return f"#{self.rank} {self.user.email} ({self.board_type})"


# =============================================================================
# Virtual Currency (Coins)
# =============================================================================

class VirtualCurrency(models.Model):
    """
    User's soft-currency wallet.

    Coins are earned through habit completions, streaks, achievements, and
    challenges. They can be spent on streak freezes, theme unlocks, and
    other virtual rewards.

    Balance is cached on this model for O(1) read access, but the full
    transaction history is maintained in CurrencyTransaction for auditing.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='wallet',
    )
    balance = models.IntegerField(default=0)
    total_earned = models.IntegerField(default=0)
    total_spent = models.IntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'virtual_currency'

    def __str__(self):
        return f"{self.user.email}: {self.balance} coins"

    def credit(self, amount, reason='', source=''):
        """Add coins to the wallet and log the transaction."""
        if amount <= 0:
            raise ValueError("Credit amount must be positive")
        self.balance += amount
        self.total_earned += amount
        self.save()
        CurrencyTransaction.objects.create(
            user=self.user,
            amount=amount,
            transaction_type='credit',
            reason=reason,
            source=source,
        )

    def debit(self, amount, reason='', source=''):
        """
        Remove coins from the wallet and log the transaction.

        Raises ValueError if insufficient balance.
        """
        if amount <= 0:
            raise ValueError("Debit amount must be positive")
        if self.balance < amount:
            raise ValueError("Insufficient balance")
        self.balance -= amount
        self.total_spent += amount
        self.save()
        CurrencyTransaction.objects.create(
            user=self.user,
            amount=-amount,
            transaction_type='debit',
            reason=reason,
            source=source,
        )


class CurrencyTransaction(models.Model):
    """
    Immutable coin transaction record.

    Every credit and debit to a user's VirtualCurrency wallet creates a
    transaction record for full audit trail and analytics.
    """
    TRANSACTION_TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='coin_transactions',
    )
    amount = models.IntegerField()                                         # Positive for credit, negative for debit
    transaction_type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    reason = models.CharField(max_length=255, blank=True, default='')
    source = models.CharField(max_length=100, blank=True, default='')      # e.g. 'habit_completion', 'streak_freeze_purchase'
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = 'currency_transactions'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email}: {self.amount:+d} coins ({self.reason})"


# =============================================================================
# Daily Bonus Tracker
# =============================================================================

class DailyBonus(models.Model):
    """
    Tracks daily engagement bonuses.

    Each row records whether a user has claimed their daily login bonus
    and/or the bonus for completing all habits that day. Used to prevent
    double-claiming and to calculate consecutive bonus days.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_bonuses',
    )
    date = models.DateField()
    login_bonus_claimed = models.BooleanField(default=False)
    all_done_bonus_claimed = models.BooleanField(default=False)
    xp_earned = models.IntegerField(default=0)
    coins_earned = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'daily_bonuses'
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.email} bonus {self.date}"


# =============================================================================
# Milestone Reward Definitions
# =============================================================================

class MilestoneReward(models.Model):
    """
    Defines rewards granted at specific milestone events.

    Milestones trigger automatically when a user reaches a certain level,
    streak count, or total completions. Each milestone can grant XP,
    coins, and/or a streak freeze.
    """
    MILESTONE_TYPES = [
        ('level_up', 'Level Up'),
        ('streak', 'Streak Milestone'),
        ('completions', 'Completion Milestone'),
        ('days_active', 'Days Active'),
    ]

    milestone_type = models.CharField(max_length=30, choices=MILESTONE_TYPES)
    threshold = models.IntegerField()                                      # The value that triggers this milestone
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')

    # --- Rewards ---
    xp_reward = models.IntegerField(default=0)
    coin_reward = models.IntegerField(default=0)
    streak_freeze_reward = models.IntegerField(default=0)                  # Number of free freezes

    # --- Display ---
    icon_code = models.IntegerField(default=0xE838)
    color_value = models.BigIntegerField(default=0xFFFFD700)
    celebration_type = models.CharField(max_length=50, default='confetti')  # confetti | fireworks | glow | shake

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'milestone_rewards'
        unique_together = ('milestone_type', 'threshold')
        ordering = ['milestone_type', 'threshold']

    def __str__(self):
        return f"{self.title} ({self.milestone_type} @ {self.threshold})"
