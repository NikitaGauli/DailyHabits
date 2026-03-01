"""
Grow Together Admin — Production-Grade Admin for Collaborative Habits
=====================================================================
"""

from django.contrib import admin
from django.db.models import QuerySet
from django.http import HttpRequest
from django.utils.html import format_html

from .models import (
    CollaborativeHabit,
    CollaborativeHabitMember,
    CollaborativeHabitProgress,
    HabitInvite,
    HabitActivityLog,
    ProgressReaction,
    ProgressComment,
    WeeklyLeaderboard,
    GroupMilestone,
    AbuseReport,
)


# ─── Inlines ──────────────────────────────────────────────────────────────────

class CollaborativeHabitMemberInline(admin.TabularInline):
    model = CollaborativeHabitMember
    extra = 0
    readonly_fields = ('user', 'role', 'current_streak', 'total_xp_earned', 'joined_at', 'is_active')
    can_delete = False

    def has_add_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


@admin.register(CollaborativeHabit)
class CollaborativeHabitAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'owner', 'frequency', 'privacy', 'member_count',
        'active_badge', 'created_at',
    )
    list_filter = ('frequency', 'privacy', 'is_active', 'created_at')
    search_fields = ('title', 'owner__email')
    readonly_fields = ('id', 'created_at', 'updated_at')
    list_per_page = 30
    inlines = [CollaborativeHabitMemberInline]

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj: CollaborativeHabit) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};font-weight:600;">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(CollaborativeHabitMember)
class CollaborativeHabitMemberAdmin(admin.ModelAdmin):
    list_display = (
        'user', 'collaborative_habit', 'role_badge', 'current_streak',
        'total_xp_earned', 'active_badge',
    )
    list_filter = ('role', 'is_active')
    search_fields = ('user__email', 'collaborative_habit__title')
    readonly_fields = ('id', 'joined_at')

    @admin.display(description='Role')
    def role_badge(self, obj: CollaborativeHabitMember) -> str:
        colors = {'owner': '#6366f1', 'admin': '#3b82f6', 'member': '#94a3b8'}
        color = colors.get(obj.role, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.role.capitalize())

    @admin.display(description='Active')
    def active_badge(self, obj: CollaborativeHabitMember) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Left</span>', '#dc2626')


@admin.register(CollaborativeHabitProgress)
class CollaborativeHabitProgressAdmin(admin.ModelAdmin):
    list_display = ('member', 'collaborative_habit', 'date', 'completed_badge', 'completion_count', 'xp_earned')
    list_filter = ('completed', 'date')
    readonly_fields = ('id', 'completed_at')
    list_per_page = 50

    @admin.display(description='Done', ordering='completed')
    def completed_badge(self, obj: CollaborativeHabitProgress) -> str:
        if obj.completed:
            return format_html('<span style="color:{};">✓</span>', '#16a34a')
        return format_html('<span style="color:{};">✗</span>', '#dc2626')


@admin.register(HabitInvite)
class HabitInviteAdmin(admin.ModelAdmin):
    list_display = ('collaborative_habit', 'invited_by', 'invited_user', 'status_badge', 'created_at', 'expires_at')
    list_filter = ('status',)
    readonly_fields = ('id', 'created_at')

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: HabitInvite) -> str:
        colors = {'pending': '#f59e0b', 'accepted': '#16a34a', 'declined': '#dc2626', 'expired': '#94a3b8'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())


@admin.register(HabitActivityLog)
class HabitActivityLogAdmin(admin.ModelAdmin):
    list_display = ('collaborative_habit', 'actor', 'action', 'created_at')
    list_filter = ('action', 'created_at')
    readonly_fields = ('id', 'created_at')
    list_per_page = 50


@admin.register(ProgressReaction)
class ProgressReactionAdmin(admin.ModelAdmin):
    list_display = ('user', 'progress', 'reaction_type', 'created_at')
    list_filter = ('reaction_type',)
    readonly_fields = ('id', 'created_at')


@admin.register(ProgressComment)
class ProgressCommentAdmin(admin.ModelAdmin):
    list_display = ('author', 'progress', 'content_preview', 'created_at')
    readonly_fields = ('id', 'created_at')
    search_fields = ('author__email', 'content')

    @admin.display(description='Content')
    def content_preview(self, obj: ProgressComment) -> str:
        return obj.content[:60] + '…' if len(obj.content) > 60 else obj.content


@admin.register(WeeklyLeaderboard)
class WeeklyLeaderboardAdmin(admin.ModelAdmin):
    list_display = ('collaborative_habit', 'user', 'rank_display', 'xp_earned', 'week_start')
    list_filter = ('week_start',)
    readonly_fields = ('id',)
    list_per_page = 50

    @admin.display(description='Rank', ordering='rank')
    def rank_display(self, obj: WeeklyLeaderboard) -> str:
        if obj.rank == 1:
            return format_html('<span style="color:#f59e0b;font-weight:700;">🥇 #{}</span>', obj.rank)
        if obj.rank <= 3:
            return format_html('<span style="font-weight:600;">#{}</span>', obj.rank)
        return f'#{obj.rank}'


@admin.register(GroupMilestone)
class GroupMilestoneAdmin(admin.ModelAdmin):
    list_display = ('collaborative_habit', 'milestone_type', 'achieved_badge', 'achieved_at')
    list_filter = ('milestone_type', 'achieved')
    readonly_fields = ('id', 'created_at')

    @admin.display(description='Achieved', ordering='achieved')
    def achieved_badge(self, obj: GroupMilestone) -> str:
        if obj.achieved:
            return format_html('<span style="color:{};font-weight:600;">✓ Yes</span>', '#16a34a')
        return format_html('<span style="color:{};">Not yet</span>', '#94a3b8')


@admin.register(AbuseReport)
class AbuseReportAdmin(admin.ModelAdmin):
    list_display = (
        'collaborative_habit', 'reporter', 'reported_user',
        'reason', 'status_badge', 'created_at',
    )
    list_filter = ('reason', 'status', 'created_at')
    readonly_fields = ('id', 'created_at')
    search_fields = ('reporter__email', 'reported_user__email')
    actions = ['resolve_reports', 'dismiss_reports']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: AbuseReport) -> str:
        colors = {'pending': '#f59e0b', 'investigating': '#3b82f6', 'resolved': '#16a34a', 'dismissed': '#94a3b8'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.action(description='✓ Resolve selected')
    def resolve_reports(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.exclude(status='resolved').update(status='resolved')
        self.message_user(request, f'{count} report(s) resolved.')

    @admin.action(description='✗ Dismiss selected')
    def dismiss_reports(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.exclude(status='dismissed').update(status='dismissed')
        self.message_user(request, f'{count} report(s) dismissed.')
