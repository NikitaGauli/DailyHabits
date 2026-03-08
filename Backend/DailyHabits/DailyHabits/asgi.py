"""
=============================================================================
 ASGI Entry Point — DailyHabits Project
=============================================================================

 Module:  DailyHabits/asgi.py
 Project: DailyHabits Backend

 Purpose:
   Exposes the ASGI-compatible ``application`` callable that handles both
   HTTP and WebSocket protocols via Django Channels' ``ProtocolTypeRouter``.

   - **HTTP requests** are served by the standard Django ASGI handler.
   - **WebSocket connections** are routed through ``URLRouter`` to the
     notification consumer (and any future WebSocket endpoints).

 WebSocket Authentication:
   JWT tokens are passed via query string (``?token=<access_token>``) and
   validated inside each consumer's ``connect()`` method.  This avoids
   Django's session-based ``AuthMiddlewareStack`` which is unreliable for
   native mobile clients.

 Usage:
   daphne DailyHabits.asgi:application -b 0.0.0.0 -p 8000
   uvicorn DailyHabits.asgi:application --host 0.0.0.0 --port 8000

 Reference:
   https://channels.readthedocs.io/en/stable/deploying.html
=============================================================================
"""

import os

from django.core.asgi import get_asgi_application

# Ensure the settings module is discoverable before the ASGI app initialises.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

# Initialise Django BEFORE importing channel routing (models must be ready).
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402
from DailyHabits.routing import websocket_urlpatterns        # noqa: E402

# =============================================================================
#  ASGI Application — Protocol Router
# =============================================================================
#
# Routes incoming connections by protocol:
#   - "http"      → Standard Django views (REST API, admin, static files)
#   - "websocket" → Django Channels consumers (notifications, future features)
#
# Note: We intentionally do NOT wrap WebSocket routes in
# ``AuthMiddlewareStack`` because JWT authentication is handled inside
# each consumer's ``connect()`` method via the query string token.
# This is more reliable for Flutter / mobile WebSocket clients.
# =============================================================================

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    'websocket': URLRouter(websocket_urlpatterns),
})
