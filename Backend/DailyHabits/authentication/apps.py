"""
=============================================================================
 Authentication App Configuration
=============================================================================

 Module:  authentication/apps.py
 Project: DailyHabits Backend

 Purpose:
   Standard Django AppConfig for the 'authentication' application.
   Registered in INSTALLED_APPS via the dotted path 'authentication'.
=============================================================================
"""

from django.apps import AppConfig


class AuthenticationConfig(AppConfig):
    """Django application configuration for the authentication module."""

    name = 'authentication'
