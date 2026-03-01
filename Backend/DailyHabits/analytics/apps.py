"""
Analytics App Configuration — analytics/apps.py

Configures the ``analytics`` Django application. This app provides cached
analytics summaries (daily, weekly, monthly) and per-habit lifetime statistics
to power the DailyHabits dashboard and insights screens.
"""

from django.apps import AppConfig


# =============================================================================
# App Config
# =============================================================================

class AnalyticsConfig(AppConfig):
    """
    Django AppConfig for the Analytics application.

    Attributes:
        default_auto_field: Uses BigAutoField for 64-bit auto-incrementing PKs.
        name:               Internal app label used by Django's app registry.
        verbose_name:       Human-readable name shown in the admin site header.
    """

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'analytics'
    verbose_name = 'Analytics & Statistics'
