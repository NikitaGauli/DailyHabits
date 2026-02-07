"""
Notifications Admin
"""

from django.contrib import admin
from .models import Notification, NotificationSettings, HabitReminder


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'notification_type', 'title', 'status', 'scheduled_time', 'sent_at']
    list_filter = ['notification_type', 'status', 'scheduled_time']
    search_fields = ['user__email', 'title', 'message']
    ordering = ['-scheduled_time']


@admin.register(NotificationSettings)
class NotificationSettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'notifications_enabled', 'habit_reminders', 'quiet_hours_enabled']
    list_filter = ['notifications_enabled', 'quiet_hours_enabled']
    search_fields = ['user__email']


@admin.register(HabitReminder)
class HabitReminderAdmin(admin.ModelAdmin):
    list_display = ['habit', 'reminder_time', 'repeat_type', 'is_enabled', 'last_sent']
    list_filter = ['repeat_type', 'is_enabled']
    ordering = ['reminder_time']
