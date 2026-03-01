"""
Grow Together — Collaborative Habit Sharing Models
===================================================

Defines the data layer for the "Grow Together" habit sharing system, enabling
users to share habits with friends, groups, or the public community, and to
track progress collaboratively with accountability features.

Models:
    - **CollaborativeHabit** — A shared habit that multiple users track together.
    - **CollaborativeHabitMember** — Membership record linking users to a shared habit.
    - **CollaborativeHabitProgress** — Daily progress records per member.
    - **HabitInvite** — Invitation to join a collaborative habit.
    - **HabitActivityLog** — Audit trail of all actions within a shared habit.
    - **ProgressReaction** — Emoji reactions on individual progress entries.
    - **ProgressComment** — Comments on individual progress entries.
    - **WeeklyLeaderboard** — Cached weekly ranking snapshots.
    - **GroupMilestone** — Pre-defined group milestones with XP rewards.
    - **AbuseReport** — User-submitted abuse reports for moderation.

All models use UUID primary keys, explicit ``db_table`` names, and define
``__str__`` for admin readability.
"""

import uuid
from typing import TYPE_CHECKING

from django.db import models
from django.conf import settings
from django.utils import timezone

if TYPE_CHECKING:
    from django.db.models.manager import RelatedManager


# ═══════════════════════════════════════════════════════════════════════════
#  COLLABORATIVE HABIT
# ═══════════════════════════════════════════════════════════════════════════

class CollaborativeHabit(models.Model):
    """
    A habit that multiple users can track together.

    The ``owner`` creates the habit and can invite friends, share it with
    a group, or make it public. Privacy types control discoverability:

    - ``private``       — Only explicitly invited users can join.
    - ``friends_only``  — Any friend of the owner can join.
    - ``public``        — Anyone can discover and join.

    An optional ``source_habit`` links back to the owner's original habit
    if the collaborative habit was created from an existing personal habit.
    """

    PRIVACY_CHOICES = [
        ('private', 'Private'),
        ('friends_only', 'Friends Only'),
        ('public', 'Public'),
    ]

    FREQUENCY_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('custom', 'Custom Days'),
    ]

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('paused', 'Paused'),
        ('archived', 'Archived'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # ── Core fields ──────────────────────────────────────────────────
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    emoji = models.CharField(max_length=10, blank=True, default='🎯')

    # ── Ownership ────────────────────────────────────────────────────
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='owned_collaborative_habits',
    )
    source_habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='collaborative_instances',
        help_text='Original personal habit this was created from.',
    )
    group = models.ForeignKey(
        'social.GroupHabit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='collaborative_habits',
        help_text='Group this shared habit belongs to (optional).',
    )

    # ── Scheduling ───────────────────────────────────────────────────
    frequency = models.CharField(
        max_length=10, choices=FREQUENCY_CHOICES, default='daily',
    )
    custom_days = models.JSONField(
        default=list, blank=True,
        help_text='List of weekday indices (0=Mon..6=Sun) for custom frequency.',
    )
    target_count = models.IntegerField(
        default=1,
        help_text='Number of times per day/period to complete this habit.',
    )

    # ── Privacy & visibility ─────────────────────────────────────────
    privacy = models.CharField(
        max_length=15, choices=PRIVACY_CHOICES, default='friends_only',
    )
    max_members = models.IntegerField(default=50)

    # ── Visual identity ──────────────────────────────────────────────
    icon_code = models.IntegerField(default=0xE87C)
    color_value = models.BigIntegerField(default=0xFF4F46E5)

    # ── Status ───────────────────────────────────────────────────────
    status = models.CharField(
        max_length=10, choices=STATUS_CHOICES, default='active',
    )
    is_active = models.BooleanField(default=True)

    # ── Denormalized counters ────────────────────────────────────────
    member_count = models.IntegerField(default=1)
    total_completions = models.IntegerField(default=0)

    # ── Gamification ─────────────────────────────────────────────────
    xp_per_completion = models.IntegerField(
        default=15,
        help_text='XP awarded to a member when they complete this habit.',
    )
    bonus_all_complete_xp = models.IntegerField(
        default=25,
        help_text='Bonus XP when ALL members complete on the same day.',
    )

    # ── Timestamps ───────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'gt_collaborative_habits'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['owner', '-created_at']),
            models.Index(fields=['privacy', 'is_active']),
            models.Index(fields=['group', '-created_at']),
        ]

    def __str__(self):
        return f"{self.title} (by {self.owner.email})"

    # ── Reverse-manager type hints for Pylance/pyright ───────────────
    if TYPE_CHECKING:
        members: RelatedManager['CollaborativeHabitMember']
        progress_records: RelatedManager['CollaborativeHabitProgress']
        invites: RelatedManager['HabitInvite']
        activity_logs: RelatedManager['HabitActivityLog']
        leaderboards: RelatedManager['WeeklyLeaderboard']


# ═══════════════════════════════════════════════════════════════════════════
#  COLLABORATIVE HABIT MEMBER
# ═══════════════════════════════════════════════════════════════════════════

class CollaborativeHabitMember(models.Model):
    """
    Membership record linking a user to a ``CollaborativeHabit``.

    Roles:
        - ``owner``     — Created the habit; can manage everything.
        - ``admin``     — Can invite/remove members and manage settings.
        - ``member``    — Standard participant.

    Each member has their own streak tracking and XP accumulation
    within the context of this collaborative habit.
    """

    ROLE_CHOICES = [
        ('owner', 'Owner'),
        ('admin', 'Admin'),
        ('member', 'Member'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='members',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='collaborative_memberships',
    )
    linked_habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='collaborative_links',
        help_text="User's personal habit linked to track progress.",
    )

    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='member')
    is_active = models.BooleanField(default=True)

    # ── Individual tracking ──────────────────────────────────────────
    current_streak = models.IntegerField(default=0)
    best_streak = models.IntegerField(default=0)
    total_completions = models.IntegerField(default=0)
    total_xp_earned = models.IntegerField(default=0)
    last_completed_date = models.DateField(null=True, blank=True)

    # ── Timestamps ───────────────────────────────────────────────────
    joined_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'gt_collaborative_members'
        unique_together = ('collaborative_habit', 'user')
        ordering = ['-joined_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['collaborative_habit', 'is_active', '-current_streak']),
        ]

    def __str__(self):
        return f"{self.user.email} in '{self.collaborative_habit.title}'"

    if TYPE_CHECKING:
        user_id: int


# ═══════════════════════════════════════════════════════════════════════════
#  COLLABORATIVE HABIT PROGRESS
# ═══════════════════════════════════════════════════════════════════════════

class CollaborativeHabitProgress(models.Model):
    """
    Daily progress record for a single member in a collaborative habit.

    Records whether a member completed the habit on a given date, how
    many times (for multi-count habits), and any optional note. This
    enables the live progress dashboard showing each member's daily status.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='progress_records',
    )
    member = models.ForeignKey(
        CollaborativeHabitMember,
        on_delete=models.CASCADE,
        related_name='progress_records',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='collaborative_progress',
        help_text='Denormalized for fast per-user queries.',
    )

    date = models.DateField(default=timezone.now)
    completed = models.BooleanField(default=False)
    completion_count = models.IntegerField(
        default=0,
        help_text='How many times completed today (for multi-count habits).',
    )
    note = models.CharField(max_length=500, blank=True, default='')

    # ── Gamification ─────────────────────────────────────────────────
    xp_earned = models.IntegerField(default=0)

    # ── Timestamps ───────────────────────────────────────────────────
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'gt_collaborative_progress'
        unique_together = ('member', 'date')
        ordering = ['-date', '-completed_at']
        indexes = [
            models.Index(fields=['collaborative_habit', 'date']),
            models.Index(fields=['user', 'date']),
            models.Index(fields=['collaborative_habit', 'date', 'completed']),
        ]

    def __str__(self):
        status = '✅' if self.completed else '⬜'
        return f"{status} {self.user.email} on {self.date}"


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT INVITE
# ═══════════════════════════════════════════════════════════════════════════

class HabitInvite(models.Model):
    """
    Invitation to join a collaborative habit.

    Invitations are sent by the habit owner or an admin and must be
    accepted by the recipient before they become a member. Each invite
    is uniquely constrained on (collaborative_habit, invited_user) to
    prevent duplicate invitations.

    Status lifecycle:
        pending → accepted | declined | expired
    """

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('declined', 'Declined'),
        ('expired', 'Expired'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='invites',
    )
    invited_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_invites_sent',
    )
    invited_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_invites_received',
    )

    status = models.CharField(
        max_length=10, choices=STATUS_CHOICES, default='pending',
    )
    message = models.CharField(
        max_length=300, blank=True, default='',
        help_text='Optional personal message from the inviter.',
    )

    # ── Expiry ───────────────────────────────────────────────────────
    expires_at = models.DateTimeField(
        null=True, blank=True,
        help_text='Auto-expire invites after this time.',
    )

    # ── Timestamps ───────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'gt_habit_invites'
        unique_together = ('collaborative_habit', 'invited_user')
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['invited_user', 'status']),
            models.Index(fields=['collaborative_habit', 'status']),
        ]

    def __str__(self):
        return (
            f"Invite: {self.invited_user.email} → "
            f"'{self.collaborative_habit.title}' ({self.status})"
        )

    @property
    def is_expired(self):
        if self.expires_at and timezone.now() > self.expires_at:
            return True
        return False


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT ACTIVITY LOG
# ═══════════════════════════════════════════════════════════════════════════

class HabitActivityLog(models.Model):
    """
    Audit trail of all significant actions within a collaborative habit.

    Every meaningful event (join, leave, complete, react, comment, milestone)
    is recorded here, powering the real-time activity feed displayed on the
    shared habit dashboard.
    """

    ACTION_CHOICES = [
        ('created', 'Habit Created'),
        ('joined', 'Member Joined'),
        ('left', 'Member Left'),
        ('removed', 'Member Removed'),
        ('completed', 'Completed Habit'),
        ('streak_milestone', 'Streak Milestone'),
        ('group_milestone', 'Group Milestone'),
        ('reacted', 'Reacted to Progress'),
        ('commented', 'Commented on Progress'),
        ('invited', 'Invitation Sent'),
        ('invite_accepted', 'Invitation Accepted'),
        ('settings_changed', 'Settings Changed'),
        ('all_completed', 'All Members Completed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='activity_logs',
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_activity_logs',
    )
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='gt_targeted_logs',
        help_text='The user this action was performed on, if applicable.',
    )

    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    description = models.CharField(max_length=500, blank=True, default='')
    metadata = models.JSONField(
        default=dict, blank=True,
        help_text='Extra context (streak count, milestone name, etc.).',
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gt_activity_logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['collaborative_habit', '-created_at']),
            models.Index(fields=['actor', '-created_at']),
        ]

    def __str__(self):
        return f"{self.actor.email}: {self.action} in '{self.collaborative_habit.title}'"


# ═══════════════════════════════════════════════════════════════════════════
#  PROGRESS REACTION
# ═══════════════════════════════════════════════════════════════════════════

class ProgressReaction(models.Model):
    """
    Emoji reaction on a specific progress entry.

    Members can react to each other's daily progress with one of five
    predefined reaction types. Each user may add at most one reaction
    of each type per progress entry.
    """

    REACTION_TYPES = [
        ('fire', '🔥 Fire'),
        ('clap', '👏 Clap'),
        ('heart', '❤️ Heart'),
        ('celebrate', '🎉 Celebrate'),
        ('strong', '💪 Strong'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    progress = models.ForeignKey(
        CollaborativeHabitProgress,
        on_delete=models.CASCADE,
        related_name='reactions',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_progress_reactions',
    )
    reaction_type = models.CharField(max_length=15, choices=REACTION_TYPES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gt_progress_reactions'
        unique_together = ('progress', 'user', 'reaction_type')
        indexes = [
            models.Index(fields=['progress', 'reaction_type']),
        ]

    def __str__(self):
        return f"{self.user.email} → {self.reaction_type} on {self.progress}"


# ═══════════════════════════════════════════════════════════════════════════
#  PROGRESS COMMENT
# ═══════════════════════════════════════════════════════════════════════════

class ProgressComment(models.Model):
    """
    Comment on a specific progress entry.

    Enables members to leave encouraging messages, tips, or questions
    on each other's daily progress. Ordered chronologically.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    progress = models.ForeignKey(
        CollaborativeHabitProgress,
        on_delete=models.CASCADE,
        related_name='comments',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_progress_comments',
    )
    content = models.TextField(max_length=300)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gt_progress_comments'
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['progress', '-created_at']),
        ]

    def __str__(self):
        return f"{self.author.email}: {self.content[:40]}"


# ═══════════════════════════════════════════════════════════════════════════
#  WEEKLY LEADERBOARD
# ═══════════════════════════════════════════════════════════════════════════

class WeeklyLeaderboard(models.Model):
    """
    Cached weekly ranking snapshot for a collaborative habit.

    Rebuilt every Monday (or on-demand). Stores the top contributors
    for the week, enabling fast leaderboard queries without real-time
    aggregation.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='leaderboards',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_leaderboard_entries',
    )

    week_start = models.DateField()
    week_end = models.DateField()
    rank = models.IntegerField()
    completions = models.IntegerField(default=0)
    streak_days = models.IntegerField(default=0)
    xp_earned = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gt_weekly_leaderboard'
        unique_together = ('collaborative_habit', 'user', 'week_start')
        ordering = ['rank']
        indexes = [
            models.Index(fields=['collaborative_habit', 'week_start', 'rank']),
        ]

    def __str__(self):
        return f"#{self.rank} {self.user.email} — Week of {self.week_start}"


# ═══════════════════════════════════════════════════════════════════════════
#  GROUP MILESTONE
# ═══════════════════════════════════════════════════════════════════════════

class GroupMilestone(models.Model):
    """
    Pre-defined or auto-generated milestones for collaborative habits.

    Milestones fire notifications and award XP when the group reaches
    certain thresholds (e.g., 7-day group streak, 100% team completion day,
    30-day consistency).
    """

    MILESTONE_TYPES = [
        ('group_streak_7', '7-Day Group Streak'),
        ('group_streak_30', '30-Day Group Streak'),
        ('all_complete_day', '100% Team Completion Day'),
        ('total_completions_100', '100 Total Completions'),
        ('total_completions_500', '500 Total Completions'),
        ('member_streak_30', 'Member 30-Day Streak'),
        ('consistency_30', '30-Day Consistency'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='milestones',
    )

    milestone_type = models.CharField(max_length=30, choices=MILESTONE_TYPES)
    title = models.CharField(max_length=200)
    description = models.CharField(max_length=500, blank=True, default='')

    xp_reward = models.IntegerField(default=50)
    achieved = models.BooleanField(default=False)
    achieved_at = models.DateTimeField(null=True, blank=True)
    achieved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='gt_achieved_milestones',
        help_text='The user who triggered the milestone (if individual).',
    )

    # ── Visual ───────────────────────────────────────────────────────
    icon_code = models.IntegerField(default=0xE838)
    badge_emoji = models.CharField(max_length=10, default='🏆')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gt_group_milestones'
        unique_together = ('collaborative_habit', 'milestone_type')
        ordering = ['created_at']

    def __str__(self):
        status = '✅' if self.achieved else '⬜'
        return f"{status} {self.title} — {self.collaborative_habit.title}"


# ═══════════════════════════════════════════════════════════════════════════
#  ABUSE REPORT
# ═══════════════════════════════════════════════════════════════════════════

class AbuseReport(models.Model):
    """
    User-submitted abuse report for collaborative habit content.

    Allows members to report inappropriate behaviour, spam, or
    harassment within shared habits. Reports are reviewed by moderators.
    """

    REASON_CHOICES = [
        ('spam', 'Spam'),
        ('harassment', 'Harassment'),
        ('inappropriate', 'Inappropriate Content'),
        ('impersonation', 'Impersonation'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('reviewed', 'Reviewed'),
        ('resolved', 'Resolved'),
        ('dismissed', 'Dismissed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_abuse_reports_filed',
    )
    reported_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='gt_abuse_reports_against',
    )
    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='abuse_reports',
    )

    reason = models.CharField(max_length=20, choices=REASON_CHOICES)
    description = models.TextField(max_length=1000)
    status = models.CharField(
        max_length=10, choices=STATUS_CHOICES, default='pending',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'gt_abuse_reports'
        ordering = ['-created_at']

    def __str__(self):
        return f"Report: {self.reporter.email} → {self.reported_user.email} ({self.reason})"


# ═══════════════════════════════════════════════════════════════════════════
#  STREAK FREEZE
# ═══════════════════════════════════════════════════════════════════════════

class StreakFreeze(models.Model):
    """
    Streak freeze / protection token for a collaborative habit member.

    Members earn or purchase streak freezes that automatically activate
    when they miss a day, preventing their streak from resetting.

    Lifecycle:
        available → used (auto-consumed on missed day)
        available → expired (if the freeze has an expiry date)

    Each member can hold a maximum number of freezes (configurable per habit).
    """

    STATUS_CHOICES = [
        ('available', 'Available'),
        ('used', 'Used'),
        ('expired', 'Expired'),
    ]

    SOURCE_CHOICES = [
        ('earned', 'Earned from streak milestone'),
        ('purchased', 'Purchased with XP'),
        ('gifted', 'Gifted by teammate'),
        ('bonus', 'Weekly bonus'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    member = models.ForeignKey(
        CollaborativeHabitMember,
        on_delete=models.CASCADE,
        related_name='streak_freezes',
    )
    collaborative_habit = models.ForeignKey(
        CollaborativeHabit,
        on_delete=models.CASCADE,
        related_name='streak_freezes',
    )

    status = models.CharField(
        max_length=10, choices=STATUS_CHOICES, default='available',
    )
    source = models.CharField(
        max_length=10, choices=SOURCE_CHOICES, default='earned',
    )

    used_on_date = models.DateField(
        null=True, blank=True,
        help_text='The date this freeze was consumed to protect a streak.',
    )
    expires_at = models.DateTimeField(
        null=True, blank=True,
        help_text='Optional expiry for this freeze token.',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'gt_streak_freezes'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['member', 'status']),
            models.Index(fields=['collaborative_habit', 'status']),
        ]

    def __str__(self):
        return (
            f"StreakFreeze({self.status}) for "
            f"{self.member.user.email} in '{self.collaborative_habit.title}'"
        )

    @property
    def is_expired(self):
        if self.expires_at and timezone.now() > self.expires_at:
            return True
        return False
