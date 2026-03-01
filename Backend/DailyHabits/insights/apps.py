"""
Insights App Configuration — DailyHabits Application
====================================================

Django application configuration for the **Insights** app.  Registers
the app under the name ``'insights'`` with a human-readable label used
in the Django admin sidebar.
"""

# ===========================================================================
# Imports
# ===========================================================================

from django.apps import AppConfig


# ===========================================================================
# App Configuration
# ===========================================================================


class InsightsConfig(AppConfig):
    """
    Configuration class for the Insights application.

    Attributes:
        default_auto_field (str): Use 64-bit big-integer primary keys.
        name (str): Python module path used by Django internals.
        verbose_name (str): Human-readable label displayed in the admin.
    """
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'insights'
    verbose_name = 'Smart Insights & Motivation'
