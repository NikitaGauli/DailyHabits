"""
Achievements App Configuration
================================
Django application configuration for the ``achievements`` app.

This app provides the gamification layer for DailyHabits, including
achievement badges, user XP/levels, and unlockable rewards.
"""

from django.apps import AppConfig


class AchievementsConfig(AppConfig):
    """Configuration class for the achievements Django application."""

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'achievements'
    verbose_name = 'Achievements & Rewards'
