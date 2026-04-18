"""
Notification Models
===================
Defines the data models for the DailyHabits notification subsystem.

This module contains four core models:

- **Notification**: Stores inbox notifications for system events, social
  interactions, habit reminders, achievements, and admin announcements.
- **SmartTip**: Personalized, AI-generated habit guidance delivered to
  users based on their activity patterns and progress.
- **NotificationSettings**: Per-user notification preferences including
  quiet hours, channel toggles, and frequency limits.
- **HabitReminder**: User-configured, per-habit recurring reminders with
  flexible scheduling options.

All models use explicit ``db_table`` names and composite indexes
optimized for the most common query patterns (user + status, user + type).
"""

from django.db import models
from django.conf import settings


# =============================================================================
#  NOTIFICATION MODEL — inbox messages for system & social events
# =============================================================================

class Notification(models.Model):
    """
    Represents a single inbox notification delivered to a user.

    Notifications are created by :class:`~notifications.services.NotificationCreator`
    and cover both system-generated events (reminders, streaks, achievements) and
    social interactions (friend requests, group activity, likes/comments).

    Lifecycle:
        pending → sent → read / dismissed / snoozed

    Attributes:
        user: The recipient of the notification.
        notification_type: Category tag from ``NOTIFICATION_TYPES``.
        title: Short, human-readable headline.
        message: Full notification body text.
        status: Current lifecycle state (pending / sent / read / dismissed / snoozed).
        action_type: Deep-link target inside the mobile app.
        action_data: JSON payload passed to the deep-link handler.
        icon_code: Material-icon code point for front-end rendering.
        color_value: ARGB colour value for front-end badge/accent.
    """
    # ── Notification type choices ────────────────────────────────────────
    NOTIFICATION_TYPES = [
        # System / habit events
        ('reminder', 'Habit Reminder'),          # Scheduled habit reminder
        ('missed', 'Missed Habit Alert'),        # User missed a habit yesterday
        ('achievement', 'Achievement Earned'),   # New badge / achievement unlocked
        ('streak', 'Streak Milestone'),          # Streak reached a milestone (7, 30, …)
        ('streak_risk', 'Streak At Risk'),       # Streak about to break
        ('level_up', 'Level Up'),                # User levelled up in gamification
        ('system', 'System Notification'),       # Generic system message
        ('admin', 'Admin Announcement'),         # Broadcast from administrators
        ('security', 'Security Alert'),          # Password change, new device, etc.
        # Challenge events
        ('challenge', 'Challenge Update'),               # Personal/friend challenge events
        ('challenge_joined', 'Challenge Joined'),        # User joined a challenge
        ('challenge_ending', 'Challenge Ending Soon'),   # Challenge about to end
        ('challenge_completed', 'Challenge Completed'),  # User completed a challenge
        # Leaderboard events
        ('leaderboard', 'Leaderboard Update'),           # Rank change on leaderboard
        # Social / community events
        ('friend_request', 'Friend Request'),            # Incoming friend request
        ('friend_accepted', 'Friend Request Accepted'),  # Request was accepted
        ('group_join', 'Group Join'),                    # Someone joined a group
        ('group_approval', 'Group Approval'),            # Group membership approved
        ('group_challenge', 'Group Challenge Update'),   # Challenge progress update
        ('social_like', 'Post Liked'),                   # Someone liked a post
        ('social_comment', 'Post Comment'),              # Someone commented on a post
    ]

    # ── Deep-link action types (maps to Flutter route names) ────────────
    ACTION_TYPES = [
        ('none', 'No Action'),                   # No navigation on tap
        ('habit_detail', 'Open Habit Detail'),   # Navigate to a specific habit
        ('community', 'Open Community'),          # Open the community feed
        ('group_detail', 'Open Group Detail'),   # Open a specific group page
        ('profile', 'Open Profile'),              # Open user profile
        ('friend_requests', 'Open Friend Requests'),  # Open friend-request list
        ('achievements', 'Open Achievements'),   # Open achievements gallery
        ('settings', 'Open Settings'),            # Open app settings
        ('challenge_detail', 'Open Challenge'),  # Open a specific challenge
        ('leaderboard', 'Open Leaderboard'),     # Open the leaderboard screen
    ]

    # ── Notification lifecycle states ──────────────────────────────────────
    STATUS_CHOICES = [
        ('pending', 'Pending'),       # Created but not yet delivered
        ('sent', 'Sent'),             # Delivered to the user's inbox
        ('read', 'Read'),             # User viewed the notification
        ('dismissed', 'Dismissed'),   # User dismissed without reading
        ('snoozed', 'Snoozed'),       # Temporarily hidden, will resurface
    ]

    # ── Relationships ──────────────────────────────────────────────────
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    
    # ── Content fields ────────────────────────────────────────────────────
    id = models.AutoField(primary_key=True)
    notification_type = models.CharField(max_length=50, choices=NOTIFICATION_TYPES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    
    # ── Related objects (all optional — depend on notification_type) ───
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications'
    )
    achievement = models.ForeignKey(
        'achievements.Achievement',
        on_delete=models.CASCADE,
        null=True,
        blank=True
    )
    # Originator for social notifications (friend requests, likes, etc.)
    from_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sent_notifications'
    )
    group = models.ForeignKey(
        'social.GroupHabit',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications'
    )
    
    # ── Scheduling & timestamps ────────────────────────────────────────
    scheduled_time = models.DateTimeField(auto_now_add=True)    # When the notification was originally scheduled
    sent_at = models.DateTimeField(null=True, blank=True)       # Actual delivery timestamp
    read_at = models.DateTimeField(null=True, blank=True)       # When the user read the notification
    
    # ── Status & snooze ───────────────────────────────────────────────────
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='sent')
    snooze_until = models.DateTimeField(null=True, blank=True)  # Resurface time when status='snoozed'
    
    # ── Deep-link action (tells the Flutter app where to navigate) ─────
    action_type = models.CharField(max_length=50, choices=ACTION_TYPES, default='none')
    action_url = models.CharField(max_length=500, blank=True)   # Optional external URL
    action_data = models.JSONField(default=dict)                # Arbitrary payload (e.g. {'habitId': 42})
    
    # ── Visual presentation (Material icon code-point & ARGB colour) ───
    icon_code = models.IntegerField(default=0xE7F4)             # Default: notifications icon
    color_value = models.BigIntegerField(default=0xFF6366F1)    # Default: Indigo-400
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', 'notification_type']),
            models.Index(fields=['user', 'status', '-created_at']),
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        return f"{self.title} - {self.user.email}"

    @property
    def is_read(self):
        """Return ``True`` if the notification has been read by the user."""
        return self.status == 'read'

    def mark_as_read(self):
        """Transition the notification to *read* state and record the timestamp."""
        from django.utils import timezone
        self.status = 'read'
        self.read_at = timezone.now()
        self.save(update_fields=['status', 'read_at'])

    def snooze(self, minutes=30):
        """
        Snooze the notification for the given number of *minutes*.

        Sets ``status`` to ``'snoozed'`` and records ``snooze_until`` so the
        front-end (or a background task) can resurface it at the right time.

        Args:
            minutes: Duration to snooze in minutes (default 30).
        """
        from django.utils import timezone
        from datetime import timedelta
        self.status = 'snoozed'
        self.snooze_until = timezone.now() + timedelta(minutes=minutes)
        self.save(update_fields=['status', 'snooze_until'])


# =============================================================================
#  SMART TIP MODEL — personalized, AI-driven habit guidance
# =============================================================================

class SmartTip(models.Model):
    """
    Personalized habit guidance tips — calm, motivational, non-urgent.

    Smart tips are generated by :class:`~notifications.services.SmartTipService`
    and are designed to gently encourage users without the urgency of a
    standard notification.  Tips are ephemeral: they can be liked, saved,
    or dismissed, and expire after an optional ``expires_at`` date.

    Attributes:
        user: The tip recipient.
        tip_type: Category from ``TIP_TYPES`` (missed_habit, streak_close, …).
        title: Short headline for the tip card.
        message: Full guidance text.
        habit: Optionally linked habit for context.
        is_read / is_liked / is_saved / is_dismissed: Engagement flags.
        metadata: Arbitrary JSON (e.g. milestone thresholds, analytics data).
        expires_at: Optional expiration; tips past this date may be pruned.
    """
    # ── Tip category choices ────────────────────────────────────────────
    TIP_TYPES = [
        ('missed_habit', 'Missed Habit Encouragement'),   # User missed a habit recently
        ('streak_close', 'Near Streak Milestone'),        # One day away from a milestone
        ('declining', 'Declining Consistency'),            # Completion rate dropped >50%
        ('time_pattern', 'Time-based Pattern'),            # Based on time-of-day analysis
        ('category_tip', 'Category-based Tip'),            # Category-specific advice
        ('preference', 'User Preference Tip'),             # Derived from user preferences
        ('weekly', 'Weekly Insight'),                      # End-of-week summary tip
        ('general', 'General Wellness Tip'),               # Evergreen motivational tip
    ]

    # ── Relationships ──────────────────────────────────────────────────
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='smart_tips'
    )

    # ── Content fields ────────────────────────────────────────────────────
    id = models.AutoField(primary_key=True)
    tip_type = models.CharField(max_length=50, choices=TIP_TYPES, default='general')
    title = models.CharField(max_length=255)
    message = models.TextField()

    # ── Related habit (optional — some tips are generic) ──────────────
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='smart_tips'
    )

    # ── Visual presentation ────────────────────────────────────────────
    icon_code = models.IntegerField(default=0xE88E)            # Default: lightbulb icon
    color_value = models.BigIntegerField(default=0xFF14B8A6)   # Default: Teal-500

    # ── User engagement flags ─────────────────────────────────────────
    is_read = models.BooleanField(default=False)       # Tip was viewed by the user
    is_liked = models.BooleanField(default=False)      # User marked as helpful
    is_saved = models.BooleanField(default=False)      # User bookmarked for later
    is_dismissed = models.BooleanField(default=False)  # User dismissed (hides from feed)

    # ── Extra metadata (JSON) ─────────────────────────────────────────
    metadata = models.JSONField(default=dict, blank=True)  # e.g. {'milestone': 30}

    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'smart_tips'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_read']),
            models.Index(fields=['user', 'is_dismissed']),
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        return f"{self.title} - {self.user.email}"


# =============================================================================
#  NOTIFICATION SETTINGS MODEL — per-user notification preferences
# =============================================================================

class NotificationSettings(models.Model):
    """
    Per-user notification preferences and delivery controls.

    Created lazily (via ``get_or_create``) the first time a user accesses
    the notification-settings endpoint.  All boolean fields default to
    ``True`` so that new users receive all notifications out of the box.

    Attributes:
        notifications_enabled: Master kill-switch for all notifications.
        quiet_hours_enabled: When ``True``, suppress delivery between
            ``quiet_hours_start`` and ``quiet_hours_end``.
        max_notifications_per_day: Hard daily cap enforced by
            :meth:`~notifications.services.NotificationIntelligence.should_send_notification`.
        default_snooze_minutes: Default snooze duration presented in the UI.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_settings'
    )
    
    id = models.AutoField(primary_key=True)

    DELIVERY_MODE_CHOICES = [
        ('instant', 'Instant'),
        ('digest', 'Digest'),
    ]

    # ── Global delivery toggles ───────────────────────────────────────
    notifications_enabled = models.BooleanField(default=True)   # Master on/off switch
    sound_enabled = models.BooleanField(default=True)           # Play sound on delivery
    vibration_enabled = models.BooleanField(default=True)       # Vibrate on delivery
    
    # ── Per-category toggles ──────────────────────────────────────────
    habit_reminders = models.BooleanField(default=True)             # Scheduled habit reminders
    missed_habit_alerts = models.BooleanField(default=True)         # "You missed X" alerts
    achievement_notifications = models.BooleanField(default=True)   # Badge / achievement unlocks
    streak_alerts = models.BooleanField(default=True)               # Streak milestone alerts
    insight_notifications = models.BooleanField(default=True)       # Weekly insight digests
    motivational_quotes = models.BooleanField(default=True)         # Daily motivational quotes
    smart_tips_enabled = models.BooleanField(default=True)          # AI-generated smart tips
    social_notifications = models.BooleanField(default=True)        # Friend / group activity
    
    # ── Quiet hours (Do Not Disturb window) ───────────────────────────
    quiet_hours_enabled = models.BooleanField(default=False)
    quiet_hours_start = models.TimeField(null=True, blank=True)  # e.g. 22:00
    quiet_hours_end = models.TimeField(null=True, blank=True)    # e.g. 07:00
    
    # ── Frequency & throttling ────────────────────────────────────────
    reminder_minutes_before = models.IntegerField(default=15)    # Lead-time before habit's scheduled time
    max_notifications_per_day = models.IntegerField(default=20)  # Hard daily cap
    
    # ── Snooze preferences ────────────────────────────────────────────
    default_snooze_minutes = models.IntegerField(default=30)     # Default snooze length

    # ── Scheduling preferences ───────────────────────────────────────
    timezone = models.CharField(max_length=50, default='UTC')
    weekend_reminders_enabled = models.BooleanField(default=True)
    reminder_window_start = models.TimeField(null=True, blank=True)  # Optional delivery start window
    reminder_window_end = models.TimeField(null=True, blank=True)    # Optional delivery end window
    delivery_mode = models.CharField(max_length=20, choices=DELIVERY_MODE_CHOICES, default='instant')
    digest_time = models.TimeField(null=True, blank=True)
    cooldown_minutes = models.IntegerField(default=30)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'notification_settings'

    def __str__(self):
        return f"Notification Settings - {self.user.email}"


# =============================================================================
#  HABIT REMINDER MODEL — user-configured, per-habit recurring reminders
# =============================================================================

class HabitReminder(models.Model):
    """
    A user-configured recurring reminder tied to a specific habit.

    Reminders can fire once, daily, weekly, or on custom days of the week.
    The ``custom_days`` JSON field stores a list of ISO weekday integers
    (1 = Monday … 7 = Sunday) when ``repeat_type`` is ``'custom'``.

    Attributes:
        habit: The habit this reminder is attached to.
        reminder_time: Time of day the reminder should fire.
        repeat_type: Recurrence pattern (once / daily / weekly / custom).
        custom_days: List of weekday numbers for custom schedules.
        is_enabled: Toggle to pause/resume without deleting.
        message: Optional custom reminder text (falls back to default).
        last_sent: Timestamp of the most recent delivery.
    """
    # ── Recurrence pattern choices ──────────────────────────────────────
    REPEAT_CHOICES = [
        ('once', 'Once'),           # Fire exactly once then auto-disable
        ('daily', 'Daily'),         # Every day at reminder_time
        ('weekly', 'Weekly'),       # Same day each week
        ('custom', 'Custom Days'),  # User-selected weekdays (see custom_days)
    ]

    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='reminders'
    )
    
    # ── Timing & schedule ─────────────────────────────────────────────
    id = models.AutoField(primary_key=True)
    reminder_time = models.TimeField()                                          # Time of day (HH:MM)
    repeat_type = models.CharField(max_length=20, choices=REPEAT_CHOICES, default='daily')
    custom_days = models.JSONField(default=list)  # e.g. [1, 3, 5] for Mon/Wed/Fri
    
    # ── Reminder settings ─────────────────────────────────────────────
    is_enabled = models.BooleanField(default=True)          # Pause without deleting
    message = models.CharField(max_length=255, blank=True)  # Custom text override
    
    # ── Delivery tracking ─────────────────────────────────────────────
    last_sent = models.DateTimeField(null=True, blank=True)  # Most recent delivery
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_reminders'
        ordering = ['reminder_time']

    def __str__(self):
        return f"Reminder for {self.habit.title} at {self.reminder_time}"


# =============================================================================
#  DEVICE TOKEN MODEL — FCM push notification token storage
# =============================================================================

class DeviceToken(models.Model):
    """
    Stores Firebase Cloud Messaging (FCM) device tokens for push notifications.

    Each user may have multiple tokens (one per device). Tokens are
    registered when the Flutter app initialises and refreshed when FCM
    rotates them. Stale tokens are deactivated when the FCM API returns
    an ``UNREGISTERED`` error.

    Attributes:
        user: The owner of this device token.
        token: The FCM registration token string.
        device_type: Platform identifier (android / ios / web).
        device_name: Optional human-readable device label.
        is_active: Whether this token is valid for sending.
        last_used: Timestamp of the most recent successful push via this token.
    """
    DEVICE_TYPES = [
        ('android', 'Android'),
        ('ios', 'iOS'),
        ('web', 'Web'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='device_tokens',
    )
    id = models.AutoField(primary_key=True)
    token = models.TextField(unique=True)
    device_type = models.CharField(max_length=20, choices=DEVICE_TYPES, default='android')
    device_name = models.CharField(max_length=255, blank=True, default='')
    is_active = models.BooleanField(default=True)
    last_used = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'device_tokens'
        indexes = [
            models.Index(fields=['user', 'is_active']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.device_type} ({'active' if self.is_active else 'inactive'})"
