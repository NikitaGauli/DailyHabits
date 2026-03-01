"""
Habits Models — Core Domain Models for the DailyHabits Application
=================================================================

This module defines the database models that form the backbone of the habit-tracking
system. It contains five models arranged in a relational hierarchy:

    Category  →  Habit  →  HabitLog
                        →  Streak
                        →  HabitCompletion (legacy)

Key design decisions:
    - **Soft-delete pattern**: Habits are never hard-deleted; they receive an
      ``is_deleted`` flag so historical analytics remain intact.
    - **Streak caching**: Streaks are stored in a dedicated one-to-one table
      rather than computed on-the-fly, giving O(1) reads at the cost of
      incremental writes on each completion event.
    - **Flexible scheduling**: Habits support daily, weekly, and custom-day
      frequencies via a JSON field of weekday indices.
    - **Flutter-friendly fields**: ``icon_code`` and ``color_value`` store
      Flutter-native codePoint / ARGB integers so the frontend can render
      icons and colors without any mapping layer.

Authors:
    DailyHabits Engineering Team

Since:
    v1.0.0
"""

# === Standard Library Imports ================================================
from datetime import timedelta, date

# === Django Imports ==========================================================
from django.db import models
from django.conf import settings
from django.utils import timezone


# =============================================================================
# Category Model
# =============================================================================

class Category(models.Model):
    """
    Organisational grouping for habits (e.g. Health, Fitness, Learning).

    Categories allow users to tag and filter their habits.  A set of
    system-provided *default* categories is seeded on first deployment;
    users may also create custom ones.

    Attributes:
        id (int):               Auto-incrementing primary key.
        name (str):             Unique human-readable label (max 100 chars).
        description (str):      Optional longer explanation of the category.
        icon_code (int):        Flutter ``IconData.codePoint`` value for display.
        color_value (int):      Flutter ARGB colour integer for theming.
        is_default (bool):      ``True`` for system-seeded categories.
        created_at (datetime):  Timestamp of creation (set automatically).
    """

    id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    icon_code = models.IntegerField(default=0xE87C)        # Material Icons default
    color_value = models.BigIntegerField(default=0xFF6366F1)  # Indigo accent
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_categories'
        verbose_name_plural = 'Categories'
        ordering = ['name']  # Alphabetical listing

    def __str__(self) -> str:
        """Return the category name as its string representation."""
        return self.name


# =============================================================================
# Habit Model — Primary Entity
# =============================================================================

class Habit(models.Model):
    """
    Central entity representing a single trackable habit.

    A Habit belongs to one user and supports rich scheduling, visual
    customisation, priority levels, reminders, and soft-deletion.
    Completion data is recorded via :class:`HabitLog` entries, while
    cumulative streak statistics are cached in the related :class:`Streak`.

    Lifecycle states (``status``):
        * **active**   — habit is being tracked daily.
        * **paused**   — temporarily suspended (streak frozen).
        * **archived** — permanently hidden but data retained.

    Frequency modes (``frequency``):
        * **daily**  — every day.
        * **weekly** — once per week (any day).
        * **custom** — specific weekdays stored in ``custom_days``.
    """

    # --- Choice Constants ----------------------------------------------------

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

    VISIBILITY_CHOICES = [
        ('private', 'Private'),            # Only visible to the owner
        ('friends_only', 'Friends Only'),  # Visible to confirmed friends
        ('public', 'Public'),              # Visible to all users
    ]

    # --- Core Identity Fields -------------------------------------------------

    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='habits',
        help_text='Owner of this habit.',
    )
    title = models.CharField(max_length=255)          # Short user-facing label
    description = models.TextField(blank=True, null=True)  # Optional details
    
    # --- Categorisation Fields -----------------------------------------------

    category = models.ForeignKey(
        Category, 
        on_delete=models.SET_NULL,  # Keep habit even if category is deleted
        null=True, 
        blank=True,
        related_name='habits',
    )
    category_name = models.CharField(
        max_length=100, default='General',
        help_text='Denormalised category label used as fallback when FK is null.',
    )
    
    # --- Scheduling Fields ---------------------------------------------------

    time = models.CharField(max_length=100, blank=True)  # Human-readable time string
    frequency = models.CharField(
        max_length=50, 
        choices=FREQUENCY_CHOICES, 
        default='daily',
    )
    custom_days = models.JSONField(
        default=list, 
        blank=True,
        help_text='List of weekday numbers (0=Monday, 6=Sunday)',
    )
    target_count = models.IntegerField(
        default=1,
        help_text='Number of times the habit should be done per scheduled day.',
    )
    
    # --- Duration Fields -----------------------------------------------------

    start_date = models.DateField(default=date.today)     # When tracking begins
    end_date = models.DateField(null=True, blank=True)    # Optional end boundary
    
    # --- Visual / UI Fields --------------------------------------------------

    icon_code = models.IntegerField(
        default=0xE87C,
        help_text='Flutter Icon codePoint (Material Icons)',
    )
    color_value = models.BigIntegerField(
        default=0xFF6366F1,
        help_text='Flutter Color value stored as ARGB integer',
    )
    
    # --- Status & Priority Fields --------------------------------------------

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='medium')
    
    # --- Sharing & Visibility Fields ------------------------------------------

    visibility = models.CharField(
        max_length=20,
        choices=VISIBILITY_CHOICES,
        default='private',
        help_text='Controls who can see this habit: private, friends_only, or public.',
    )
    
    # --- Reminder Fields -----------------------------------------------------

    reminder_enabled = models.BooleanField(default=False)
    reminder_time = models.TimeField(null=True, blank=True)
    
    # --- Pause Management Fields ---------------------------------------------

    pause_reason = models.TextField(blank=True, help_text='User-supplied reason for pausing')
    paused_at = models.DateTimeField(null=True, blank=True)
    
    # --- Difficulty & Manual Ordering ----------------------------------------

    difficulty_score = models.IntegerField(
        default=3,
        help_text='Subjective difficulty: 1 = Easy … 5 = Very Hard',
    )
    sort_order = models.IntegerField(
        default=0,
        help_text='Manual sort position — lower values appear first',
    )
    
    # --- Soft-Delete Fields --------------------------------------------------

    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    
    # --- Audit Timestamps ----------------------------------------------------

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # --- Meta Configuration ---------------------------------------------------

    class Meta:
        db_table = 'habits'
        ordering = ['-created_at']  # Newest habits first by default
        indexes = [
            # Composite indexes for common query patterns
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', 'is_deleted']),
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['status', 'is_deleted']),
            # Feed queries filter by visibility + active status
            models.Index(fields=['visibility', 'is_deleted']),
        ]

    # --- String Representation -----------------------------------------------

    def __str__(self) -> str:
        """Return a descriptive label: ``<title> (<user email>)``."""
        return f"{self.title} ({self.user.email})"

    # --- Soft-Delete Helpers -------------------------------------------------

    def soft_delete(self) -> None:
        """
        Mark the habit as deleted without removing it from the database.

        Sets ``is_deleted = True`` and records the deletion timestamp so
        that analytics and historical data remain queryable.
        """
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.save()

    def restore(self) -> None:
        """
        Restore a previously soft-deleted habit.

        Clears the ``is_deleted`` flag and the ``deleted_at`` timestamp,
        making the habit visible to the user again.
        """
        self.is_deleted = False
        self.deleted_at = None
        self.save()

    # --- Scheduling Helpers --------------------------------------------------

    def is_scheduled_today(self) -> bool:
        """
        Determine whether this habit is scheduled for *today*.

        Returns:
            bool: ``True`` if the habit should appear on today's list
                  (daily habits always return ``True``; custom-day habits
                  check the current weekday against ``custom_days``).
        """
        if self.frequency == 'daily':
            return True
        elif self.frequency == 'custom' and self.custom_days:
            today_weekday = timezone.now().weekday()  # 0 = Monday
            return today_weekday in self.custom_days
        return True  # Weekly & unrecognised frequencies default to True

    # --- Streak Convenience Properties ---------------------------------------

    @property
    def current_streak(self) -> int:
        """
        Shortcut to the related :class:`Streak` model's ``current_streak``.

        Returns:
            int: Current consecutive-day streak, or ``0`` if no streak exists.
        """
        try:
            return self.streak.current_streak  # type: ignore
        except Streak.DoesNotExist:
            return 0

    @property
    def best_streak(self) -> int:
        """
        Shortcut to the related :class:`Streak` model's ``best_streak``.

        Returns:
            int: All-time best streak, or ``0`` if no streak exists.
        """
        try:
            return self.streak.best_streak  # type: ignore
        except Streak.DoesNotExist:
            return 0


# =============================================================================
# HabitLog Model — Daily Completion Records
# =============================================================================

class HabitLog(models.Model):
    """
    Individual daily record for a habit's completion state.

    Each row represents *one day* for *one habit*.  The ``status`` field
    distinguishes between completed, skipped, missed, and partial states,
    enabling nuanced analytics far beyond a simple boolean toggle.

    A unique-together constraint on ``(habit, date)`` guarantees at most
    one log per habit per day.

    Attributes:
        habit (FK → Habit):     The habit this log entry belongs to.
        date (date):            Calendar date of the entry.
        status (str):           One of ``completed``, ``skipped``, ``missed``, ``partial``.
        count (int):            Repetition count (supports multi-count habits).
        completed_at (datetime): Exact timestamp of completion (nullable).
        notes (str):            Optional free-text reflection.
        mood_rating (int|None): User self-reported mood (1–5 scale).
        energy_level (int|None): User self-reported energy (1–5 scale).
        partial_score (float):  Fractional completion score (0.0–1.0).
    """

    STATUS_CHOICES = [
        ('completed', 'Completed'),
        ('skipped', 'Skipped'),
        ('missed', 'Missed'),
        ('partial', 'Partial'),
    ]

    # --- Relationships -------------------------------------------------------

    habit = models.ForeignKey(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='logs',
    )

    # --- Core Fields ---------------------------------------------------------

    id = models.AutoField(primary_key=True)
    date = models.DateField()                          # Calendar date
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='completed',
    )
    count = models.IntegerField(default=1)             # Times completed today
    completed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)               # User reflection
    
    # --- Optional Wellness Metrics -------------------------------------------

    mood_rating = models.IntegerField(null=True, blank=True)    # 1 (low) – 5 (high)
    energy_level = models.IntegerField(null=True, blank=True)   # 1 (low) – 5 (high)
    
    # --- Partial Completion ---------------------------------------------------

    partial_score = models.FloatField(
        default=1.0,
        help_text='Completion score: 1.0=full, 0.5=half, etc.',
    )
    
    # --- Audit Timestamps ----------------------------------------------------

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_logs'
        unique_together = ('habit', 'date')  # One log per habit per day
        ordering = ['-date', '-completed_at']
        indexes = [
            models.Index(fields=['habit', 'date']),    # Fast lookup by habit + date
            models.Index(fields=['date', 'status']),   # Daily dashboard queries
            models.Index(fields=['habit', 'status']),  # Habit-level analytics
        ]

    def __str__(self) -> str:
        """Return a descriptive label: ``<habit title> - <date> (<status>)``."""
        return f"{self.habit.title} - {self.date} ({self.status})"


# =============================================================================
# Streak Model — Cached Streak Statistics
# =============================================================================

class Streak(models.Model):
    """
    Denormalised streak cache for a single habit.

    Instead of computing streaks from raw :class:`HabitLog` rows on every
    request, this one-to-one companion model maintains running totals that
    are updated incrementally whenever a completion event occurs.

    Attributes:
        habit (OneToOne → Habit):   The parent habit.
        current_streak (int):       Consecutive days completed as of now.
        best_streak (int):          All-time longest streak.
        last_completed_date (date): Date of the most recent completion.
        streak_start_date (date):   Date the current streak began.
        total_completions (int):    Lifetime completed-day count.
        total_skips (int):          Lifetime skipped-day count.
        total_misses (int):         Lifetime missed-day count.
    """

    # --- Relationships -------------------------------------------------------

    habit = models.OneToOneField(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='streak',
    )

    # --- Core Streak Fields --------------------------------------------------

    id = models.AutoField(primary_key=True)
    current_streak = models.IntegerField(default=0)
    best_streak = models.IntegerField(default=0)
    last_completed_date = models.DateField(null=True, blank=True)
    streak_start_date = models.DateField(null=True, blank=True)
    
    # --- Aggregate Statistics ------------------------------------------------

    total_completions = models.IntegerField(default=0)
    total_skips = models.IntegerField(default=0)
    total_misses = models.IntegerField(default=0)
    
    # --- Audit Timestamp -----------------------------------------------------

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'habit_streaks'

    def __str__(self) -> str:
        """Return ``<habit title> - <N> days``."""
        return f"{self.habit.title} - {self.current_streak} days"

    # --- Streak Mutation Methods ----------------------------------------------

    def update_streak(self, completed_date) -> None:
        """
        Recalculate the streak after the user marks a habit as completed.

        Logic:
            * If ``completed_date`` is exactly one day after the last
              completion → extend the current streak.
            * If it's the *same* day → no-op (idempotent).
            * Otherwise (gap > 1 day) → streak resets to 1.

        Args:
            completed_date (date): The calendar date on which the habit
                                   was completed.
        """
        today = timezone.now().date()
        
        if self.last_completed_date:
            days_diff = (completed_date - self.last_completed_date).days
            
            if days_diff == 1:
                # Consecutive day — extend streak
                self.current_streak += 1
            elif days_diff == 0:
                # Same day — idempotent, no change
                pass
            else:
                # Gap detected — streak broken, start fresh
                self.current_streak = 1
                self.streak_start_date = completed_date
        else:
            # Very first completion ever recorded
            self.current_streak = 1
            self.streak_start_date = completed_date
        
        # Promote to best streak if we've beaten the previous record
        if self.current_streak > self.best_streak:
            self.best_streak = self.current_streak
        
        self.last_completed_date = completed_date
        self.total_completions += 1
        self.save()

    def check_and_reset_streak(self) -> None:
        """
        Detect a broken streak and reset accordingly.

        This should be called by a daily scheduled task (e.g. Celery beat)
        to catch habits where the user missed a day without interacting
        with the app.  Any gap > 1 day is treated as a broken streak.
        """
        if not self.last_completed_date:
            return
        
        today = timezone.now().date()
        days_since_completion = (today - self.last_completed_date).days
        
        if days_since_completion > 1:
            # Streak broken — reset and tally missed days
            self.current_streak = 0
            self.total_misses += (days_since_completion - 1)
            self.save()


# =============================================================================
# HabitCompletion Model — LEGACY (Backwards-Compatible)
# =============================================================================

# NOTE: This model is retained solely for backwards compatibility with older
# mobile app versions and data-migration scripts.  All *new* code should
# record completions via HabitLog instead.

class HabitCompletion(models.Model):
    """
    **Deprecated** — Simple boolean completion record.

    Superseded by :class:`HabitLog`, which additionally tracks status,
    partial scores, mood, and energy.  This model is kept so that
    existing rows and any legacy API consumers continue to work.

    .. deprecated:: 2.0
        Use :class:`HabitLog` for all new completion tracking.
    """

    habit = models.ForeignKey(
        Habit, 
        on_delete=models.CASCADE, 
        related_name='completions',
    )
    date = models.DateField()
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_completions'
        unique_together = ('habit', 'date')  # One completion per habit per day

    def __str__(self) -> str:
        """Return ``<habit title> completed on <date>``."""
        return f"{self.habit.title} completed on {self.date}"
