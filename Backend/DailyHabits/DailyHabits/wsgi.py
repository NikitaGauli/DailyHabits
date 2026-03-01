"""
=============================================================================
 WSGI Entry Point — DailyHabits Project
=============================================================================

 Module:  DailyHabits/wsgi.py
 Project: DailyHabits Backend

 Purpose:
   Exposes the WSGI-compatible ``application`` callable used by synchronous
   web servers (Gunicorn, uWSGI, Apache mod_wsgi) to serve the Django app.

   This is the standard production entry point for traditional request/
   response deployments.

 Usage:
   gunicorn DailyHabits.wsgi:application --bind 0.0.0.0:8000

 Reference:
   https://docs.djangoproject.com/en/6.0/howto/deployment/wsgi/
=============================================================================
"""

import os

from django.core.wsgi import get_wsgi_application

# Ensure the settings module is discoverable before the WSGI app initialises.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

# Build and expose the WSGI application object.
application = get_wsgi_application()
