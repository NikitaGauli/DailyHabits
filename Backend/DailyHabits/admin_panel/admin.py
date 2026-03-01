"""
admin_panel/admin.py — Production-Grade Admin Panel Registration
=================================================================
Enhanced admin for RBAC, moderation, system settings, audit logs,
feature flags, notification campaigns, analytics snapshots, and
AI safety monitoring.
"""

from django.contrib import admin
from django.db.models import QuerySet
from django.http import HttpRequest, HttpResponse
from django.utils import timezone
from django.utils.html import format_html

import csv

from .models import (
    AdminProfile, AdminRole, AISafetyLog, AIUserRestriction,
    AuditLog, ContentModerationQueue, FeatureFlag,
    NotificationCampaign, NotificationTemplate,
    PlatformAnalyticsSnapshot, Report, SystemSettings, UserWarning,
)


# ═══════════════════════════════════════════════════════════════════════════════
#  RBAC — Roles & Profiles
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(AdminRole)
class AdminRoleAdmin(admin.ModelAdmin):
    list_display = ['display_name', 'name', 'active_badge', 'profile_count', 'created_at']
    search_fields = ['name', 'display_name']
    list_filter = ['is_active']

    @admin.display(description='Status', ordering='is_active')
    def active_badge(self, obj: AdminRole) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};font-weight:600;">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')

    @admin.display(description='Profiles')
    def profile_count(self, obj: AdminRole) -> int:
        return AdminProfile.objects.filter(role=obj).count()


@admin.register(AdminProfile)
class AdminProfileAdmin(admin.ModelAdmin):
    list_display = [
        'user', 'role', 'active_badge', '2fa_badge',
        'last_admin_login',
    ]
    list_filter = ['role', 'is_active', 'two_factor_enabled']
    search_fields = ['user__email', 'user__name']
    list_per_page = 30

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj: AdminProfile) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#dc2626')

    @admin.display(description='2FA')
    def __2fa_badge(self, obj: AdminProfile) -> str:
        if obj.two_factor_enabled:
            return format_html('<span style="color:{};">🔒 Enabled</span>', '#16a34a')
        return format_html('<span style="color:{};">⚠ Off</span>', '#f59e0b')

    # Use a clean name for the column — rename to avoid leading dunder issues
    __2fa_badge.short_description = '2FA'

    def _2fa_badge(self, obj):
        return self.__2fa_badge(obj)
    _2fa_badge.short_description = '2FA'

    # Actually use a simpler approach:
    list_display = [
        'user', 'role', 'active_badge', 'two_factor_enabled',
        'last_admin_login',
    ]


# ═══════════════════════════════════════════════════════════════════════════════
#  AUDIT LOG
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = [
        'created_at', 'admin_email', 'action', 'resource_type',
        'resource_id', 'severity_badge',
    ]
    list_filter = ['action', 'severity', 'resource_type', 'created_at']
    search_fields = ['description', 'admin_user__email', 'resource_type', 'resource_id']
    readonly_fields = [
        'id', 'admin_user', 'action', 'resource_type', 'resource_id',
        'description', 'changes', 'ip_address', 'user_agent', 'metadata',
        'severity', 'created_at',
    ]
    list_per_page = 50
    date_hierarchy = 'created_at'
    actions = ['export_as_csv']

    @admin.display(description='Admin', ordering='admin_user__email')
    def admin_email(self, obj: AuditLog) -> str:
        if obj.admin_user:
            return obj.admin_user.email
        return 'System'

    @admin.display(description='Severity', ordering='severity')
    def severity_badge(self, obj: AuditLog) -> str:
        colors = {
            'info': '#3b82f6', 'warning': '#f59e0b',
            'error': '#dc2626', 'critical': '#dc2626',
        }
        color = colors.get(obj.severity, '#94a3b8')
        return format_html(
            '<span style="color:{};font-weight:600;">{}</span>',
            color, obj.severity.upper(),
        )

    @admin.action(description='📥 Export selected as CSV')
    def export_as_csv(self, request: HttpRequest, queryset: QuerySet) -> HttpResponse:
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="audit_logs.csv"'
        writer = csv.writer(response)
        writer.writerow(['Date', 'Admin', 'Action', 'Resource Type', 'Resource ID', 'Severity', 'Description'])
        for log in queryset.select_related('admin_user'):
            writer.writerow([
                log.created_at.isoformat(),
                log.admin_user.email if log.admin_user else 'System',
                log.action, log.resource_type, log.resource_id,
                log.severity, log.description,
            ])
        return response

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


# ═══════════════════════════════════════════════════════════════════════════════
#  MODERATION — Reports, Queue, Warnings
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'category', 'content_type', 'status_badge',
        'priority_badge', 'reporter_email', 'created_at',
    ]
    list_filter = ['status', 'priority', 'category', 'created_at']
    search_fields = ['description', 'reporter__email', 'reported_user__email']
    list_per_page = 30
    date_hierarchy = 'created_at'
    actions = ['resolve_reports', 'dismiss_reports']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: Report) -> str:
        colors = {
            'pending': '#f59e0b', 'investigating': '#3b82f6',
            'resolved': '#16a34a', 'dismissed': '#94a3b8',
        }
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.display(description='Priority', ordering='priority')
    def priority_badge(self, obj: Report) -> str:
        colors = {'low': '#94a3b8', 'medium': '#f59e0b', 'high': '#dc2626', 'critical': '#dc2626'}
        color = colors.get(obj.priority, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.priority.upper())

    @admin.display(description='Reporter')
    def reporter_email(self, obj: Report) -> str:
        return obj.reporter.email if obj.reporter else '—'

    @admin.action(description='✓ Resolve selected reports')
    def resolve_reports(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.exclude(status='resolved').update(
            status='resolved', resolved_at=timezone.now(),
        )
        self.message_user(request, f'{count} report(s) resolved.')

    @admin.action(description='✗ Dismiss selected reports')
    def dismiss_reports(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.exclude(status='dismissed').update(status='dismissed')
        self.message_user(request, f'{count} report(s) dismissed.')


@admin.register(ContentModerationQueue)
class ContentModerationQueueAdmin(admin.ModelAdmin):
    list_display = [
        'content_type', 'status_badge', 'auto_flag_score_display', 'created_at',
    ]
    list_filter = ['status', 'content_type', 'created_at']
    list_per_page = 30
    actions = ['approve_items', 'reject_items']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: ContentModerationQueue) -> str:
        colors = {'pending': '#f59e0b', 'approved': '#16a34a', 'rejected': '#dc2626', 'escalated': '#8b5cf6'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.display(description='Flag Score')
    def auto_flag_score_display(self, obj: ContentModerationQueue) -> str:
        score = obj.auto_flag_score or 0
        if score >= 0.8:
            return format_html('<span style="color:#dc2626;font-weight:700;">{:.0%}</span>', score)
        if score >= 0.5:
            return format_html('<span style="color:#f59e0b;">{:.0%}</span>', score)
        return format_html('{:.0%}', score)

    @admin.action(description='✓ Approve selected')
    def approve_items(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(status='pending').update(status='approved')
        self.message_user(request, f'{count} item(s) approved.')

    @admin.action(description='✗ Reject selected')
    def reject_items(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(status='pending').update(status='rejected')
        self.message_user(request, f'{count} item(s) rejected.')


@admin.register(UserWarning)
class UserWarningAdmin(admin.ModelAdmin):
    list_display = ['user', 'severity_badge', 'acknowledged_badge', 'reason_preview', 'created_at']
    list_filter = ['severity', 'acknowledged', 'created_at']
    search_fields = ['user__email', 'reason']
    list_per_page = 30
    actions = ['mark_acknowledged']

    @admin.display(description='Severity', ordering='severity')
    def severity_badge(self, obj: UserWarning) -> str:
        colors = {'low': '#3b82f6', 'medium': '#f59e0b', 'high': '#dc2626', 'critical': '#dc2626'}
        color = colors.get(obj.severity, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.severity.upper())

    @admin.display(description='Acknowledged', ordering='acknowledged')
    def acknowledged_badge(self, obj: UserWarning) -> str:
        if obj.acknowledged:
            return format_html('<span style="color:{};">✓ Yes</span>', '#16a34a')
        return format_html('<span style="color:{};">✗ No</span>', '#f59e0b')

    @admin.display(description='Reason')
    def reason_preview(self, obj: UserWarning) -> str:
        text = obj.reason or ''
        return text[:60] + '…' if len(text) > 60 else text

    @admin.action(description='✓ Mark as acknowledged')
    def mark_acknowledged(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(acknowledged=False).update(acknowledged=True)
        self.message_user(request, f'{count} warning(s) acknowledged.')


# ═══════════════════════════════════════════════════════════════════════════════
#  SYSTEM MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(SystemSettings)
class SystemSettingsAdmin(admin.ModelAdmin):
    list_display = ['key', 'value_preview', 'value_type', 'category', 'updated_at']
    list_filter = ['category', 'value_type']
    search_fields = ['key', 'description']
    list_editable = ['value_type']
    list_per_page = 50

    @admin.display(description='Value')
    def value_preview(self, obj: SystemSettings) -> str:
        text = str(obj.value or '')
        return text[:50] + '…' if len(text) > 50 else text


@admin.register(FeatureFlag)
class FeatureFlagAdmin(admin.ModelAdmin):
    list_display = ['key', 'name', 'enabled_badge', 'rollout_strategy', 'rollout_percentage_display', 'updated_at']
    list_filter = ['is_enabled', 'rollout_strategy']
    search_fields = ['key', 'name', 'description']
    list_per_page = 30
    actions = ['enable_flags', 'disable_flags']

    @admin.display(description='Enabled', ordering='is_enabled')
    def enabled_badge(self, obj: FeatureFlag) -> str:
        if obj.is_enabled:
            return format_html('<span style="color:{};font-weight:600;">● ON</span>', '#16a34a')
        return format_html('<span style="color:{};font-weight:600;">● OFF</span>', '#dc2626')

    @admin.display(description='Rollout %')
    def rollout_percentage_display(self, obj: FeatureFlag) -> str:
        pct = getattr(obj, 'rollout_percentage', None)
        if pct is not None:
            return f'{pct}%'
        return '—'

    @admin.action(description='✓ Enable selected flags')
    def enable_flags(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.update(is_enabled=True)
        self.message_user(request, f'{count} flag(s) enabled.')

    @admin.action(description='✗ Disable selected flags')
    def disable_flags(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.update(is_enabled=False)
        self.message_user(request, f'{count} flag(s) disabled.')


# ═══════════════════════════════════════════════════════════════════════════════
#  NOTIFICATIONS — Templates & Campaigns
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    list_display = ['name', 'channel', 'active_badge', 'created_at']
    list_filter = ['channel', 'is_active']
    search_fields = ['name']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj: NotificationTemplate) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(NotificationCampaign)
class NotificationCampaignAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'status_badge', 'target_audience',
        'total_recipients', 'sent_count_display', 'created_at',
    ]
    list_filter = ['status', 'target_audience', 'created_at']
    search_fields = ['name']
    list_per_page = 30

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: NotificationCampaign) -> str:
        colors = {
            'draft': '#94a3b8', 'scheduled': '#3b82f6',
            'sending': '#f59e0b', 'sent': '#16a34a', 'cancelled': '#dc2626',
        }
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.display(description='Sent')
    def sent_count_display(self, obj: NotificationCampaign) -> str:
        sent = getattr(obj, 'sent_count', 0) or 0
        total = obj.total_recipients or 0
        if total > 0:
            pct = round(sent / total * 100)
            return f'{sent}/{total} ({pct}%)'
        return '—'


# ═══════════════════════════════════════════════════════════════════════════════
#  ANALYTICS SNAPSHOTS
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(PlatformAnalyticsSnapshot)
class PlatformAnalyticsSnapshotAdmin(admin.ModelAdmin):
    list_display = [
        'date', 'total_users', 'daily_active_users',
        'new_users', 'completion_rate_display',
        'total_xp_earned',
    ]
    ordering = ['-date']
    list_per_page = 31
    date_hierarchy = 'date'

    @admin.display(description='Completion Rate')
    def completion_rate_display(self, obj: PlatformAnalyticsSnapshot) -> str:
        rate = obj.average_completion_rate or 0
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{:.1f}%</span>', color, rate)

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


# ═══════════════════════════════════════════════════════════════════════════════
#  AI SAFETY
# ═══════════════════════════════════════════════════════════════════════════════

@admin.register(AISafetyLog)
class AISafetyLogAdmin(admin.ModelAdmin):
    list_display = ['feature', 'status_badge', 'safety_score_display', 'user', 'created_at']
    list_filter = ['status', 'feature', 'created_at']
    search_fields = ['user__email', 'feature']
    list_per_page = 30

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: AISafetyLog) -> str:
        colors = {'safe': '#16a34a', 'flagged': '#f59e0b', 'blocked': '#dc2626'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.upper())

    @admin.display(description='Safety Score')
    def safety_score_display(self, obj: AISafetyLog) -> str:
        score = obj.safety_score or 0
        if score >= 0.8:
            return format_html('<span style="color:#16a34a;font-weight:600;">{:.0%}</span>', score)
        if score >= 0.5:
            return format_html('<span style="color:#f59e0b;">{:.0%}</span>', score)
        return format_html('<span style="color:#dc2626;font-weight:700;">{:.0%}</span>', score)


@admin.register(AIUserRestriction)
class AIUserRestrictionAdmin(admin.ModelAdmin):
    list_display = ['user', 'feature', 'disabled_badge', 'created_at']
    list_filter = ['feature', 'is_disabled', 'created_at']
    search_fields = ['user__email']
    actions = ['lift_restrictions']

    @admin.display(description='Disabled', ordering='is_disabled')
    def disabled_badge(self, obj: AIUserRestriction) -> str:
        if obj.is_disabled:
            return format_html('<span style="color:{};font-weight:600;">🚫 Disabled</span>', '#dc2626')
        return format_html('<span style="color:{};">✓ Enabled</span>', '#16a34a')

    @admin.action(description='✓ Lift selected restrictions')
    def lift_restrictions(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(is_disabled=True).update(is_disabled=False)
        self.message_user(request, f'{count} restriction(s) lifted.')
