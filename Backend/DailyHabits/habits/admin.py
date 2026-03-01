"""
Habits Admin — Production-Grade Django Admin for the Habits App
================================================================

Rich admin interface with inline models, computed analytics columns,
bulk actions, coloured status badges, and chart-ready data.

Registered models:
    Category, Habit, HabitLog, Streak, HabitCompletion
"""

from django.contrib import admin
from django.db.models import QuerySet
from django.http import HttpRequest
from django.utils import timezone
from django.utils.html import format_html

from .models import Category, Habit, HabitLog, Streak, HabitCompletion


# ─── Inlines ──────────────────────────────────────────────────────────────────

class HabitLogInline(admin.TabularInline):
    model = HabitLog
    extra = 0
    max_num = 14
    readonly_fields = ('date', 'status', 'count', 'completed_at', 'notes')
    can_delete = False
    ordering = ['-date']
    verbose_name_plural = 'Recent Logs (last 14)'

    def has_add_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


class StreakInline(admin.StackedInline):
    model = Streak
    extra = 0
    max_num = 1
    readonly_fields = (
        'current_streak', 'best_streak', 'total_completions',
        'last_completed_date', 'streak_start_date',
    )
    can_delete = False

    def has_add_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


# =============================================================================
# Category Admin
# =============================================================================

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'is_default', 'habit_count', 'created_at']
    search_fields = ['name']
    list_filter = ['is_default']

    @admin.display(description='Habits')
    def habit_count(self, obj: Category) -> int:
        return Habit.objects.filter(category_name=obj.name, is_deleted=False).count()


# =============================================================================
# Habit Admin
# =============================================================================

@admin.register(Habit)
class HabitAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'user_email', 'category_name', 'frequency',
        'status_badge', 'deleted_badge', 'completion_rate',
        'streak_display', 'created_at',
    ]
    list_display_links = ['title']
    list_filter = ['status', 'frequency', 'is_deleted', 'category_name', 'created_at']
    search_fields = ['title', 'user__email', 'description']
    ordering = ['-created_at']
    readonly_fields = ['created_at', 'updated_at', 'deleted_at']
    list_per_page = 30
    date_hierarchy = 'created_at'
    inlines = [StreakInline, HabitLogInline]
    actions = ['soft_delete_habits', 'restore_habits']

    fieldsets = (
        ('Habit Details', {
            'fields': ('title', 'description', 'user', 'category_name', 'frequency', 'target_count'),
        }),
        ('Status', {
            'fields': ('status', 'is_deleted', 'deleted_at'),
        }),
        ('Schedule', {
            'fields': ('reminder_time', 'start_date', 'end_date'),
            'classes': ('collapse',),
        }),
        ('Audit', {
            'fields': ('created_at', 'updated_at'),
        }),
    )

    @admin.display(description='User', ordering='user__email')
    def user_email(self, obj: Habit) -> str:
        return obj.user.email

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: Habit) -> str:
        colors = {'active': '#16a34a', 'paused': '#f59e0b', 'archived': '#94a3b8', 'completed': '#3b82f6'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.display(description='Deleted', ordering='is_deleted')
    def deleted_badge(self, obj: Habit) -> str:
        if obj.is_deleted:
            return format_html('<span style="color:{};">✗ Yes</span>', '#dc2626')
        return format_html('<span style="color:{};">—</span>', '#16a34a')

    @admin.display(description='Completion %')
    def completion_rate(self, obj: Habit) -> str:
        total = HabitLog.objects.filter(habit=obj).count()
        if not total:
            return '—'
        completed = HabitLog.objects.filter(habit=obj, status='completed').count()
        rate = round(completed / total * 100, 1)
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{}%</span>', color, rate)

    @admin.display(description='Streak')
    def streak_display(self, obj: Habit) -> str:
        try:
            streak = Streak.objects.get(habit=obj)
            if streak.current_streak > 0:
                return format_html(
                    '<span style="color:#f59e0b;">🔥 {} days</span>',
                    streak.current_streak,
                )
            return '0'
        except Streak.DoesNotExist:
            return '—'

    @admin.action(description='🗑 Soft delete selected habits')
    def soft_delete_habits(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(is_deleted=False).update(
            is_deleted=True, deleted_at=timezone.now(), status='archived',
        )
        self.message_user(request, f'{count} habit(s) soft-deleted.')

    @admin.action(description='♻ Restore selected habits')
    def restore_habits(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(is_deleted=True).update(
            is_deleted=False, deleted_at=None, status='active',
        )
        self.message_user(request, f'{count} habit(s) restored.')


# =============================================================================
# HabitLog Admin
# =============================================================================

@admin.register(HabitLog)
class HabitLogAdmin(admin.ModelAdmin):
    list_display = ['habit_title', 'user_email', 'date', 'status_badge', 'count', 'completed_at']
    list_filter = ['status', 'date']
    search_fields = ['habit__title', 'habit__user__email']
    ordering = ['-date', '-completed_at']
    list_per_page = 50
    date_hierarchy = 'date'
    readonly_fields = ('habit', 'date', 'status', 'count', 'completed_at', 'notes')

    @admin.display(description='Habit', ordering='habit__title')
    def habit_title(self, obj: HabitLog) -> str:
        return obj.habit.title

    @admin.display(description='User')
    def user_email(self, obj: HabitLog) -> str:
        return obj.habit.user.email

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: HabitLog) -> str:
        colors = {'completed': '#16a34a', 'skipped': '#f59e0b', 'missed': '#dc2626'}
        color = colors.get(obj.status, '#94a3b8')
        icon = {'completed': '✓', 'skipped': '⏭', 'missed': '✗'}.get(obj.status, '?')
        return format_html('<span style="color:{};font-weight:600;">{} {}</span>', color, icon, obj.status.capitalize())

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


# =============================================================================
# Streak Admin
# =============================================================================

@admin.register(Streak)
class StreakAdmin(admin.ModelAdmin):
    list_display = [
        'habit_title', 'user_email', 'current_streak_display',
        'best_streak', 'total_completions', 'last_completed_date',
    ]
    search_fields = ['habit__title', 'habit__user__email']
    ordering = ['-current_streak']
    list_per_page = 30
    list_filter = ['last_completed_date']

    @admin.display(description='Habit', ordering='habit__title')
    def habit_title(self, obj: Streak) -> str:
        return obj.habit.title

    @admin.display(description='User')
    def user_email(self, obj: Streak) -> str:
        return obj.habit.user.email

    @admin.display(description='Current Streak', ordering='current_streak')
    def current_streak_display(self, obj: Streak) -> str:
        if obj.current_streak >= 30:
            return format_html('<span style="color:#f59e0b;font-weight:700;">🔥 {} days</span>', obj.current_streak)
        if obj.current_streak >= 7:
            return format_html('<span style="color:#16a34a;font-weight:600;">{} days</span>', obj.current_streak)
        if obj.current_streak > 0:
            return f'{obj.current_streak} days'
        return format_html('<span style="color:{};">0</span>', '#94a3b8')


# =============================================================================
# HabitCompletion Admin (Legacy)
# =============================================================================

@admin.register(HabitCompletion)
class HabitCompletionAdmin(admin.ModelAdmin):
    list_display = ['habit', 'date', 'completed_at']
    list_filter = ['date']
    ordering = ['-date']
    list_per_page = 50
