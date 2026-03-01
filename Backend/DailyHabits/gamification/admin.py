"""
Gamification Admin — Production-Grade Admin for XP, Challenges, Leaderboards
=============================================================================
"""

from django.contrib import admin
from django.db.models import QuerySet
from django.http import HttpRequest
from django.utils.html import format_html

from .models import (
    XPEvent, StreakFreeze, Challenge, ChallengeParticipant,
    LeaderboardEntry, VirtualCurrency, CurrencyTransaction,
    DailyBonus, MilestoneReward,
)


@admin.register(XPEvent)
class XPEventAdmin(admin.ModelAdmin):
    list_display = ['user', 'amount_display', 'source_type', 'description', 'created_at']
    list_filter = ['source_type', 'created_at']
    search_fields = ['user__email', 'description']
    readonly_fields = [
        'user', 'amount', 'source_type', 'source_id', 'description',
        'multiplier', 'base_amount', 'created_at',
    ]
    list_per_page = 50
    date_hierarchy = 'created_at'

    @admin.display(description='XP', ordering='amount')
    def amount_display(self, obj: XPEvent) -> str:
        return format_html('<span style="color:#6366f1;font-weight:700;">+{}</span>', obj.amount)

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj=None) -> bool:
        return False


@admin.register(StreakFreeze)
class StreakFreezeAdmin(admin.ModelAdmin):
    list_display = ['user', 'status_badge', 'cost_coins', 'purchased_at', 'used_at', 'expires_at']
    list_filter = ['status']
    search_fields = ['user__email']
    list_per_page = 30

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: StreakFreeze) -> str:
        colors = {'available': '#16a34a', 'used': '#3b82f6', 'expired': '#94a3b8'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())


@admin.register(Challenge)
class ChallengeAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'scope', 'status_badge', 'difficulty_badge',
        'xp_reward', 'participant_count', 'start_date', 'end_date',
    ]
    list_filter = ['scope', 'status', 'difficulty', 'is_featured']
    search_fields = ['title', 'description']
    list_per_page = 30
    actions = ['activate_challenges', 'end_challenges']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: Challenge) -> str:
        colors = {'draft': '#94a3b8', 'active': '#16a34a', 'completed': '#3b82f6', 'cancelled': '#dc2626'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())

    @admin.display(description='Difficulty')
    def difficulty_badge(self, obj: Challenge) -> str:
        colors = {'easy': '#16a34a', 'medium': '#f59e0b', 'hard': '#dc2626', 'expert': '#8b5cf6'}
        color = colors.get(obj.difficulty, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.difficulty.capitalize())

    @admin.display(description='Participants')
    def participant_count(self, obj: Challenge) -> int:
        return ChallengeParticipant.objects.filter(challenge=obj).count()

    @admin.action(description='▶ Activate selected')
    def activate_challenges(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(status='draft').update(status='active')
        self.message_user(request, f'{count} challenge(s) activated.')

    @admin.action(description='⏹ End selected')
    def end_challenges(self, request: HttpRequest, queryset: QuerySet) -> None:
        count = queryset.filter(status='active').update(status='completed')
        self.message_user(request, f'{count} challenge(s) ended.')


@admin.register(ChallengeParticipant)
class ChallengeParticipantAdmin(admin.ModelAdmin):
    list_display = ['user', 'challenge', 'status_badge', 'progress', 'progress_percentage']
    list_filter = ['status']
    search_fields = ['user__email', 'challenge__title']

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj: ChallengeParticipant) -> str:
        colors = {'active': '#16a34a', 'completed': '#3b82f6', 'failed': '#dc2626', 'withdrawn': '#94a3b8'}
        color = colors.get(obj.status, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.status.capitalize())


@admin.register(LeaderboardEntry)
class LeaderboardEntryAdmin(admin.ModelAdmin):
    list_display = ['rank_display', 'user', 'board_type', 'score', 'completions', 'period_start']
    list_filter = ['board_type']
    ordering = ['board_type', 'rank']
    list_per_page = 50

    @admin.display(description='Rank', ordering='rank')
    def rank_display(self, obj: LeaderboardEntry) -> str:
        if obj.rank == 1:
            return format_html('<span style="color:#f59e0b;font-weight:700;">🥇 #{}</span>', obj.rank)
        if obj.rank == 2:
            return format_html('<span style="color:#94a3b8;font-weight:700;">🥈 #{}</span>', obj.rank)
        if obj.rank == 3:
            return format_html('<span style="color:#b45309;font-weight:700;">🥉 #{}</span>', obj.rank)
        return f'#{obj.rank}'


@admin.register(VirtualCurrency)
class VirtualCurrencyAdmin(admin.ModelAdmin):
    list_display = ['user', 'balance_display', 'total_earned', 'total_spent']
    search_fields = ['user__email']
    list_per_page = 30

    @admin.display(description='Balance', ordering='balance')
    def balance_display(self, obj: VirtualCurrency) -> str:
        return format_html('<span style="color:#f59e0b;font-weight:700;">🪙 {}</span>', obj.balance)


@admin.register(CurrencyTransaction)
class CurrencyTransactionAdmin(admin.ModelAdmin):
    list_display = ['user', 'amount_display', 'transaction_type', 'reason', 'created_at']
    list_filter = ['transaction_type', 'source']
    search_fields = ['user__email', 'reason']
    list_per_page = 50

    @admin.display(description='Amount', ordering='amount')
    def amount_display(self, obj: CurrencyTransaction) -> str:
        if obj.amount > 0:
            return format_html('<span style="color:#16a34a;font-weight:600;">+{}</span>', obj.amount)
        return format_html('<span style="color:#dc2626;font-weight:600;">{}</span>', obj.amount)


@admin.register(DailyBonus)
class DailyBonusAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'login_bonus_claimed', 'all_done_bonus_claimed', 'xp_earned', 'coins_earned']
    list_filter = ['login_bonus_claimed', 'all_done_bonus_claimed', 'date']
    list_per_page = 50


@admin.register(MilestoneReward)
class MilestoneRewardAdmin(admin.ModelAdmin):
    list_display = ['title', 'milestone_type', 'threshold', 'xp_reward', 'coin_reward', 'active_badge']
    list_filter = ['milestone_type', 'is_active']
    search_fields = ['title']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj: MilestoneReward) -> str:
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')
