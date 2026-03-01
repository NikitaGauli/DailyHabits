"""
Settings App — Application Configuration
==========================================

Django ``AppConfig`` for the ``settings_app`` application.

This app manages user-facing settings, device tokens, data exports,
privacy policies, FAQs, and support tickets within the DailyHabits
project.  The ``verbose_name`` is surfaced in the Django admin sidebar
as *User Settings & Support*.
"""

from django.apps import AppConfig


# =============================================================================
# APP CONFIGURATION
# =============================================================================


class SettingsAppConfig(AppConfig):
    """
    Configuration class for the ``settings_app`` Django application.

    Attributes:
        default_auto_field: Uses ``BigAutoField`` for 64-bit auto-incrementing
            primary keys, supporting large-scale datasets.
        name: Internal dotted-path identifier used by Django's app registry.
        verbose_name: Human-readable label shown in the admin interface.
    """

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'settings_app'
    verbose_name = 'User Settings & Support'
