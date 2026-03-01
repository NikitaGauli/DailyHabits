"""
=============================================================================
 Authentication — Django Admin Configuration
=============================================================================

 Module:  authentication/admin.py
 Project: DailyHabits Backend

 Purpose:
   Production-grade admin for User, LoginActivity and DataDeletionRequest.
   Includes rich list displays, inline models, custom actions, computed
   fields, and search/filter support for efficient platform management.
=============================================================================
"""

from datetime import timedelta

from django.contrib import admin
from django.db.models import Count, QuerySet
from django.http import HttpRequest
from django.utils import timezone
from django.utils.html import format_html

from .models import User, LoginActivity, DataDeletionRequest, PasswordResetToken


# ─── Inline Models ────────────────────────────────────────────────────────────

class LoginActivityInline(admin.TabularInline):
    model = LoginActivity
    extra = 0
    max_num = 10
    readonly_fields = ('ip_address', 'user_agent', 'device_type', 'location', 'login_at', 'was_successful')
    can_delete = False
    verbose_name_plural = 'Recent Login Activity'
    ordering = ['-login_at']

    def has_add_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


class DataDeletionRequestInline(admin.TabularInline):
    model = DataDeletionRequest
    extra = 0
    readonly_fields = ('reason', 'status', 'requested_at', 'processed_at')
    can_delete = False


# =============================================================================
#  USER ADMIN
# =============================================================================

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    """Enhanced admin for managing user accounts with insights and quick actions."""

    list_display = (
        'email', 'name', 'is_active_badge', 'is_staff_badge',
        'current_streak', 'total_habits_completed',
        'last_login_display', 'created_at',
    )
    list_display_links = ('email', 'name')
    list_filter = ('is_active', 'is_staff', 'is_superuser', 'created_at')
    search_fields = ('email', 'name')
    ordering = ['-created_at']
    readonly_fields = (
        'created_at', 'updated_at', 'last_login',
        'habit_count_display', 'login_count_display', 'account_age_display',
    )
    list_per_page = 30
    date_hierarchy = 'created_at'
    inlines = [LoginActivityInline, DataDeletionRequestInline]

    fieldsets = (
        ('Identity', {
            'fields': ('email', 'name', 'profile_image'),
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
            'classes': ('collapse',),
        }),
        ('Habit Stats', {
            'fields': ('current_streak', 'total_habits_completed', 'habit_count_display'),
        }),
        ('Audit', {
            'fields': ('last_login', 'created_at', 'updated_at', 'login_count_display', 'account_age_display'),
        }),
    )

    actions = ['activate_users', 'deactivate_users', 'promote_to_staff']

    # ── Computed display columns ──────────────────────────────────────

    @admin.display(description='Active', ordering='is_active')
    def is_active_badge(self, obj: User) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};font-weight:600;">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};font-weight:600;">● Inactive</span>', '#dc2626')

    @admin.display(description='Staff', ordering='is_staff')
    def is_staff_badge(self, obj: User) -> str:
        if obj.is_staff:
            return format_html('<span style="color:{};font-weight:600;">✓ Staff</span>', '#6366f1')
        return format_html('<span style="color:{};">—</span>', '#94a3b8')

    @admin.display(description='Last Login', ordering='last_login')
    def last_login_display(self, obj: User) -> str:
        if not obj.last_login:
            return format_html('<span style="color:{};">Never</span>', '#94a3b8')
        delta = timezone.now() - obj.last_login
        if delta < timedelta(hours=1):
            return format_html('<span style="color:#16a34a;">{}m ago</span>', int(delta.total_seconds() / 60))
        if delta < timedelta(days=1):
            return format_html('<span style="color:#3b82f6;">{}h ago</span>', int(delta.total_seconds() / 3600))
        if delta < timedelta(days=7):
            return format_html('<span style="color:#f59e0b;">{}d ago</span>', delta.days)
        return format_html('<span style="color:#dc2626;">{}d ago</span>', delta.days)

    @admin.display(description='Total Habits')
    def habit_count_display(self, obj: User) -> int:
        from habits.models import Habit
        return Habit.objects.filter(user=obj, is_deleted=False).count()

    @admin.display(description='Login Count')
    def login_count_display(self, obj: User) -> int:
        return LoginActivity.objects.filter(user=obj, was_successful=True).count()

    @admin.display(description='Account Age')
    def account_age_display(self, obj: User) -> str:
        if not obj.created_at:
            return '—'
        delta = timezone.now() - obj.created_at
        if delta.days > 365:
            return f'{delta.days // 365}y {(delta.days % 365) // 30}m'
        if delta.days > 30:
            return f'{delta.days // 30}m {delta.days % 30}d'
        return f'{delta.days}d'

    # ── Bulk actions ──────────────────────────────────────────────────

    @admin.action(description='✓ Activate selected users')
    def activate_users(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.update(is_active=True)
        self.message_user(request, f'{count} user(s) activated.')

    @admin.action(description='✗ Deactivate selected users')
    def deactivate_users(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.update(is_active=False)
        self.message_user(request, f'{count} user(s) deactivated.')

    @admin.action(description='↑ Promote to staff')
    def promote_to_staff(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.update(is_staff=True)
        self.message_user(request, f'{count} user(s) promoted to staff.')

    def get_queryset(self, request: HttpRequest) -> QuerySet:
        return super().get_queryset(request).annotate(
            _login_count=Count('login_activities'),
        )


# =============================================================================
#  LOGIN ACTIVITY ADMIN
# =============================================================================

@admin.register(LoginActivity)
class LoginActivityAdmin(admin.ModelAdmin):
    """Read-only audit log of login attempts — filterable by status and device."""

    list_display = ('user', 'ip_address', 'device_type', 'status_badge', 'location', 'login_at')
    list_filter = ('was_successful', 'device_type', 'login_at')
    search_fields = ('user__email', 'ip_address', 'location')
    readonly_fields = ('user', 'ip_address', 'user_agent', 'device_type', 'location', 'login_at', 'was_successful')
    list_per_page = 50
    date_hierarchy = 'login_at'

    @admin.display(description='Status', ordering='was_successful')
    def status_badge(self, obj: LoginActivity) -> str:
        if obj.was_successful:
            return format_html('<span style="color:{};font-weight:600;">✓ Success</span>', '#16a34a')
        return format_html('<span style="color:{};font-weight:600;">✗ Failed</span>', '#dc2626')

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


# =============================================================================
#  DATA DELETION REQUEST ADMIN
# =============================================================================

@admin.register(DataDeletionRequest)
class DataDeletionRequestAdmin(admin.ModelAdmin):
    """Admin interface for reviewing and processing GDPR deletion requests."""

    list_display = ('user', 'status_badge', 'requested_at', 'processed_at', 'days_pending')
    list_filter = ('status', 'requested_at')
    search_fields = ('user__email', 'reason')
    readonly_fields = ('user', 'reason', 'requested_at')
    list_per_page = 30
    actions = ['mark_processing', 'mark_completed']

    @admin.display(description='Status')
    def status_badge(self, obj: DataDeletionRequest) -> str:
        colors = {
            'pending': '#f59e0b', 'processing': '#3b82f6',
            'completed': '#16a34a', 'cancelled': '#94a3b8',
        }
        color = colors.get(obj.status, '#94a3b8')
        return format_html(
            '<span style="color:{};font-weight:600;">{}</span>',
            color, obj.get_status_display(),  # type: ignore[attr-defined]
        )

    @admin.display(description='Days Pending')
    def days_pending(self, obj: DataDeletionRequest) -> str:
        if obj.status in ('completed', 'cancelled'):
            return '—'
        delta = timezone.now() - obj.requested_at
        days = delta.days
        if days > 25:
            return format_html('<span style="color:#dc2626;font-weight:700;">⚠ {} days</span>', days)
        if days > 14:
            return format_html('<span style="color:#f59e0b;">{} days</span>', days)
        return f'{days} days'

    @admin.action(description='Mark as Processing')
    def mark_processing(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(status='pending').update(status='processing')
        self.message_user(request, f'{count} request(s) marked as processing.')

    @admin.action(description='Mark as Completed')
    def mark_completed(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.exclude(status='completed').update(
            status='completed', processed_at=timezone.now(),
        )
        self.message_user(request, f'{count} request(s) completed.')


# =============================================================================
#  PASSWORD RESET TOKEN ADMIN
# =============================================================================

@admin.register(PasswordResetToken)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    """Read-only view of password reset tokens for security auditing."""

    list_display = ('user', 'is_used', 'created_at', 'expires_at', 'ip_address')
    list_filter = ('is_used', 'created_at')
    search_fields = ('user__email',)
    readonly_fields = (
        'user', 'token_hash', 'is_used', 'created_at', 'expires_at',
        'ip_address', 'user_agent',
    )
    list_per_page = 30

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False
