"""
WebSocket Consumer — Real-Time Notifications
=============================================

Implements the server-side WebSocket handler for delivering instant
notifications to connected Flutter clients.

Architecture
------------
Each authenticated user is added to a unique **channel layer group**
named ``notifications_user_<user_id>``.  When a new notification is
persisted (via :class:`~notifications.services.NotificationCreator`),
a Django signal fires :func:`broadcast_notification`, which pushes a
JSON event into the user's group.  The consumer receives the group
message and forwards it to the WebSocket as a ``new_notification``
event.

Authentication
--------------
The consumer extracts a JWT access token from the WebSocket query
string (``?token=<access_token>``) during the ``connect`` phase.
If the token is invalid, expired, or missing, the connection is
rejected with **4001 Unauthorized**.

This approach avoids cookie-based session authentication, which is
unreliable for native mobile WebSocket clients (Flutter/Android/iOS).

Event Types (client → server)
-----------------------------
``ping``
    Keepalive heartbeat.  The server responds with ``{"type": "pong"}``.

Event Types (server → client)
-----------------------------
``new_notification``
    A new notification was created for this user::

        {
            "type": "new_notification",
            "notification": {
                "id": 42,
                "notification_type": "friend_request",
                "title": "New Friend Request",
                "message": "John wants to be your friend!",
                ...
            }
        }

``badge_update``
    The unread notification count changed::

        {
            "type": "badge_update",
            "unread_count": 5
        }

Channel Group Naming
--------------------
``notifications_user_{user_id}``
    One group per user.  Multiple devices / tabs receive the same events.

Dependencies
------------
- ``channels`` — Django Channels async WebSocket consumer.
- ``channels.layers`` — In-process or Redis-backed channel layer.
- ``rest_framework_simplejwt`` — JWT token validation.

See Also
--------
- :mod:`notifications.signals` — Signal handler that triggers broadcasts.
- :mod:`notifications.routing` — WebSocket URL registration.
- :mod:`DailyHabits.asgi` — ASGI application with protocol router.
"""

import json
import logging
from typing import TYPE_CHECKING

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)

User = get_user_model()

if TYPE_CHECKING:
    from rest_framework_simplejwt.tokens import Token


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    Async WebSocket consumer for per-user real-time notifications.

    Lifecycle::

        connect()   → authenticate via JWT, join user channel group
        receive()   → handle client messages (ping/pong keepalive)
        disconnect()→ leave channel group

    Group messages dispatched from :func:`notifications.signals.broadcast_notification`
    are routed to :meth:`new_notification` or :meth:`badge_update` based
    on the ``type`` key.
    """

    # ── Channel group name for this connection ───────────────────────
    group_name: str = ''

    # ── Authenticated user (resolved during connect) ─────────────────
    user: 'User | None' = None  # type: ignore[assignment]

    # ─────────────────────────────────────────────────────────────────
    #  Connection Lifecycle
    # ─────────────────────────────────────────────────────────────────

    async def connect(self):
        """
        Handles a new WebSocket connection request.

        1. Extracts the JWT access token from the ``?token=`` query param.
        2. Validates the token and resolves the user.
        3. Adds the socket to the user's notification channel group.
        4. Accepts the connection and sends an initial badge count.

        Rejects with close code **4001** if authentication fails.
        """
        # Extract JWT from query string: ws://host/ws/notifications/?token=xxx
        query_string = self.scope.get('query_string', b'').decode('utf-8')
        token = self._parse_token(query_string)

        if not token:
            logger.warning('WebSocket connection rejected: no token provided')
            await self.close(code=4001)
            return

        # Validate the JWT and resolve the user
        self.user = await self._authenticate(token)
        if self.user is None:
            logger.warning('WebSocket connection rejected: invalid token')
            await self.close(code=4001)
            return

        # Build the per-user channel group name
        self.group_name = f'notifications_user_{self.user.id}'

        # Join the channel group so broadcast messages reach this socket
        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name,
        )

        # Accept the WebSocket handshake
        await self.accept()

        logger.info(
            'WebSocket connected: user=%s group=%s',
            self.user.email,
            self.group_name,
        )

        # Send the current unread badge count immediately after connection
        unread_count = await self._get_unread_count()
        await self.send(text_data=json.dumps({
            'type': 'badge_update',
            'unread_count': unread_count,
        }))

    async def disconnect(self, close_code):
        """
        Handles WebSocket disconnection.

        Removes this socket from the user's channel group so it no longer
        receives broadcast events.
        """
        if self.group_name:
            await self.channel_layer.group_discard(
                self.group_name,
                self.channel_name,
            )
            logger.info(
                'WebSocket disconnected: user=%s code=%s',
                getattr(self.user, 'email', 'unknown'),
                close_code,
            )

    # ─────────────────────────────────────────────────────────────────
    #  Client → Server Messages
    # ─────────────────────────────────────────────────────────────────

    async def receive(self, text_data=None, bytes_data=None):
        """
        Handles incoming messages from the client.

        Supported message types:

        - ``ping`` — Responds with ``{"type": "pong"}`` for keepalive.
        - ``mark_read`` — Marks a notification as read and broadcasts badge update.

        All other messages are silently ignored to avoid coupling.
        """
        if not text_data:
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        msg_type = data.get('type', '')

        if msg_type == 'ping':
            await self.send(text_data=json.dumps({'type': 'pong'}))

        elif msg_type == 'mark_read':
            notification_id = data.get('notification_id')
            if notification_id:
                await self._mark_notification_read(notification_id)
                # Broadcast updated badge count to all user's devices
                unread_count = await self._get_unread_count()
                await self.channel_layer.group_send(
                    self.group_name,
                    {
                        'type': 'badge_update',
                        'unread_count': unread_count,
                    },
                )

    # ─────────────────────────────────────────────────────────────────
    #  Server → Client Event Handlers (channel layer dispatch)
    # ─────────────────────────────────────────────────────────────────

    async def new_notification(self, event):
        """
        Forwards a ``new_notification`` group event to the WebSocket client.

        Event structure (from channel layer)::

            {
                "type": "new_notification",
                "notification": { ... serialized notification dict ... }
            }
        """
        await self.send(text_data=json.dumps({
            'type': 'new_notification',
            'notification': event['notification'],
        }))

    async def badge_update(self, event):
        """
        Forwards a ``badge_update`` group event to the WebSocket client.

        Event structure (from channel layer)::

            {
                "type": "badge_update",
                "unread_count": 5
            }
        """
        await self.send(text_data=json.dumps({
            'type': 'badge_update',
            'unread_count': event['unread_count'],
        }))

    # ─────────────────────────────────────────────────────────────────
    #  Private Helpers
    # ─────────────────────────────────────────────────────────────────

    @staticmethod
    def _parse_token(query_string: str) -> str | None:
        """
        Extracts the ``token`` parameter from a URL query string.

        Args:
            query_string: Raw query string (e.g. ``"token=abc123&foo=bar"``).

        Returns:
            The token value, or ``None`` if not found.
        """
        from urllib.parse import parse_qs
        params = parse_qs(query_string)
        tokens = params.get('token', [])
        return tokens[0] if tokens else None

    @database_sync_to_async
    def _authenticate(self, token: str):
        """
        Validates a JWT access token and returns the associated user.

        Uses ``rest_framework_simplejwt`` for token validation to stay
        consistent with the REST API authentication layer.

        Args:
            token: Raw JWT access token string.

        Returns:
            The ``User`` instance, or ``None`` if the token is invalid.
        """
        try:
            from rest_framework_simplejwt.tokens import AccessToken
            validated = AccessToken(token)  # type: ignore[arg-type]
            user_id = validated['user_id']
            return User.objects.get(id=user_id)
        except Exception as e:
            logger.warning('JWT validation failed: %s', e)
            return None

    @database_sync_to_async
    def _get_unread_count(self) -> int:
        """
        Returns the number of unread notifications for the connected user.

        Counts notifications with ``status='sent'`` (delivered but not yet
        read by the user).
        """
        from notifications.models import Notification
        return Notification.objects.filter(
            user=self.user,
            status='sent',
        ).count()

    @database_sync_to_async
    def _mark_notification_read(self, notification_id: int) -> bool:
        """
        Marks a single notification as read for the connected user.

        Args:
            notification_id: Primary key of the notification.

        Returns:
            ``True`` if the notification was found and updated.
        """
        from notifications.models import Notification
        from django.utils import timezone
        try:
            notification = Notification.objects.get(
                id=notification_id,
                user=self.user,
            )
            if notification.status != 'read':
                notification.status = 'read'
                notification.read_at = timezone.now()
                notification.save(update_fields=['status', 'read_at'])
            return True
        except Notification.DoesNotExist:
            return False
