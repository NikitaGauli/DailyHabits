"""
Project-Level WebSocket Routing — DailyHabits
==============================================

Aggregates WebSocket URL patterns from all apps and exposes them as
``websocket_urlpatterns`` for the ASGI ``ProtocolTypeRouter``.

Currently registered WebSocket apps:

- **notifications** — Real-time notification delivery
  (``ws/notifications/``)

To add WebSocket endpoints from another app, import its
``websocket_urlpatterns`` and extend the list below.

See Also
--------
- :mod:`DailyHabits.asgi`             — ASGI entry point with protocol routing.
- :mod:`notifications.routing`         — Notification WebSocket URL patterns.
- :mod:`notifications.consumers`       — Notification WebSocket consumer.
"""

from notifications.routing import websocket_urlpatterns as notification_ws

# =============================================================================
#  Combined WebSocket URL Patterns
# =============================================================================

websocket_urlpatterns = [
    *notification_ws,
]
