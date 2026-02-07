"""
Enhanced Habit Models for DailyHabits
Production-ready with streaks, logs, and comprehensive tracking
"""

from django.db import models
from django.conf import settings
from django.utils import timezone
from datetime import timedelta, date


class Category(models.Model):
    """
    Habit categories for organization
    """
    id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    icon_code = models.IntegerField(default=0xE87C)  # Default icon
    color_value = models.BigIntegerField(default=0xFF6366F1)  # Default color
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_categories'
        verbose_name_plural = 'Categories'
        ordering = ['name']

    def __str__(self):
        return self.name


class Habit(models.Model):
    """
    Core Habit Model with comprehensive tracking capabilities
    """
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('paused', 'Paused'),
        ('archived', 'Archived'),
    ]
    
    FREQUENCY_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('custom', 'Custom Days'),
    ]
    
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
    ]

    # Core fields
    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='habits'
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    
    # Categorization
    category = models.ForeignKey(
        Category, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='habits'
    )
    category_name = models.CharField(max_length=100, default='General')  # Fallback
    
    # Scheduling
    time = models.CharField(max_length=100, blank=True)  # Display time string
    frequency = models.CharField(
        max_length=50, 
        choices=FREQUENCY_CHOICES, 
        default='daily'
    )
    custom_days = models.JSONField(
        default=list, 
        blank=True,
        help_text='List of weekday numbers (0=Monday, 6=Sunday)'
    )
    target_count = models.IntegerField(default=1)  # How many times per day
    
    # Duration
    start_date = models.DateField(default=date.today)
    end_date = models.DateField(null=True, blank=True)
    
    # Visual
    icon_code = models.IntegerField(
        default=0xE87C,
        help_text='Flutter Icon codePoint'
    )
    color_value = models.BigIntegerField(
        default=0xFF6366F1,
        help_text='Flutter Color value (ARGB)'
    )
    
    # Status & Priority
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='medium')
    
    # Reminders
    reminder_enabled = models.BooleanField(default=False)
    reminder_time = models.TimeField(null=True, blank=True)
    
    # Pause management
    pause_reason = models.TextField(blank=True, help_text='Reason for pausing')
    paused_at = models.DateTimeField(null=True, blank=True)
    
    # Difficulty & ordering
    difficulty_score = models.IntegerField(
        default=3,
        help_text='1=Easy, 5=Very Hard — auto or user assigned'
    )
    sort_order = models.IntegerField(
        default=0,
        help_text='Manual sort position (lower = higher)'
    )
    
    # Soft delete
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habits'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', 'is_deleted']),
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['status', 'is_deleted']),
        ]

    def __str__(self):
        return f"{self.title} ({self.user.email})"

    def soft_delete(self):
        """Soft delete the habit"""
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.save()

    def restore(self):
        """Restore a soft-deleted habit"""
        self.is_deleted = False
        self.deleted_at = None
        self.save()

    def is_scheduled_today(self):
        """Check if this habit should be done today"""
        if self.frequency == 'daily':
            return True
        elif self.frequency == 'custom' and self.custom_days:
            today_weekday = timezone.now().weekday()
            return today_weekday in self.custom_days
        return True

    @property
    def current_streak(self):
        """Get current streak from related Streak model"""
        try:
            return self.streak.current_streak
        except Streak.DoesNotExist:
            return 0

    @property
    def best_streak(self):
        """Get best streak from related Streak model"""
        try:
            return self.streak.best_streak
        except Streak.DoesNotExist:
            return 0


class HabitLog(models.Model):
    """
    Daily habit tracking with status (completed/skipped/missed)
    More detailed than simple completion tracking
    """
    STATUS_CHOICES = [
        ('completed', 'Completed'),
        ('skipped', 'Skipped'),
        ('missed', 'Missed'),
        ('partial', 'Partial'),
    ]

    habit = models.ForeignKey(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='logs'
    )
    id = models.AutoField(primary_key=True)
    date = models.DateField()
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='completed'
    )
    count = models.IntegerField(default=1)  # How many times completed
    completed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)
    
    # Mood/Energy tracking (optional)
    mood_rating = models.IntegerField(null=True, blank=True)  # 1-5
    energy_level = models.IntegerField(null=True, blank=True)  # 1-5
    
    # Partial completion scoring (0.0 - 1.0)
    partial_score = models.FloatField(
        default=1.0,
        help_text='Completion score: 1.0=full, 0.5=half, etc.'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_logs'
        unique_together = ('habit', 'date')
        ordering = ['-date', '-completed_at']
        indexes = [
            models.Index(fields=['habit', 'date']),
            models.Index(fields=['date', 'status']),
            models.Index(fields=['habit', 'status']),
        ]

    def __str__(self):
        return f"{self.habit.title} - {self.date} ({self.status})"


class Streak(models.Model):
    """
    Track streaks for each habit
    Cached for performance, updated on habit completion
    """
    habit = models.OneToOneField(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='streak'
    )
    id = models.AutoField(primary_key=True)
    current_streak = models.IntegerField(default=0)
    best_streak = models.IntegerField(default=0)
    last_completed_date = models.DateField(null=True, blank=True)
    streak_start_date = models.DateField(null=True, blank=True)
    
    # Statistics
    total_completions = models.IntegerField(default=0)
    total_skips = models.IntegerField(default=0)
    total_misses = models.IntegerField(default=0)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_streaks'

    def __str__(self):
        return f"{self.habit.title} - {self.current_streak} days"

    def update_streak(self, completed_date):
        """Update streak based on completion"""
        today = timezone.now().date()
        
        if self.last_completed_date:
            days_diff = (completed_date - self.last_completed_date).days
            
            if days_diff == 1:
                # Consecutive day - extend streak
                self.current_streak += 1
            elif days_diff == 0:
                # Same day - no change
                pass
            else:
                # Streak broken - reset
                self.current_streak = 1
                self.streak_start_date = completed_date
        else:
            # First completion
            self.current_streak = 1
            self.streak_start_date = completed_date
        
        # Update best streak if current is higher
        if self.current_streak > self.best_streak:
            self.best_streak = self.current_streak
        
        self.last_completed_date = completed_date
        self.total_completions += 1
        self.save()

    def check_and_reset_streak(self):
        """Check if streak should be reset (missed day)"""
        if not self.last_completed_date:
            return
        
        today = timezone.now().date()
        days_since_completion = (today - self.last_completed_date).days
        
        if days_since_completion > 1:
            # Streak broken
            self.current_streak = 0
            self.total_misses += (days_since_completion - 1)
            self.save()


# Keep the old HabitCompletion model for backwards compatibility
class HabitCompletion(models.Model):
    """
    Legacy completion tracking (for backwards compatibility)
    New code should use HabitLog
    """
    habit = models.ForeignKey(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='completions'
    )
    date = models.DateField()
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_completions'
        unique_together = ('habit', 'date')

    def __str__(self):
        return f"{self.habit.title} completed on {self.date}"
