"""
Achievement Models
Gamification system with badges, levels, and rewards
"""

from django.db import models
from django.conf import settings


class Achievement(models.Model):
    """
    Achievement/Badge definitions
    """
    ACHIEVEMENT_TYPES = [
        ('streak', 'Streak Based'),
        ('completion', 'Completion Count'),
        ('consistency', 'Consistency Rate'),
        ('milestone', 'Milestone'),
        ('special', 'Special Achievement'),
    ]
    
    RARITY_CHOICES = [
        ('common', 'Common'),
        ('uncommon', 'Uncommon'),
        ('rare', 'Rare'),
        ('epic', 'Epic'),
        ('legendary', 'Legendary'),
    ]

    name = models.CharField(max_length=255)
    description = models.TextField()
    achievement_type = models.CharField(max_length=50, choices=ACHIEVEMENT_TYPES)
    
    # Requirements
    target_value = models.IntegerField()
    target_type = models.CharField(max_length=50, default='count')  # count, percentage, days
    
    # Visual
    icon_code = models.IntegerField(default=0xE87B)
    color_value = models.BigIntegerField(default=0xFFFFD700)  # Gold default
    badge_image_url = models.URLField(blank=True, null=True)
    
    # Gamification
    rarity = models.CharField(max_length=20, choices=RARITY_CHOICES, default='common')
    points = models.IntegerField(default=10)
    level_required = models.IntegerField(default=1)
    
    # Ordering
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    is_hidden = models.BooleanField(default=False)  # Secret achievements
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'achievements'
        ordering = ['order', 'level_required', 'points']

    def __str__(self):
        return f"{self.name} ({self.rarity})"


class UserAchievement(models.Model):
    """
    User's earned achievements
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
    
    # Context
    earned_at = models.DateTimeField(auto_now_add=True)
    earned_value = models.IntegerField(default=0)  # The value when earned
    is_notified = models.BooleanField(default=False)
    is_claimed = models.BooleanField(default=False)  # For reward claiming

    class Meta:
        db_table = 'user_achievements'
        unique_together = ('user', 'achievement', 'habit')
        ordering = ['-earned_at']

    def __str__(self):
        return f"{self.user.email} earned {self.achievement.name}"


class UserLevel(models.Model):
    """
    User level progression
    """
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
        (10, 'Habit Champion'),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='level'
    )
    
    current_level = models.IntegerField(default=1)
    current_xp = models.IntegerField(default=0)
    total_xp = models.IntegerField(default=0)
    
    # Stats
    total_achievements = models.IntegerField(default=0)
    achievements_this_month = models.IntegerField(default=0)
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_levels'

    def __str__(self):
        level_name = dict(self.LEVEL_NAMES).get(self.current_level, 'Unknown')
        return f"{self.user.email} - Level {self.current_level} ({level_name})"

    @property
    def level_name(self):
        return dict(self.LEVEL_NAMES).get(self.current_level, 'Unknown')

    @property
    def xp_for_next_level(self):
        """XP required for next level (exponential growth)"""
        return self.current_level * 100 + (self.current_level ** 2) * 50

    @property
    def xp_progress_percentage(self):
        """Progress towards next level as percentage"""
        required = self.xp_for_next_level
        return min(100, (self.current_xp / required) * 100) if required > 0 else 100

    def add_xp(self, amount):
        """Add XP and handle level ups"""
        self.current_xp += amount
        self.total_xp += amount
        
        leveled_up = False
        while self.current_xp >= self.xp_for_next_level and self.current_level < 10:
            self.current_xp -= self.xp_for_next_level
            self.current_level += 1
            leveled_up = True
        
        self.save()
        return leveled_up


class Reward(models.Model):
    """
    Rewards that can be unlocked
    """
    REWARD_TYPES = [
        ('theme', 'Theme Unlock'),
        ('icon', 'Icon Pack'),
        ('badge', 'Special Badge'),
        ('feature', 'Feature Unlock'),
    ]

    name = models.CharField(max_length=255)
    description = models.TextField()
    reward_type = models.CharField(max_length=50, choices=REWARD_TYPES)
    
    # Requirements
    level_required = models.IntegerField(default=1)
    points_required = models.IntegerField(default=0)
    achievement_required = models.ForeignKey(
        Achievement,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    
    # Visual
    icon_code = models.IntegerField(default=0xE8F4)
    preview_image_url = models.URLField(blank=True, null=True)
    
    # Data
    reward_data = models.JSONField(default=dict)  # Theme colors, icon codes, etc.
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'rewards'
        ordering = ['level_required', 'points_required']

    def __str__(self):
        return f"{self.name} ({self.reward_type})"


class UserReward(models.Model):
    """
    User's unlocked rewards
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
    unlocked_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=False)  # Currently in use

    class Meta:
        db_table = 'user_rewards'
        unique_together = ('user', 'reward')

    def __str__(self):
        return f"{self.user.email} - {self.reward.name}"
