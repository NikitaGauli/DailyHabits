"""
Social / Community Models
=========================

Defines the data layer for all social and community features within DailyHabits.
This module contains models for:

- **Friendships** – Bidirectional friend requests with pending/accepted/rejected workflow.
- **Feed Posts** – Community activity feed entries (completions, streaks, achievements).
- **Post Interactions** – Likes and comments on feed posts.
- **Share Cards** – Auto-generated shareable summaries (daily, weekly, streak milestones).
- **Privacy Controls** – Per-habit granular privacy settings for sharing.
- **Referral System** – Invite links with usage caps, expiry, and tracking.
- **Group Habits** – Collaborative habit groups with invite codes and role-based membership.

All models use explicit ``db_table`` names and define ``__str__`` for admin readability.
"""

from django.db import models
from django.conf import settings
import uuid
from typing import TYPE_CHECKING


# ═══════════════════════════════════════════════════════════════════════════
#  FRIENDSHIP
# ═══════════════════════════════════════════════════════════════════════════

class Friendship(models.Model):
    """
    Bidirectional friendship between two users.

    The ``from_user`` initiates the request; ``to_user`` receives it.
    Status progresses through *pending → accepted* or *pending → rejected*.
    A unique constraint on (from_user, to_user) prevents duplicate requests.
    """

    STATUS_CHOICES = [
        ('pending', 'Pending'),       # Request sent, awaiting response
        ('accepted', 'Accepted'),     # Both users are now friends
        ('rejected', 'Rejected'),     # Request was declined
    ]

    # The user who initiated the friend request
    from_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_friend_requests',
    )
    # The user who receives the friend request
    to_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_friend_requests',
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'friendships'
        unique_together = ('from_user', 'to_user')  # Prevent duplicate requests
        ordering = ['-created_at']                   # Newest requests first

    def __str__(self):
        return f"{self.from_user.email} → {self.to_user.email} ({self.status})"

    # Django auto-generates `_id` attributes for FK fields
    if TYPE_CHECKING:
        from_user_id: int
        to_user_id: int


# ═══════════════════════════════════════════════════════════════════════════
#  FEED POSTS, LIKES, COMMENTS
# ═══════════════════════════════════════════════════════════════════════════

class FeedPost(models.Model):
    """
    A post in the community activity feed.

    Posts can represent habit completions, streak milestones, achievements,
    group updates, or free-form motivational messages. Each post optionally
    links to a specific ``Habit`` or ``GroupHabit`` for context.

    Denormalized ``like_count`` and ``comment_count`` fields are maintained
    for fast read performance on feed listing queries.
    """

    POST_TYPES = [
        ('completion', 'Habit Completion'),      # User completed a habit
        ('streak', 'Streak Milestone'),          # Streak milestone reached
        ('achievement', 'Achievement Earned'),   # Badge / achievement unlocked
        ('group_update', 'Group Update'),        # Activity within a group
        ('motivation', 'Motivational Post'),     # Free-form encouragement
    ]

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='feed_posts',
    )
    post_type = models.CharField(max_length=20, choices=POST_TYPES, default='completion')
    content = models.TextField(max_length=500)
    emoji = models.CharField(max_length=10, blank=True, default='')  # Optional reaction emoji

    # ── Optional foreign-key references ──────────────────────────────
    habit = models.ForeignKey(
        'habits.Habit', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='feed_posts',
    )
    group = models.ForeignKey(
        'social.GroupHabit', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='feed_posts',
    )

    # Denormalized counters – updated atomically on like/comment actions
    like_count = models.IntegerField(default=0)
    comment_count = models.IntegerField(default=0)

    # Flexible JSON blob for extra context (e.g. streak count, badge name)
    metadata = models.JSONField(default=dict, blank=True)

    is_public = models.BooleanField(default=True)  # False = friends-only visibility
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'feed_posts'
        ordering = ['-created_at']  # Newest posts first
        indexes = [
            # Composite index speeds up chronological feed queries per author
            models.Index(fields=['-created_at', 'author']),
        ]

    def __str__(self):
        return f"{self.author.email}: {self.content[:50]}"


class PostLike(models.Model):
    """
    A like (clap) on a feed post.

    Each user may like a given post only once; the unique constraint on
    (post, user) enforces this. Toggling is handled at the view layer by
    creating or deleting the ``PostLike`` row.
    """

    post = models.ForeignKey(FeedPost, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='post_likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'post_likes'
        unique_together = ('post', 'user')  # One like per user per post

    def __str__(self):
        return f"{self.user.email} liked post {self.post_id}"  # type: ignore[attr-defined]


class PostComment(models.Model):
    """
    A comment on a feed post.

    Comments are ordered chronologically (oldest first) so that
    conversation threads read naturally from top to bottom.
    """

    post = models.ForeignKey(FeedPost, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='post_comments',
    )
    content = models.TextField(max_length=300)  # Character limit enforced at DB level
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'post_comments'
        ordering = ['created_at']  # Chronological order for conversation flow

    def __str__(self):
        return f"{self.author.email}: {self.content[:40]}"


# ═══════════════════════════════════════════════════════════════════════════
#  SHARE CARDS
# ═══════════════════════════════════════════════════════════════════════════


class ShareCard(models.Model):
    """
    Auto-generated share cards for daily, weekly, and streak summaries.

    A ``ShareCard`` captures a snapshot of a user's progress over a date
    range and bundles it into a shareable format. Each card receives a
    unique ``share_token`` (UUID) for public-link access and carries
    customizable theming colours (``color_primary``, ``color_accent``).

    The ``card_data`` JSON field stores structured rendering data so the
    frontend can produce a visually rich card without additional API calls.
    """
    SHARE_TYPES = [
        ('daily', 'Daily Summary'),          # End-of-day snapshot
        ('weekly', 'Weekly Summary'),        # End-of-week rollup
        ('streak', 'Streak Milestone'),      # Streak achievement card
        ('achievement', 'Achievement Earned'),  # Badge unlock card
        ('custom', 'Custom Share'),          # User-created share
    ]

    STATUS_CHOICES = [
        ('draft', 'Draft'),      # Generated but not yet shared
        ('shared', 'Shared'),    # User has distributed the card
        ('expired', 'Expired'),  # Card is past its relevance window
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='share_cards'
    )

    id = models.AutoField(primary_key=True)
    share_type = models.CharField(max_length=50, choices=SHARE_TYPES)
    title = models.CharField(max_length=255)        # Headline text on the card
    subtitle = models.CharField(max_length=255, blank=True)  # Secondary text

    # ── Card rendering payload ───────────────────────────────────────
    card_data = models.JSONField(default=dict, help_text='Structured data for rendering the share card')

    # ── Summary statistics ───────────────────────────────────────────
    habits_completed = models.IntegerField(default=0)
    total_habits = models.IntegerField(default=0)
    streak_count = models.IntegerField(default=0)
    completion_rate = models.FloatField(default=0.0)  # Percentage (0-100)

    # ── Share metadata ───────────────────────────────────────────────
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    share_url = models.URLField(blank=True)           # Populated on first share
    shared_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')

    # ── Date range the card covers ───────────────────────────────────
    period_start = models.DateField()
    period_end = models.DateField()

    # ── Visual theming (hex colour codes) ────────────────────────────
    color_primary = models.CharField(max_length=10, default='#312C51')  # Dark purple
    color_accent = models.CharField(max_length=10, default='#F0C38E')   # Warm gold
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'share_cards'
        ordering = ['-created_at']  # Most recent cards first

    def __str__(self):
        return f"{self.share_type} card - {self.user.email} ({self.period_start})"


# ═══════════════════════════════════════════════════════════════════════════
#  SHARING PRIVACY
# ═══════════════════════════════════════════════════════════════════════════


class SharingPrivacy(models.Model):
    """
    Per-habit granular privacy controls for social sharing.

    Each row overrides the default sharing behaviour for a single habit,
    allowing users to opt out of daily/weekly summaries, streak shares,
    group visibility, or detail exposure independently.

    Habits without a corresponding ``SharingPrivacy`` row default to
    *all sharing enabled* (handled in ``SocialService.get_privacy_settings``).
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sharing_privacy'
    )
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='privacy_settings'
    )
    
    id = models.AutoField(primary_key=True)

    # ── Per-habit sharing toggles ────────────────────────────────────
    allow_in_summary = models.BooleanField(default=True, help_text='Include in daily/weekly share cards')
    allow_streak_share = models.BooleanField(default=True, help_text='Include streak milestones')
    allow_in_group = models.BooleanField(default=True, help_text='Visible in group habits')
    show_details = models.BooleanField(default=False, help_text='Show habit description/notes')
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sharing_privacy'
        unique_together = ('user', 'habit')  # One privacy record per user-habit pair

    def __str__(self):
        return f"Privacy: {self.habit.title} - {self.user.email}"


# ═══════════════════════════════════════════════════════════════════════════
#  REFERRAL SYSTEM
# ═══════════════════════════════════════════════════════════════════════════


class ReferralLink(models.Model):
    """
    Friend-invite referral link with usage limits and expiry.

    Each user may have one active referral link at a time.
    The ``is_valid`` property centralises the three validity checks:
    active flag, usage cap, and expiration timestamp.
    """
    referrer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referral_links'
    )
    code = models.CharField(max_length=12, unique=True)  # 8-char alpha-numeric code

    # ── Usage tracking ───────────────────────────────────────────────
    uses_count = models.IntegerField(default=0)    # Incremented on each successful referral
    max_uses = models.IntegerField(default=10)     # Hard cap on total uses
    is_active = models.BooleanField(default=True)  # Manual kill switch

    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)  # Null = never expires

    class Meta:
        db_table = 'referral_links'

    def __str__(self):
        return f"Referral {self.code} by {self.referrer.email}"

    @property
    def is_valid(self):
        """Check whether this referral link is still usable.

        Returns:
            bool: ``True`` if the link is active, under its usage cap,
                  and has not expired; ``False`` otherwise.
        """
        from django.utils import timezone
        if not self.is_active:
            return False
        if self.uses_count >= self.max_uses:
            return False
        if self.expires_at and timezone.now() > self.expires_at:
            return False
        return True


class Referral(models.Model):
    """
    Record of a successful referral between two users.

    Created when a new user signs up using a valid ``ReferralLink``.
    The ``referred_user`` is a ``OneToOneField`` ensuring each account
    can only be referred once.
    """
    referrer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referrals_made'
    )
    referred_user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referred_by'
    )
    referral_link = models.ForeignKey(
        ReferralLink,
        on_delete=models.SET_NULL,
        null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'referrals'

    def __str__(self):
        return f"{self.referrer.email} -> {self.referred_user.email}"


# ═══════════════════════════════════════════════════════════════════════════
#  GROUP HABITS
# ═══════════════════════════════════════════════════════════════════════════


class GroupHabit(models.Model):
    """
    A collaborative habit group that multiple users can join.

    Groups are created by a user (the ``creator`` / admin) and made
    discoverable via a unique 6-character ``invite_code``. Each group
    stores a ``habit_template`` JSON blob that defines the default habit
    configuration new members adopt on joining.

    Visual identity is defined by ``icon_code`` (Material icon codepoint)
    and ``color_value`` (ARGB integer used by the Flutter frontend).
    """
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)

    # Template JSON used to pre-populate a habit for each new member
    habit_template = models.JSONField(
        default=dict,
        help_text='Template data for creating the habit for each member'
    )

    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_groups'
    )

    id = models.AutoField(primary_key=True)
    invite_code = models.CharField(max_length=8, unique=True)  # 6-char unique join code
    max_members = models.IntegerField(default=20)               # Group capacity limit
    is_active = models.BooleanField(default=True)               # Soft-delete flag

    # ── Visual identity ──────────────────────────────────────────────
    icon_code = models.IntegerField(default=0xE7FB)          # Material icon codepoint
    color_value = models.BigIntegerField(default=0xFFF0C38E) # ARGB colour integer
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'group_habits'
        ordering = ['-created_at']

    def __str__(self):
        return self.name

    @property
    def member_count(self):
        """Return the current number of members in this group."""
        return self.members.count()  # type: ignore[attr-defined]


class GroupMember(models.Model):
    """
    Membership record linking a user to a ``GroupHabit``.

    Each member has a ``role`` (admin or member) and an optional
    linked ``Habit`` representing their personal instance of the
    group's shared habit. The ``is_active`` flag supports soft
    removal without losing historical data.
    """
    ROLE_CHOICES = [
        ('admin', 'Admin'),    # Can manage group settings and members
        ('member', 'Member'),  # Standard participant
    ]

    group = models.ForeignKey(
        GroupHabit,
        on_delete=models.CASCADE,
        related_name='members'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='group_memberships'
    )
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text='The user\'s personal habit linked to this group'
    )
    
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'group_members'
        unique_together = ('group', 'user')

    def __str__(self):
        return f"{self.user.email} in {self.group.name}"


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT SHARING — Friend-Based Habit Visibility
# ═══════════════════════════════════════════════════════════════════════════


class SharedHabit(models.Model):
    """
    Tracks an individual habit sharing relationship between two users.

    When a user shares a habit with a friend, a ``SharedHabit`` row is
    created linking the habit to the recipient. This enables fine-grained
    control over who can see, comment on, and react to each habit.

    The ``shared_by`` field always references the **habit owner**, and
    ``shared_with`` references the **recipient friend**. Sharing requires
    an active ``Friendship(status='accepted')`` — enforced at the API level.

    Permissions:
        - ``can_comment``: Whether the recipient can leave comments.
        - ``can_react``: Whether the recipient can add emoji reactions.

    Security:
        - Visibility is enforced at the API layer via ``CanViewSharedHabit``.
        - Only the habit owner can create or revoke shares.
        - The unique constraint on ``(habit, shared_with)`` prevents
          duplicate sharing with the same friend.
    """

    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='shares',
        help_text='The habit being shared.',
    )

    # The user who owns and shares the habit
    shared_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='habits_shared_out',
        help_text='User who shared the habit (must be the habit owner).',
    )

    # The friend who receives access to view the habit
    shared_with = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='habits_shared_in',
        help_text='Friend who was granted access to view this habit.',
    )

    # ── Granular permissions for the recipient ────────────────────────
    can_comment = models.BooleanField(
        default=True,
        help_text='Whether the recipient can comment on this habit.',
    )
    can_react = models.BooleanField(
        default=True,
        help_text='Whether the recipient can react to this habit.',
    )

    shared_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'shared_habits'
        unique_together = ('habit', 'shared_with')  # No duplicate shares
        ordering = ['-shared_at']
        indexes = [
            # "What habits have been shared with me?" — ordered by recency
            models.Index(fields=['shared_with', '-shared_at']),
            # "Who did I share this habit with?"
            models.Index(fields=['habit', 'shared_by']),
        ]

    def __str__(self):
        return (
            f"{self.shared_by.email} shared "
            f"'{self.habit.title}' with {self.shared_with.email}"
        )


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT REACTIONS — Emoji Engagement on Shared Habits
# ═══════════════════════════════════════════════════════════════════════════


class HabitReaction(models.Model):
    """
    An emoji reaction on a shared habit.

    Users can react with one of five predefined reaction types to
    encourage their friends. Each user may add at most one reaction
    of each type per habit — enforced by the unique constraint on
    ``(habit, user, reaction_type)``.

    Toggling is handled at the view layer: if the reaction already
    exists it is deleted (un-react), otherwise a new one is created.

    Reaction types and their intended meanings:
        - ``like``      — General appreciation  👍
        - ``encourage`` — Motivational support  💪
        - ``celebrate`` — Celebration           🎉
        - ``fire``      — Streak/momentum hype  🔥
        - ``clap``      — Applause              👏
    """

    REACTION_TYPES = [
        ('like', '👍 Like'),
        ('encourage', '💪 Encourage'),
        ('celebrate', '🎉 Celebrate'),
        ('fire', '🔥 Fire'),
        ('clap', '👏 Clap'),
    ]

    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='reactions',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='habit_reactions',
    )
    reaction_type = models.CharField(
        max_length=20,
        choices=REACTION_TYPES,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_reactions'
        # Each user can only have one of each reaction type per habit
        unique_together = ('habit', 'user', 'reaction_type')
        indexes = [
            # Aggregate reaction counts per habit
            models.Index(fields=['habit', 'reaction_type']),
        ]

    def __str__(self):
        return f"{self.user.email} reacted {self.reaction_type} on '{self.habit.title}'"


# ═══════════════════════════════════════════════════════════════════════════
#  HABIT COMMENTS — Discussion on Shared Habits
# ═══════════════════════════════════════════════════════════════════════════


class HabitComment(models.Model):
    """
    A comment on a shared or public habit.

    Comments enable friends to leave encouraging messages, tips, or
    questions on shared habits. Comments are ordered chronologically
    (oldest first) so conversation threads read naturally.

    Access control:
        - Only users with visibility access (owner, shared-with, or
          public viewers) can read comments.
        - Only users with ``SharedHabit.can_comment=True`` (or the
          habit owner) can create comments.
        - Comment length is capped at 300 characters at the DB level.
    """

    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='habit_comments',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='authored_habit_comments',
    )
    content = models.TextField(
        max_length=300,
        help_text='Comment text (max 300 characters).',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_comments'
        ordering = ['created_at']  # Chronological conversation order
        indexes = [
            # List comments for a habit, newest first
            models.Index(fields=['habit', '-created_at']),
        ]

    def __str__(self):
        return f"{self.author.email}: {self.content[:40]}"


# ═══════════════════════════════════════════════════════════════════════════
#  GROUP CHALLENGES — Collaborative habit goals within groups
# ═══════════════════════════════════════════════════════════════════════════


class GroupChallenge(models.Model):
    """
    A time-bound collaborative challenge within a ``GroupHabit``.

    Group admins can create challenges that all members work toward
    together. Each challenge defines a target metric (total completions,
    streak days, etc.) and a deadline.

    Members participate by completing their linked group habit; progress
    is aggregated across all participants.

    Status lifecycle:
        active → completed (target met) or expired (deadline passed)
    """

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('expired', 'Expired'),
    ]

    group = models.ForeignKey(
        GroupHabit,
        on_delete=models.CASCADE,
        related_name='challenges',
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_group_challenges',
    )

    id = models.AutoField(primary_key=True)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)

    # Goal definition
    target_type = models.CharField(
        max_length=30,
        choices=[
            ('completions', 'Total Completions'),
            ('streak', 'Streak Days'),
            ('all_done', 'All-Done Days'),
        ],
        default='completions',
    )
    target_value = models.IntegerField(default=50)
    current_progress = models.IntegerField(default=0)

    # Time bounds
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')

    # Rewards
    xp_reward = models.IntegerField(default=50)
    coin_reward = models.IntegerField(default=10)

    # Visual
    icon_code = models.IntegerField(default=0xE838)
    color_value = models.BigIntegerField(default=0xFFF59E0B)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'group_challenges'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} in {self.group.name}"

    @property
    def progress_percentage(self):
        if self.target_value == 0:
            return 100.0
        return min(100.0, round(self.current_progress / self.target_value * 100, 1))

    @property
    def is_active(self):
        from django.utils import timezone as tz
        now = tz.now()
        return self.start_date <= now <= self.end_date and self.status == 'active'


# ═══════════════════════════════════════════════════════════════════════════
#  ENCOURAGEMENT — Direct motivational nudges between friends
# ═══════════════════════════════════════════════════════════════════════════


class Encouragement(models.Model):
    """
    A direct encouragement message from one user to another.

    Unlike reactions (which are on habits), encouragements are
    person-to-person motivational nudges. They can optionally
    reference a specific habit.
    """

    ENCOURAGE_TYPES = [
        ('cheer', '🎉 Cheer'),
        ('motivate', '💪 Motivate'),
        ('celebrate', '🏆 Celebrate'),
        ('remind', '⏰ Gentle Reminder'),
    ]

    from_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='encouragements_sent',
    )
    to_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='encouragements_received',
    )
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='encouragements',
    )
    encourage_type = models.CharField(max_length=20, choices=ENCOURAGE_TYPES, default='cheer')
    message = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'encouragements'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.from_user.email} → {self.to_user.email}: {self.encourage_type}"
