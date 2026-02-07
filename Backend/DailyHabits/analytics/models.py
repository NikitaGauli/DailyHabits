"""
Analytics Models
Cached analytics summaries for performance
"""

from django.db import models
from django.conf import settings


class DailySummary(models.Model):
    """
    Daily analytics summary per user
    Cached data for dashboard performance
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_summaries'
    )
    date = models.DateField()
    
    # Habit counts
    total_habits = models.IntegerField(default=0)
    completed_count = models.IntegerField(default=0)
    skipped_count = models.IntegerField(default=0)
    missed_count = models.IntegerField(default=0)
    
    # Rates
    completion_rate = models.FloatField(default=0.0)
    consistency_rate = models.FloatField(default=0.0)
    
    # Streak info
    current_overall_streak = models.IntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_daily_summaries'
        unique_together = ('user', 'date')
        ordering = ['-date']
        indexes = [
            models.Index(fields=['user', 'date']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.date}"


class WeeklySummary(models.Model):
    """
    Weekly analytics summary
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='weekly_summaries'
    )
    week_start = models.DateField()  # Monday of the week
    week_end = models.DateField()  # Sunday of the week
    year = models.IntegerField()
    week_number = models.IntegerField()
    
    # Aggregated stats
    total_completions = models.IntegerField(default=0)
    total_habits_tracked = models.IntegerField(default=0)
    average_completion_rate = models.FloatField(default=0.0)
    best_day = models.CharField(max_length=20, blank=True)
    worst_day = models.CharField(max_length=20, blank=True)
    
    # Daily breakdown (JSON)
    daily_data = models.JSONField(default=dict)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_weekly_summaries'
        unique_together = ('user', 'year', 'week_number')
        ordering = ['-week_start']

    def __str__(self):
        return f"{self.user.email} - Week {self.week_number}/{self.year}"


class MonthlySummary(models.Model):
    """
    Monthly analytics summary
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='monthly_summaries'
    )
    year = models.IntegerField()
    month = models.IntegerField()
    
    # Aggregated stats
    total_completions = models.IntegerField(default=0)
    total_habits_tracked = models.IntegerField(default=0)
    average_completion_rate = models.FloatField(default=0.0)
    best_week = models.IntegerField(null=True, blank=True)
    
    # Heatmap data (JSON with daily completion info)
    heatmap_data = models.JSONField(default=list)
    
    # Category breakdown
    category_stats = models.JSONField(default=dict)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_monthly_summaries'
        unique_together = ('user', 'year', 'month')
        ordering = ['-year', '-month']

    def __str__(self):
        return f"{self.user.email} - {self.month}/{self.year}"


class HabitAnalytics(models.Model):
    """
    Per-habit analytics cache
    """
    habit = models.OneToOneField(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='analytics'
    )
    
    # Lifetime stats
    total_completions = models.IntegerField(default=0)
    total_days_tracked = models.IntegerField(default=0)
    lifetime_completion_rate = models.FloatField(default=0.0)
    
    # Recent stats
    last_7_days_rate = models.FloatField(default=0.0)
    last_30_days_rate = models.FloatField(default=0.0)
    
    # Trend
    trend_direction = models.CharField(
        max_length=20,
        choices=[
            ('improving', 'Improving'),
            ('stable', 'Stable'),
            ('declining', 'Declining'),
        ],
        default='stable'
    )
    trend_percentage = models.FloatField(default=0.0)
    
    # Best performance
    best_streak_ever = models.IntegerField(default=0)
    best_month = models.CharField(max_length=20, blank=True)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_habit_analytics'

    def __str__(self):
        return f"Analytics for {self.habit.title}"
