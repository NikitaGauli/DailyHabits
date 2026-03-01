"""
Notifications App Configuration
===============================
Django application configuration for the ``notifications`` app.

This app manages all user-facing notification features including:

- Inbox notifications (system, social, habit-related)
- Personalized smart tips (AI-generated habit guidance)
- Per-user notification preferences and delivery controls
- Per-habit recurring reminders with flexible scheduling

The ``verbose_name`` is displayed in the Django admin sidebar.
"""

from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    """
    AppConfig for the ``notifications`` Django application.

    Attributes:
        default_auto_field: Uses ``BigAutoField`` for 64-bit auto-incrementing
            primary keys (Django 3.2+ default).
        name: Dotted Python path used by the Django app registry.
        verbose_name: Human-readable label shown in the admin dashboard.
    """

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notifications'
    verbose_name = 'Notifications & Reminders'
