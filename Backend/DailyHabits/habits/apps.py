"""
Habits App Configuration
========================

Django application configuration for the ``habits`` app.  This file is
automatically referenced via the ``INSTALLED_APPS`` setting in the
project’s ``settings.py`` and controls the app label, default primary-key
type, and any startup-time initialisation hooks.

Authors:
    DailyHabits Engineering Team

Since:
    v1.0.0
"""

# === Django Imports ==========================================================
from django.apps import AppConfig


class HabitsConfig(AppConfig):
    """
    Application configuration for the *habits* Django app.

    Attributes:
        default_auto_field (str): Uses 64-bit ``BigAutoField`` for future-proof
            primary key generation.
        name (str): Python path used by Django to locate the app module.
    """

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'habits'
