"""
Notification Serializers
========================
REST Framework serializers for the notifications app.

Each serializer maps a notification model to a JSON-friendly representation
consumed by the Flutter front-end.  Computed fields use **camelCase** names
(e.g. ``fromUserName``, ``habitTitle``) to match the front-end convention,
while the underlying model fields remain in **snake_case**.

Serializers
-----------
- :class:`NotificationSerializer`         — Inbox notifications with social metadata.
- :class:`SmartTipSerializer`             — Personalized smart tips.
- :class:`NotificationSettingsSerializer` — User notification preferences.
- :class:`HabitReminderSerializer`        — Per-habit recurring reminders.
"""

from rest_framework import serializers
from .models import Notification, SmartTip, NotificationSettings, HabitReminder


# =============================================================================
#  NOTIFICATION SERIALIZER — inbox notifications
# =============================================================================

class NotificationSerializer(serializers.ModelSerializer):
    """
    Serializer for :class:`~notifications.models.Notification`.

    Includes denormalized fields from related models so the front-end can
    render notification cards without extra API calls:

    - ``fromUserName`` / ``fromUserImage`` — originator info for social events.
    - ``habitTitle`` — linked habit name for habit-related notifications.
    - ``groupName`` — linked group name for group-related notifications.
    """

    # -- Computed (read-only) fields resolved from related objects --
    fromUserName = serializers.SerializerMethodField()
    fromUserImage = serializers.SerializerMethodField()
    habitTitle = serializers.SerializerMethodField()
    groupName = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = [
            'id', 'notification_type', 'title', 'message',
            'status', 'scheduled_time', 'sent_at', 'read_at',
            'icon_code', 'color_value',
            'action_type', 'action_data',
            'habit', 'from_user', 'group',
            'fromUserName', 'fromUserImage',
            'habitTitle', 'groupName',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'sent_at', 'read_at']

    # -- SerializerMethodField resolvers --

    def get_fromUserName(self, obj):
        """Return the display name of the notification originator, or ``None``."""
        return obj.from_user.name if obj.from_user else None

    def get_fromUserImage(self, obj):
        """Return the profile-image URL of the originator, or ``None``."""
        return obj.from_user.profile_image if obj.from_user else None

    def get_habitTitle(self, obj):
        """Return the linked habit's title, or ``None`` if not habit-related."""
        return obj.habit.title if obj.habit else None

    def get_groupName(self, obj):
        """Return the linked group's name, or ``None`` if not group-related."""
        return obj.group.name if obj.group else None


# =============================================================================
#  SMART TIP SERIALIZER — personalized guidance cards
# =============================================================================

class SmartTipSerializer(serializers.ModelSerializer):
    """
    Serializer for :class:`~notifications.models.SmartTip`.

    Exposes all engagement flags (``is_read``, ``is_liked``, ``is_saved``,
    ``is_dismissed``) so the front-end can render toggle states.  The computed
    ``habitTitle`` avoids an extra request to resolve the related habit.
    """

    habitTitle = serializers.SerializerMethodField()

    class Meta:
        model = SmartTip
        fields = [
            'id', 'tip_type', 'title', 'message',
            'icon_code', 'color_value',
            'is_read', 'is_liked', 'is_saved', 'is_dismissed',
            'habit', 'habitTitle',
            'metadata', 'created_at', 'expires_at',
        ]
        read_only_fields = ['id', 'created_at']

    def get_habitTitle(self, obj):
        """Return the related habit's title, or ``None`` for generic tips."""
        return obj.habit.title if obj.habit else None


# =============================================================================
#  NOTIFICATION SETTINGS SERIALIZER — user preferences
# =============================================================================

class NotificationSettingsSerializer(serializers.ModelSerializer):
    """
    Serializer for :class:`~notifications.models.NotificationSettings`.

    Excludes ``id``, ``user``, and ``updated_at`` since those are internal
    fields managed server-side.  All remaining boolean/integer fields are
    directly writable by the front-end settings screen.
    """

    class Meta:
        model = NotificationSettings
        exclude = ['id', 'user', 'updated_at']


# =============================================================================
#  HABIT REMINDER SERIALIZER — per-habit recurring reminders
# =============================================================================

class HabitReminderSerializer(serializers.ModelSerializer):
    """
    Serializer for :class:`~notifications.models.HabitReminder`.

    Includes a read-only ``habitTitle`` sourced directly from the related
    habit via DRF's ``source`` kwarg, so the front-end can display the
    habit name alongside each reminder entry.
    """

    # Denormalized habit title resolved via source shortcut
    habitTitle = serializers.CharField(source='habit.title', read_only=True)

    class Meta:
        model = HabitReminder
        fields = [
            'id', 'habit', 'habitTitle', 'reminder_time',
            'repeat_type', 'custom_days', 'is_enabled',
            'message', 'last_sent', 'created_at'
        ]
        read_only_fields = ['id', 'last_sent', 'created_at']

