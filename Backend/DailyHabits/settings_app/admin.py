from django.contrib import admin
from django.utils.html import format_html

from .models import (
    UserSettings, PrivacySettings, SecuritySettings,
    LoginSession, SettingsAuditLog, ExportRequest,
    PrivacyPolicy, FAQ, SupportTicket,
)


@admin.register(UserSettings)
class UserSettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'theme', 'accent_color', 'font_size', 'language', 'updated_at']
    list_filter = ['theme', 'accent_color', 'language']
    search_fields = ['user__email']


@admin.register(PrivacySettings)
class PrivacySettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'account_visibility', 'who_can_view_habits', 'who_can_send_friend_requests', 'updated_at']
    list_filter = ['account_visibility']
    search_fields = ['user__email']


@admin.register(SecuritySettings)
class SecuritySettingsAdmin(admin.ModelAdmin):
    list_display = ['user', 'two_factor_badge', 'biometric_badge', 'session_timeout_minutes', 'updated_at']
    list_filter = ['two_factor_enabled', 'biometric_lock_enabled']
    search_fields = ['user__email']

    @admin.display(description='2FA', ordering='two_factor_enabled')
    def two_factor_badge(self, obj):
        if obj.two_factor_enabled:
            return format_html('<span style="color:{};font-weight:600;">● Enabled</span>', '#16a34a')
        return format_html('<span style="color:{};">● Off</span>', '#94a3b8')

    @admin.display(description='Biometric', ordering='biometric_lock_enabled')
    def biometric_badge(self, obj):
        if obj.biometric_lock_enabled:
            return format_html('<span style="color:{};font-weight:600;">● Enabled</span>', '#16a34a')
        return format_html('<span style="color:{};">● Off</span>', '#94a3b8')


@admin.register(LoginSession)
class LoginSessionAdmin(admin.ModelAdmin):
    list_display = ['user', 'device_name', 'platform', 'ip_address', 'active_badge', 'logged_in_at']
    list_filter = ['platform', 'is_active', 'device_type']
    search_fields = ['user__email', 'device_name', 'ip_address']
    list_per_page = 50

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Ended</span>', '#94a3b8')


@admin.register(SettingsAuditLog)
class SettingsAuditLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'category', 'action', 'ip_address', 'created_at']
    list_filter = ['category']
    search_fields = ['user__email', 'action', 'description']
    readonly_fields = ['user', 'category', 'action', 'description', 'old_value', 'new_value', 'ip_address', 'user_agent', 'created_at']
    list_per_page = 50
    date_hierarchy = 'created_at'

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(ExportRequest)
class ExportRequestAdmin(admin.ModelAdmin):
    list_display = ['user', 'export_format', 'status_badge', 'created_at']
    list_filter = ['export_format', 'status']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        colors = {'pending': '#f59e0b', 'processing': '#3b82f6', 'completed': '#16a34a', 'failed': '#dc2626'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())


@admin.register(PrivacyPolicy)
class PrivacyPolicyAdmin(admin.ModelAdmin):
    list_display = ['version', 'title', 'effective_date', 'current_badge']
    list_filter = ['is_current']

    @admin.display(description='Current', ordering='is_current')
    def current_badge(self, obj):
        if obj.is_current:
            return format_html('<span style="color:{};font-weight:600;">● Current</span>', '#16a34a')
        return format_html('<span style="color:{};">● Archived</span>', '#94a3b8')


@admin.register(FAQ)
class FAQAdmin(admin.ModelAdmin):
    list_display = ['question', 'category', 'sort_order', 'active_badge']
    list_filter = ['category', 'is_active']
    list_editable = ['sort_order']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'subject', 'category', 'priority_badge', 'status_badge', 'created_at']
    list_filter = ['status', 'priority', 'category']
    search_fields = ['subject', 'description', 'user__email']
    list_per_page = 50
    date_hierarchy = 'created_at'
    actions = ['mark_resolved', 'mark_in_progress']

    @admin.display(description='Priority', ordering='priority')
    def priority_badge(self, obj):
        colors = {'low': '#94a3b8', 'medium': '#f59e0b', 'high': '#dc2626', 'urgent': '#7f1d1d'}
        color = colors.get(obj.priority, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.priority.upper())

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        colors = {'open': '#f59e0b', 'in_progress': '#3b82f6', 'resolved': '#16a34a', 'closed': '#94a3b8'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.replace('_', ' ').capitalize())

    @admin.action(description='Mark as resolved')
    def mark_resolved(self, request, queryset):
        queryset.update(status='resolved')

    @admin.action(description='Mark as in progress')
    def mark_in_progress(self, request, queryset):
        queryset.update(status='in_progress')
