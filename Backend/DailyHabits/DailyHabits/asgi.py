"""
=============================================================================
 ASGI Entry Point — DailyHabits Project
=============================================================================

 Module:  DailyHabits/asgi.py
 Project: DailyHabits Backend

 Purpose:
   Exposes the ASGI-compatible ``application`` callable for asynchronous
   servers (Daphne, Uvicorn, Hypercorn).  Supports HTTP, WebSocket,
   and other async protocols.

   Currently the project uses synchronous WSGI in production; this file
   is provided for future migration to async channels/WebSocket features.

 Usage:
   uvicorn DailyHabits.asgi:application --host 0.0.0.0 --port 8000

 Reference:
   https://docs.djangoproject.com/en/6.0/howto/deployment/asgi/
=============================================================================
"""

import os

from django.core.asgi import get_asgi_application

# Ensure the settings module is discoverable before the ASGI app initialises.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

# Build and expose the ASGI application object.
application = get_asgi_application()
