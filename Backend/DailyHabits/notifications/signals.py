"""
Notification Signals — Real-Time Broadcast Integration
======================================================

Django signal handlers that bridge the ORM notification lifecycle with
the Django Channels WebSocket layer.

When a new :class:`~notifications.models.Notification` is created (via
``post_save``), the :func:`broadcast_notification` handler serialises the
notification and sends it to the user's channel group.  All connected
WebSocket clients for that user instantly receive the event.

Signal Flow
-----------
1. ``NotificationCreator.create()`` inserts a ``Notification`` row.
2. Django emits ``post_save`` with ``created=True``.
3. :func:`broadcast_notification` fires asynchronously via ``async_to_sync``.
4. The channel layer delivers the event to
   ``notifications_user_{user_id}``.
5. :meth:`NotificationConsumer.new_notification` forwards to the client.

Performance Notes
-----------------
- ``async_to_sync`` is used because signal handlers run in a synchronous
  context.  This is safe for the in-memory channel layer and Redis-backed
  layers.
- The notification is serialised inline to avoid circular imports with
  the serializer module.  Only the fields needed by the Flutter client
  are included.

See Also
--------
- :mod:`notifications.consumers` — WebSocket consumer.
- :class:`notifications.services.NotificationCreator` — Notification factory.
- :mod:`notifications.apps` — Signal connection point.
"""

import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

logger = logging.getLogger(__name__)


@receiver(post_save, sender='notifications.Notification')
def broadcast_notification(sender, instance, created, **kwargs):
    """
    Broadcasts a newly created notification to the user's WebSocket group.

    Triggered by Django's ``post_save`` signal whenever a
    :class:`~notifications.models.Notification` is saved.  Only fires for
    **new** notifications (``created=True``) to avoid duplicate broadcasts
    on subsequent updates (e.g., marking as read).

    The event payload includes full notification metadata so the Flutter
    client can render the notification card without a follow-up API call.

    Args:
        sender: The ``Notification`` model class.
        instance: The saved ``Notification`` instance.
        created: ``True`` if this is a new record.
        **kwargs: Additional signal keyword arguments (unused).
    """
    if not created:
        return

    # Build the notification payload for WebSocket
    notification_data = {
        'id': instance.id,
        'type': instance.notification_type,
        'title': instance.title,
        'message': instance.message,
        'status': instance.status,
        'scheduledTime': instance.scheduled_time.isoformat() if instance.scheduled_time else None,
        'sentAt': instance.sent_at.isoformat() if instance.sent_at else None,
        'iconCode': instance.icon_code,
        'colorValue': instance.color_value,
        'actionType': instance.action_type,
        'actionData': instance.action_data or {},
        'habitId': instance.habit_id,
        'fromUserId': instance.from_user_id if instance.from_user_id else None,
        'fromUserName': instance.from_user.name if instance.from_user_id else None,
        'fromUserImage': None,
        'groupId': instance.group_id if instance.group_id else None,
        'groupName': instance.group.name if instance.group_id else None,
        'habitTitle': instance.habit.title if instance.habit_id else None,
    }

    # --- WebSocket broadcast ---
    try:
        from channels.layers import get_channel_layer
        from asgiref.sync import async_to_sync

        channel_layer = get_channel_layer()
        if channel_layer is not None:
            group_name = f'notifications_user_{instance.user_id}'

            async_to_sync(channel_layer.group_send)(
                group_name,
                {
                    'type': 'new_notification',
                    'notification': notification_data,
                },
            )

            # Send updated badge count
            from notifications.models import Notification
            unread_count = Notification.objects.filter(
                user_id=instance.user_id,
                status='sent',
            ).count()

            async_to_sync(channel_layer.group_send)(
                group_name,
                {
                    'type': 'badge_update',
                    'unread_count': unread_count,
                },
            )

            logger.info(
                'Broadcast notification id=%s to group=%s (unread=%s)',
                instance.id,
                group_name,
                unread_count,
            )
    except Exception as e:
        logger.error('Failed to broadcast notification via WebSocket: %s', e, exc_info=True)


