"""
WebSocket URL Routing — Notifications
======================================

Defines the WebSocket URL patterns for the real-time notification subsystem.

This module maps incoming WebSocket connections to the appropriate consumer:

- ``ws/notifications/`` → :class:`NotificationConsumer`

The URL patterns are included by the project-level ASGI router
(``DailyHabits/routing.py``) and wrapped in an ``AuthMiddlewareStack``
for JWT-based authentication.

Usage (client)::

    ws://localhost:8000/ws/notifications/?token=<jwt_access_token>
"""

from django.urls import re_path

from . import consumers

# =============================================================================
#  WebSocket URL Patterns
# =============================================================================

websocket_urlpatterns = [
    re_path(r'ws/notifications/$', consumers.NotificationConsumer.as_asgi()),
]
