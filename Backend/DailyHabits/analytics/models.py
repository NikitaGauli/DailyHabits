"""
Analytics Models — analytics/models.py

Defines the data models for the Analytics app. These models store pre-computed,
cached analytics summaries at daily, weekly, and monthly granularity, as well as
per-habit lifetime analytics. Caching aggregated data avoids expensive real-time
queries on the HabitLog table and ensures snappy dashboard performance.

Models:
    - DailySummary:   One row per user per day with completion counts and rates.
    - WeeklySummary:  Aggregated weekly stats with daily JSON breakdown.
    - MonthlySummary: Monthly roll-ups including heatmap and category data.
    - HabitAnalytics: Per-habit lifetime statistics and trend indicators.
"""

from django.db import models
from django.conf import settings


# =============================================================================
# Daily Summary Model
# =============================================================================

class DailySummary(models.Model):
    """
    Stores a single day's analytics snapshot for one user.

    A new row is created (or updated) at the end of each day by the analytics
    service.  The cached counts and rates power the dashboard "today" card and
    the daily trend chart without re-aggregating raw HabitLog rows.

    Attributes:
        user:                   Foreign key to the owning user.
        date:                   The calendar date this summary represents.
        total_habits:           Number of active habits on that date.
        completed_count:        Habits marked 'completed'.
        skipped_count:          Habits marked 'skipped'.
        missed_count:           Habits that were neither completed nor skipped.
        completion_rate:        completed_count / total_habits as a percentage.
        consistency_rate:       Rolling consistency metric for the user.
        current_overall_streak: Longest active streak across all habits.
    """
    # ── Relationships ──────────────────────────────────────────────────
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_summaries'
    )
    date = models.DateField()  # Calendar date (unique per user)

    # ── Habit Counts ──────────────────────────────────────────────────
    total_habits = models.IntegerField(default=0)       # Active habits that day
    completed_count = models.IntegerField(default=0)    # Marked as completed
    skipped_count = models.IntegerField(default=0)      # Intentionally skipped
    missed_count = models.IntegerField(default=0)       # Not acted upon

    # ── Computed Rates (0.0 – 100.0) ─────────────────────────────────
    completion_rate = models.FloatField(default=0.0)    # % completed out of total
    consistency_rate = models.FloatField(default=0.0)   # Rolling consistency metric

    # ── Streak Information ────────────────────────────────────────────
    current_overall_streak = models.IntegerField(default=0)  # Best active streak

    # ── Timestamps ────────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)  # Row creation time
    updated_at = models.DateTimeField(auto_now=True)      # Last recalculation time

    class Meta:
        db_table = 'analytics_daily_summaries'
        unique_together = ('user', 'date')   # One summary per user per day
        ordering = ['-date']                  # Most recent first
        indexes = [
            models.Index(fields=['user', 'date']),  # Optimise user+date lookups
        ]

    def __str__(self):
        """Human-readable label: 'user@example.com - 2026-02-08'."""
        return f"{self.user.email} - {self.date}"


# =============================================================================
# Weekly Summary Model
# =============================================================================

class WeeklySummary(models.Model):
    """
    Aggregated analytics for a single ISO calendar week.

    These summaries drive the "weekly progress" bar chart on the frontend.
    The ``daily_data`` JSON field stores a per-day breakdown so the chart
    can render without additional queries.

    Attributes:
        user:                    Foreign key to the owning user.
        week_start / week_end:   Monday–Sunday date range for the week.
        year / week_number:      ISO year and week number (unique per user).
        total_completions:       Sum of all completed habit logs in the week.
        total_habits_tracked:    Number of unique habits tracked.
        average_completion_rate: Mean daily completion rate across the week.
        best_day / worst_day:    Day names with highest/lowest completion.
        daily_data:              JSON breakdown keyed by day of week.
    """
    # ── Relationships ──────────────────────────────────────────────────
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='weekly_summaries'
    )

    # ── Date Range ────────────────────────────────────────────────────
    week_start = models.DateField()    # Monday of the ISO week
    week_end = models.DateField()      # Sunday of the ISO week
    year = models.IntegerField()       # ISO year
    week_number = models.IntegerField()  # ISO week number (1–53)

    # ── Aggregated Statistics ─────────────────────────────────────────
    total_completions = models.IntegerField(default=0)       # Sum of completed logs
    total_habits_tracked = models.IntegerField(default=0)    # Unique habits
    average_completion_rate = models.FloatField(default=0.0)  # Mean daily rate (%)
    best_day = models.CharField(max_length=20, blank=True)   # e.g. "Monday"
    worst_day = models.CharField(max_length=20, blank=True)  # e.g. "Friday"

    # ── Daily Breakdown (JSON) ────────────────────────────────────────
    # Structure: { "Mon": { "completed": 5, "total": 6, "rate": 83.3 }, … }
    daily_data = models.JSONField(default=dict)

    # ── Timestamps ────────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_weekly_summaries'
        unique_together = ('user', 'year', 'week_number')  # One row per user per week
        ordering = ['-week_start']  # Most recent week first

    def __str__(self):
        """Human-readable label: 'user@example.com - Week 6/2026'."""
        return f"{self.user.email} - Week {self.week_number}/{self.year}"


# =============================================================================
# Monthly Summary Model
# =============================================================================

class MonthlySummary(models.Model):
    """
    Monthly roll-up of user analytics.

    Contains high-level aggregation plus two JSON fields that store a calendar
    heatmap and a category-level breakdown, allowing the frontend to render
    the monthly report view from a single API call.

    Attributes:
        user:                    Foreign key to the owning user.
        year / month:            Calendar year and month (unique per user).
        total_completions:       Completed habit log count for the month.
        total_habits_tracked:    Number of unique habits tracked.
        average_completion_rate: Mean daily completion rate.
        best_week:               ISO week number with the highest rate.
        heatmap_data:            JSON list of daily intensity values.
        category_stats:          JSON dict with per-category breakdowns.
    """
    # ── Relationships ──────────────────────────────────────────────────
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='monthly_summaries'
    )

    # ── Time Period ───────────────────────────────────────────────────
    year = models.IntegerField()   # Calendar year (e.g. 2026)
    month = models.IntegerField()  # Calendar month (1–12)

    # ── Aggregated Statistics ─────────────────────────────────────────
    total_completions = models.IntegerField(default=0)       # Total completed logs
    total_habits_tracked = models.IntegerField(default=0)    # Unique habits
    average_completion_rate = models.FloatField(default=0.0)  # Mean daily rate (%)
    best_week = models.IntegerField(null=True, blank=True)   # ISO week with peak %

    # ── Heatmap Data (JSON list) ──────────────────────────────────────
    # Each entry: { "date": "2026-02-01", "intensity": 0.85, "completed": 5 }
    heatmap_data = models.JSONField(default=list)

    # ── Category Breakdown (JSON dict) ───────────────────────────────
    # Structure: { "Health": { "count": 3, "rate": 75.0 }, … }
    category_stats = models.JSONField(default=dict)

    # ── Timestamps ────────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_monthly_summaries'
        unique_together = ('user', 'year', 'month')  # One row per user per month
        ordering = ['-year', '-month']  # Newest month first

    def __str__(self):
        """Human-readable label: 'user@example.com - 2/2026'."""
        return f"{self.user.email} - {self.month}/{self.year}"


# =============================================================================
# Per-Habit Analytics Model
# =============================================================================

class HabitAnalytics(models.Model):
    """
    Cached lifetime analytics for a single habit.

    A one-to-one extension of ``habits.Habit`` that stores pre-computed metrics.
    The analytics service recalculates these values periodically so that the
    "habit detail" screen can render instantly.

    Attributes:
        habit:                   One-to-one link to the parent Habit.
        total_completions:       Lifetime count of completed logs.
        total_days_tracked:      Total calendar days since the habit was created.
        lifetime_completion_rate: Completions / days tracked as a percentage.
        last_7_days_rate:        Completion rate for the last 7 days.
        last_30_days_rate:       Completion rate for the last 30 days.
        trend_direction:         'improving', 'stable', or 'declining'.
        trend_percentage:        Magnitude of the trend change (%).
        best_streak_ever:        Longest consecutive-day streak achieved.
        best_month:              Calendar month label with the peak rate.
    """
    # ── Relationship ──────────────────────────────────────────────────
    habit = models.OneToOneField(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='analytics'  # Access via habit.analytics
    )

    # ── Lifetime Statistics ───────────────────────────────────────────
    total_completions = models.IntegerField(default=0)           # All-time completions
    total_days_tracked = models.IntegerField(default=0)          # Calendar days since creation
    lifetime_completion_rate = models.FloatField(default=0.0)    # Completions / days (%)

    # ── Recent Performance ────────────────────────────────────────────
    last_7_days_rate = models.FloatField(default=0.0)   # Short-term completion rate
    last_30_days_rate = models.FloatField(default=0.0)  # Medium-term completion rate

    # ── Trend Indicators ──────────────────────────────────────────────
    trend_direction = models.CharField(
        max_length=20,
        choices=[
            ('improving', 'Improving'),
            ('stable', 'Stable'),
            ('declining', 'Declining'),
        ],
        default='stable'
    )
    trend_percentage = models.FloatField(default=0.0)  # Magnitude of change (%)

    # ── Best Performance Records ──────────────────────────────────────
    best_streak_ever = models.IntegerField(default=0)           # Peak consecutive days
    best_month = models.CharField(max_length=20, blank=True)    # e.g. "Jan 2026"

    # ── Timestamp ─────────────────────────────────────────────────────
    updated_at = models.DateTimeField(auto_now=True)  # Last recalculation time

    class Meta:
        db_table = 'analytics_habit_analytics'  # Explicit table name

    def __str__(self):
        """Human-readable label: 'Analytics for <habit title>'."""
        return f"Analytics for {self.habit.title}"
