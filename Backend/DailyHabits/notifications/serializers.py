"""
Notifications Serializers
"""

from rest_framework import serializers
from .models import Notification, SmartTip, NotificationSettings, HabitReminder


class NotificationSerializer(serializers.ModelSerializer):
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

    def get_fromUserName(self, obj):
        return obj.from_user.name if obj.from_user else None

    def get_fromUserImage(self, obj):
        return obj.from_user.profile_image if obj.from_user else None

    def get_habitTitle(self, obj):
        return obj.habit.title if obj.habit else None

    def get_groupName(self, obj):
        return obj.group.name if obj.group else None


class SmartTipSerializer(serializers.ModelSerializer):
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
        return obj.habit.title if obj.habit else None


class NotificationSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationSettings
        exclude = ['id', 'user', 'updated_at']


class HabitReminderSerializer(serializers.ModelSerializer):
    habitTitle = serializers.CharField(source='habit.title', read_only=True)

    class Meta:
        model = HabitReminder
        fields = [
            'id', 'habit', 'habitTitle', 'reminder_time',
            'repeat_type', 'custom_days', 'is_enabled',
            'message', 'last_sent', 'created_at'
        ]
        read_only_fields = ['id', 'last_sent', 'created_at']
