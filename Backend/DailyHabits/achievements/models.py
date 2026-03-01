"""
Achievements Models
====================
Data models for the gamification and achievements system.

This module defines the complete data layer for the achievements subsystem,
which powers badges, levels, XP progression, and unlockable rewards.
The gamification engine encourages consistent habit tracking by awarding
achievements based on streaks, completion counts, consistency rates,
milestones, and special in-app events.

Models:
    - Achievement:       Canonical definitions for all earnable badges/achievements.
    - UserAchievement:   Join table recording which users have earned which achievements.
    - UserLevel:         Per-user XP and level progression state.
    - Reward:            Definitions for unlockable rewards (themes, icons, features).
    - UserReward:        Join table recording which rewards a user has unlocked.
"""

from django.db import models
from django.conf import settings


# =============================================================================
# Achievement Definition Model
# =============================================================================

class Achievement(models.Model):
    """
    Canonical achievement / badge definition.

    Each row represents a single earnable achievement in the gamification
    system.  Achievements are categorised by type (streak, completion,
    consistency, milestone, or special) and by rarity tier.  The front-end
    uses ``icon_code`` and ``color_value`` to render the badge visually.

    Attributes:
        name:             Human-readable achievement title.
        description:      Explanatory text shown to the user.
        achievement_type: Category that determines how the badge is evaluated.
        target_value:     Numeric threshold the user must reach to earn it.
        rarity:           Rarity tier affecting XP weight and visual styling.
        points:           XP points awarded on earning the achievement.
        is_hidden:        If True, achievement is hidden until earned (secret badge).
    """
    # -- Achievement type choices ------------------------------------------------
    # Determines the evaluation strategy used by AchievementService.
    ACHIEVEMENT_TYPES = [
        ('streak', 'Streak Based'),           # Consecutive-day streaks
        ('completion', 'Completion Count'),    # Total completed habit-logs
        ('consistency', 'Consistency Rate'),   # Percentage-based consistency
        ('milestone', 'Milestone'),            # One-time milestone events
        ('special', 'Special Achievement'),    # Time-of-day / contextual badges
    ]

    # -- Rarity tiers -----------------------------------------------------------
    # Higher rarity badges are harder to earn and grant more XP points.
    RARITY_CHOICES = [
        ('common', 'Common'),
        ('uncommon', 'Uncommon'),
        ('rare', 'Rare'),
        ('epic', 'Epic'),
        ('legendary', 'Legendary'),
    ]

    # -- Core identity fields ---------------------------------------------------
    name = models.CharField(max_length=255)
    description = models.TextField()
    achievement_type = models.CharField(max_length=50, choices=ACHIEVEMENT_TYPES)

    # -- Requirement thresholds -------------------------------------------------
    target_value = models.IntegerField()  # Numeric goal the user must reach
    target_type = models.CharField(max_length=50, default='count')  # count | percentage | days

    # -- Visual / UI representation ---------------------------------------------
    icon_code = models.IntegerField(default=0xE87B)              # Material icon codepoint
    color_value = models.BigIntegerField(default=0xFFFFD700)     # ARGB colour (gold default)
    badge_image_url = models.URLField(blank=True, null=True)     # Optional custom badge image

    # -- Gamification metadata --------------------------------------------------
    rarity = models.CharField(max_length=20, choices=RARITY_CHOICES, default='common')
    points = models.IntegerField(default=10)         # XP awarded on earning
    level_required = models.IntegerField(default=1)  # Minimum user level to display

    # -- Ordering & visibility --------------------------------------------------
    order = models.IntegerField(default=0)              # Manual sort order in lists
    is_active = models.BooleanField(default=True)       # Soft-disable without deletion
    is_hidden = models.BooleanField(default=False)      # Secret achievements (revealed on earn)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'achievements'
        ordering = ['order', 'level_required', 'points']

    def __str__(self):
        """Return a human-readable label: 'Achievement Name (rarity)'."""
        return f"{self.name} ({self.rarity})"


# =============================================================================
# User ↔ Achievement Join Model
# =============================================================================

class UserAchievement(models.Model):
    """
    Records an individual user earning a specific achievement.

    This is the many-to-many through table between users and achievements.
    For *streak*-type achievements the same badge can be earned once per
    habit (tracked via the optional ``habit`` FK), while all other types
    are earned at most once per user.

    Attributes:
        user:          The user who earned the achievement.
        achievement:   The achievement that was earned.
        habit:         (Optional) The habit that triggered a streak achievement.
        earned_value:  The metric value at the moment the achievement was awarded.
        is_notified:   Whether the user has been notified about this achievement.
        is_claimed:    Whether the user has claimed any associated reward.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='achievements'
    )
    achievement = models.ForeignKey(
        Achievement,
        on_delete=models.CASCADE,
        related_name='user_achievements'
    )
    
    # Optional: which habit triggered this
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='achievements'
    )
    
    # -- Context & state -------------------------------------------------------
    earned_at = models.DateTimeField(auto_now_add=True)        # Timestamp of award
    earned_value = models.IntegerField(default=0)              # Metric snapshot when earned
    is_notified = models.BooleanField(default=False)           # Push notification sent flag
    is_claimed = models.BooleanField(default=False)            # Reward-claim acknowledgement

    class Meta:
        db_table = 'user_achievements'
        unique_together = ('user', 'achievement', 'habit')
        ordering = ['-earned_at']

    def __str__(self):
        """Return '{email} earned {achievement}'."""
        return f"{self.user.email} earned {self.achievement.name}"


# =============================================================================
# User Level / XP Progression Model
# =============================================================================

class UserLevel(models.Model):
    """
    Tracks a user's XP and level progression.

    Each user has exactly one ``UserLevel`` row (OneToOneField).  XP is
    accumulated from earning achievements and the ``add_xp`` method
    automatically handles level-up transitions using an exponential XP
    curve.  The maximum level is 10 ("Habit Champion").

    XP formula per level:  ``level * 100  +  level² * 50``

    Attributes:
        current_level:           The user's current level (1–10).
        current_xp:              XP accumulated toward the *next* level.
        total_xp:                Lifetime cumulative XP.
        total_achievements:      Cached count of all earned achievements.
        achievements_this_month: Rolling monthly achievement count.
    """
    # -- Human-readable level titles (1 → 10) --------------------------------
    LEVEL_NAMES = [
        (1, 'Beginner'),
        (2, 'Novice'),
        (3, 'Apprentice'),
        (4, 'Intermediate'),
        (5, 'Advanced'),
        (6, 'Expert'),
        (7, 'Master'),
        (8, 'Grandmaster'),
        (9, 'Legend'),
        (10, 'Habit Champion'),   # Maximum level
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='level'
    )
    
    # -- Progression state ------------------------------------------------------
    current_level = models.IntegerField(default=1)       # Current level (1–10)
    current_xp = models.IntegerField(default=0)          # XP toward next level
    total_xp = models.IntegerField(default=0)            # Lifetime cumulative XP

    # -- Cached statistics ------------------------------------------------------
    total_achievements = models.IntegerField(default=0)          # All-time earned count
    achievements_this_month = models.IntegerField(default=0)     # Rolling monthly count

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_levels'

    def __str__(self):
        """Return '{email} – Level N (Title)'."""
        level_name = dict(self.LEVEL_NAMES).get(self.current_level, 'Unknown')
        return f"{self.user.email} - Level {self.current_level} ({level_name})"

    # -- Computed properties ---------------------------------------------------

    @property
    def level_name(self):
        """Return the human-readable title for the current level."""
        return dict(self.LEVEL_NAMES).get(self.current_level, 'Unknown')

    @property
    def xp_for_next_level(self):
        """Calculate XP required to reach the next level.

        Uses an exponential growth curve:
            ``required = level * 100 + level² * 50``

        Returns:
            int: XP points required to advance from the current level.
        """
        return self.current_level * 100 + (self.current_level ** 2) * 50

    @property
    def xp_progress_percentage(self):
        """Return progress toward the next level as a percentage (0–100).

        Returns:
            float: Percentage of XP accumulated toward the next level.
        """
        required = self.xp_for_next_level
        return min(100, (self.current_xp / required) * 100) if required > 0 else 100

    # -- Mutating helpers ------------------------------------------------------

    def add_xp(self, amount):
        """Add XP and automatically process any resulting level-ups.

        The method loops to handle cases where a single XP grant spans
        multiple levels.  Level is capped at 10 (Habit Champion).

        Args:
            amount (int): Number of XP points to add.

        Returns:
            bool: True if the user leveled up at least once.
        """
        self.current_xp += amount
        self.total_xp += amount

        leveled_up = False
        # Loop handles multi-level jumps from a single large XP grant
        while self.current_xp >= self.xp_for_next_level and self.current_level < 10:
            self.current_xp -= self.xp_for_next_level
            self.current_level += 1
            leveled_up = True

        self.save()
        return leveled_up


# =============================================================================
# Reward Definition Model
# =============================================================================

class Reward(models.Model):
    """
    Definition of an unlockable reward.

    Rewards are incentives such as theme packs, icon packs, special badges,
    or feature unlocks that become available when a user reaches a required
    level, accumulates enough points, or earns a specific ``Achievement``.

    The ``reward_data`` JSONField stores type-specific payload (e.g. theme
    colour palette, icon codepoints) consumed by the front-end client.

    Attributes:
        name:                 Display name of the reward.
        description:          User-facing description text.
        reward_type:          Category of the reward (theme, icon, badge, feature).
        level_required:       Minimum user level to unlock.
        points_required:      Minimum cumulative points to unlock.
        achievement_required: Optional prerequisite achievement.
        reward_data:          Arbitrary JSON payload for the front-end.
    """
    # -- Reward type choices ----------------------------------------------------
    REWARD_TYPES = [
        ('theme', 'Theme Unlock'),      # Custom colour themes
        ('icon', 'Icon Pack'),           # Additional icon sets
        ('badge', 'Special Badge'),      # Exclusive profile badges
        ('feature', 'Feature Unlock'),   # Premium feature access
    ]

    # -- Core identity fields ---------------------------------------------------
    name = models.CharField(max_length=255)
    description = models.TextField()
    reward_type = models.CharField(max_length=50, choices=REWARD_TYPES)

    # -- Unlock requirements ----------------------------------------------------
    level_required = models.IntegerField(default=1)       # Min user level
    points_required = models.IntegerField(default=0)      # Min cumulative points
    achievement_required = models.ForeignKey(              # Optional prerequisite badge
        Achievement,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    # -- Visual / UI representation ---------------------------------------------
    icon_code = models.IntegerField(default=0xE8F4)           # Material icon codepoint
    preview_image_url = models.URLField(blank=True, null=True) # Preview thumbnail URL

    # -- Payload ----------------------------------------------------------------
    reward_data = models.JSONField(default=dict)  # Arbitrary JSON: theme colours, icon codes, etc.

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'rewards'
        ordering = ['level_required', 'points_required']

    def __str__(self):
        """Return 'Reward Name (type)'."""
        return f"{self.name} ({self.reward_type})"


# =============================================================================
# User ↔ Reward Join Model
# =============================================================================

class UserReward(models.Model):
    """
    Records a reward unlocked by a specific user.

    Each user may unlock a reward at most once (enforced by ``unique_together``).
    The ``is_active`` flag indicates whether the user has the reward currently
    equipped / enabled (e.g. an active theme or icon pack).

    Attributes:
        user:        The user who unlocked the reward.
        reward:      The reward that was unlocked.
        unlocked_at: Timestamp when the reward was unlocked.
        is_active:   Whether the reward is currently equipped by the user.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='rewards'
    )
    reward = models.ForeignKey(
        Reward,
        on_delete=models.CASCADE,
        related_name='user_rewards'
    )
    unlocked_at = models.DateTimeField(auto_now_add=True)     # When the reward was unlocked
    is_active = models.BooleanField(default=False)            # True if currently equipped/in use

    class Meta:
        db_table = 'user_rewards'
        unique_together = ('user', 'reward')

    def __str__(self):
        """Return '{email} – {reward name}'."""
        return f"{self.user.email} - {self.reward.name}"
