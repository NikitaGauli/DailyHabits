"""
Insights Models
Smart insights, motivational content, and personalized recommendations
"""

from django.db import models
from django.conf import settings


class MotivationalQuote(models.Model):
    """
    Collection of motivational quotes
    """
    CATEGORIES = [
        ('general', 'General'),
        ('streak', 'Streak Motivation'),
        ('comeback', 'Comeback Encouragement'),
        ('milestone', 'Milestone Celebration'),
        ('morning', 'Morning Motivation'),
        ('evening', 'Evening Reflection'),
    ]

    quote = models.TextField()
    author = models.CharField(max_length=255, blank=True)
    category = models.CharField(max_length=50, choices=CATEGORIES, default='general')
    
    # Usage tracking
    times_shown = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    
    # Localization
    language = models.CharField(max_length=10, default='en')
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'motivational_quotes'
        ordering = ['-times_shown']

    def __str__(self):
        return f'"{self.quote[:50]}..." - {self.author}'


class UserInsight(models.Model):
    """
    Personalized insights for users
    """
    INSIGHT_TYPES = [
        ('best_time', 'Best Performance Time'),
        ('consistent_habit', 'Most Consistent Habit'),
        ('declining_habit', 'Declining Habit Alert'),
        ('streak_milestone', 'Streak Milestone'),
        ('improvement', 'Improvement Opportunity'),
        ('celebration', 'Achievement Celebration'),
        ('recommendation', 'Recommendation'),
        ('weekly_summary', 'Weekly Summary'),
    ]
    
    PRIORITY_LEVELS = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='insights'
    )
    
    insight_type = models.CharField(max_length=50, choices=INSIGHT_TYPES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    
    # Related data
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='insights'
    )
    data = models.JSONField(default=dict)  # Additional context data
    
    # Display
    priority = models.CharField(max_length=20, choices=PRIORITY_LEVELS, default='medium')
    icon_code = models.IntegerField(default=0xE88E)
    color_value = models.BigIntegerField(default=0xFF3B82F6)
    
    # Status
    is_read = models.BooleanField(default=False)
    is_dismissed = models.BooleanField(default=False)
    is_actionable = models.BooleanField(default=True)
    action_taken = models.BooleanField(default=False)
    
    # Validity
    valid_from = models.DateTimeField(auto_now_add=True)
    valid_until = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'user_insights'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_read']),
            models.Index(fields=['user', 'insight_type']),
        ]

    def __str__(self):
        return f"{self.title} - {self.user.email}"


class InsightTemplate(models.Model):
    """
    Templates for generating insights
    """
    insight_type = models.CharField(max_length=50, unique=True)
    title_template = models.CharField(max_length=255)
    message_template = models.TextField()
    
    # Conditions for triggering
    trigger_conditions = models.JSONField(default=dict)
    
    # Visual defaults
    icon_code = models.IntegerField(default=0xE88E)
    color_value = models.BigIntegerField(default=0xFF3B82F6)
    
    is_active = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'insight_templates'

    def __str__(self):
        return f"Template: {self.insight_type}"


class UserPreferences(models.Model):
    """
    User preferences and settings
    """
    LANGUAGE_CHOICES = [
        ('en', 'English'),
        ('ne', 'Nepali'),
    ]
    
    THEME_CHOICES = [
        ('dark', 'Dark Mode'),
        ('light', 'Light Mode'),
        ('system', 'System Default'),
    ]
    
    DATE_FORMAT_CHOICES = [
        ('mdy', 'MM/DD/YYYY'),
        ('dmy', 'DD/MM/YYYY'),
        ('ymd', 'YYYY-MM-DD'),
    ]
    
    WEEK_START_CHOICES = [
        (0, 'Monday'),
        (6, 'Sunday'),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='preferences'
    )
    
    # Display
    theme = models.CharField(max_length=20, choices=THEME_CHOICES, default='dark')
    language = models.CharField(max_length=10, choices=LANGUAGE_CHOICES, default='en')
    date_format = models.CharField(max_length=10, choices=DATE_FORMAT_CHOICES, default='mdy')
    week_starts_on = models.IntegerField(choices=WEEK_START_CHOICES, default=0)
    
    # Habit defaults
    default_reminder_time = models.TimeField(null=True, blank=True)
    default_habit_color = models.BigIntegerField(default=0xFF6366F1)
    
    # Privacy
    show_in_leaderboard = models.BooleanField(default=True)
    profile_is_public = models.BooleanField(default=False)
    
    # Features
    smart_insights_enabled = models.BooleanField(default=True)
    motivational_quotes_enabled = models.BooleanField(default=True)
    gamification_enabled = models.BooleanField(default=True)
    
    # Data
    data_retention_days = models.IntegerField(default=365)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_preferences'

    def __str__(self):
        return f"Preferences - {self.user.email}"
