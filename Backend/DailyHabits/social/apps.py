"""
Social App \u2014 Application Configuration
=======================================

Django ``AppConfig`` for the ``social`` application.  Registers the app
under the human-readable name *Social Sharing* and sets the default
auto-field type to ``BigAutoField`` for all models in this app.
"""

from django.apps import AppConfig


class SocialConfig(AppConfig):
    """Django application configuration for the Social / Community app.

    Attributes:
        default_auto_field: Uses 64-bit big integers for auto-generated
            primary keys to accommodate high-volume tables (feed posts,
            likes, comments).
        name: Python module path used by Django's app registry.
        verbose_name: Human-readable label shown in the Django admin.
    """

    default_auto_field = 'django.db.models.BigAutoField'
    name = 'social'
    verbose_name = 'Social Sharing'
