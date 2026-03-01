from django.contrib import admin
from django.utils.html import format_html

from .models import Notification, NotificationSettings, HabitReminder


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'notification_type', 'title', 'status_badge', 'scheduled_time', 'sent_at']
    list_filter = ['notification_type', 'status', 'scheduled_time']
    search_fields = ['user__email', 'title', 'message']
    ordering = ['-scheduled_time']
    list_per_page = 50

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        colors = {'pending': '#f59e0b', 'sent': '#16a34a', 'failed': '#dc2626', 'read': '#3b82f6'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())


@admin.register(NotificationSettings)
class NotificationSettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'enabled_badge', 'habit_reminders', 'quiet_hours_enabled']
    list_filter = ['notifications_enabled', 'quiet_hours_enabled']
    search_fields = ['user__email']

    @admin.display(description='Enabled', ordering='notifications_enabled')
    def enabled_badge(self, obj):
        if obj.notifications_enabled:
            return format_html('<span style="color:{};">● On</span>', '#16a34a')
        return format_html('<span style="color:{};">● Off</span>', '#dc2626')


@admin.register(HabitReminder)
class HabitReminderAdmin(admin.ModelAdmin):
    list_display = ['habit', 'reminder_time', 'repeat_type', 'enabled_badge', 'last_sent']
    list_filter = ['repeat_type', 'is_enabled']
    ordering = ['reminder_time']
    search_fields = ['habit__title', 'habit__user__email']

    @admin.display(description='Enabled', ordering='is_enabled')
    def enabled_badge(self, obj):
        if obj.is_enabled:
            return format_html('<span style="color:{};">● On</span>', '#16a34a')
        return format_html('<span style="color:{};">● Off</span>', '#94a3b8')
