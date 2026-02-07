"""
Notification Models
Reminders, alerts, and notification management
"""

from django.db import models
from django.conf import settings


class Notification(models.Model):
    """
    User notifications
    """
    NOTIFICATION_TYPES = [
        # System / habit
        ('reminder', 'Habit Reminder'),
        ('missed', 'Missed Habit Alert'),
        ('achievement', 'Achievement Earned'),
        ('streak', 'Streak Milestone'),
        ('level_up', 'Level Up'),
        ('system', 'System Notification'),
        ('admin', 'Admin Announcement'),
        ('security', 'Security Alert'),
        # Social
        ('friend_request', 'Friend Request'),
        ('friend_accepted', 'Friend Request Accepted'),
        ('group_join', 'Group Join'),
        ('group_approval', 'Group Approval'),
        ('group_challenge', 'Group Challenge Update'),
        ('social_like', 'Post Liked'),
        ('social_comment', 'Post Comment'),
    ]

    ACTION_TYPES = [
        ('none', 'No Action'),
        ('habit_detail', 'Open Habit Detail'),
        ('community', 'Open Community'),
        ('group_detail', 'Open Group Detail'),
        ('profile', 'Open Profile'),
        ('friend_requests', 'Open Friend Requests'),
        ('achievements', 'Open Achievements'),
        ('settings', 'Open Settings'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('read', 'Read'),
        ('dismissed', 'Dismissed'),
        ('snoozed', 'Snoozed'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    
    # Content
    id = models.AutoField(primary_key=True)
    notification_type = models.CharField(max_length=50, choices=NOTIFICATION_TYPES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    
    # Related objects
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
    # For social notifications
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
    
    # Scheduling
    scheduled_time = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    
    # Status
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='sent')
    snooze_until = models.DateTimeField(null=True, blank=True)
    
    # Deep-link action
    action_type = models.CharField(max_length=50, choices=ACTION_TYPES, default='none')
    action_url = models.CharField(max_length=500, blank=True)
    action_data = models.JSONField(default=dict)
    
    # Visual
    icon_code = models.IntegerField(default=0xE7F4)
    color_value = models.BigIntegerField(default=0xFF6366F1)
    
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
        return self.status == 'read'

    def mark_as_read(self):
        """Mark notification as read"""
        from django.utils import timezone
        self.status = 'read'
        self.read_at = timezone.now()
        self.save(update_fields=['status', 'read_at'])

    def snooze(self, minutes=30):
        """Snooze notification"""
        from django.utils import timezone
        from datetime import timedelta
        self.status = 'snoozed'
        self.snooze_until = timezone.now() + timedelta(minutes=minutes)
        self.save(update_fields=['status', 'snooze_until'])


class SmartTip(models.Model):
    """
    Personalized habit guidance tips — calm, motivational, non-urgent.
    """
    TIP_TYPES = [
        ('missed_habit', 'Missed Habit Encouragement'),
        ('streak_close', 'Near Streak Milestone'),
        ('declining', 'Declining Consistency'),
        ('time_pattern', 'Time-based Pattern'),
        ('category_tip', 'Category-based Tip'),
        ('preference', 'User Preference Tip'),
        ('weekly', 'Weekly Insight'),
        ('general', 'General Wellness Tip'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='smart_tips'
    )

    id = models.AutoField(primary_key=True)
    tip_type = models.CharField(max_length=50, choices=TIP_TYPES, default='general')
    title = models.CharField(max_length=255)
    message = models.TextField()

    # Related habit (optional)
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='smart_tips'
    )

    # Visual
    icon_code = models.IntegerField(default=0xE88E)
    color_value = models.BigIntegerField(default=0xFF14B8A6)

    # Engagement
    is_read = models.BooleanField(default=False)
    is_liked = models.BooleanField(default=False)
    is_saved = models.BooleanField(default=False)
    is_dismissed = models.BooleanField(default=False)

    # Metadata
    metadata = models.JSONField(default=dict, blank=True)

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


class NotificationSettings(models.Model):
    """
    User notification preferences
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_settings'
    )
    
    id = models.AutoField(primary_key=True)
    # Global settings
    notifications_enabled = models.BooleanField(default=True)
    sound_enabled = models.BooleanField(default=True)
    vibration_enabled = models.BooleanField(default=True)
    
    # Type-specific settings
    habit_reminders = models.BooleanField(default=True)
    missed_habit_alerts = models.BooleanField(default=True)
    achievement_notifications = models.BooleanField(default=True)
    streak_alerts = models.BooleanField(default=True)
    insight_notifications = models.BooleanField(default=True)
    motivational_quotes = models.BooleanField(default=True)
    smart_tips_enabled = models.BooleanField(default=True)
    social_notifications = models.BooleanField(default=True)
    
    # Quiet hours
    quiet_hours_enabled = models.BooleanField(default=False)
    quiet_hours_start = models.TimeField(null=True, blank=True)
    quiet_hours_end = models.TimeField(null=True, blank=True)
    
    # Frequency
    reminder_minutes_before = models.IntegerField(default=15)
    max_notifications_per_day = models.IntegerField(default=20)
    
    # Snooze preferences
    default_snooze_minutes = models.IntegerField(default=30)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'notification_settings'

    def __str__(self):
        return f"Notification Settings - {self.user.email}"


class HabitReminder(models.Model):
    """
    Specific habit reminders
    """
    REPEAT_CHOICES = [
        ('once', 'Once'),
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('custom', 'Custom Days'),
    ]

    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='reminders'
    )
    
    # Timing
    id = models.AutoField(primary_key=True)
    reminder_time = models.TimeField()
    repeat_type = models.CharField(max_length=20, choices=REPEAT_CHOICES, default='daily')
    custom_days = models.JSONField(default=list)  # For custom repeat
    
    # Settings
    is_enabled = models.BooleanField(default=True)
    message = models.CharField(max_length=255, blank=True)
    
    # Tracking
    last_sent = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_reminders'
        ordering = ['reminder_time']

    def __str__(self):
        return f"Reminder for {self.habit.title} at {self.reminder_time}"
