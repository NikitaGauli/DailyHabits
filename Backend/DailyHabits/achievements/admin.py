from django.contrib import admin
from django.utils.html import format_html

from .models import Achievement, UserAchievement, UserLevel, Reward, UserReward


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ['name', 'achievement_type', 'rarity_badge', 'points', 'target_value', 'active_badge']
    list_filter = ['achievement_type', 'rarity', 'is_active']
    search_fields = ['name', 'description']
    ordering = ['order', 'level_required']
    list_per_page = 30

    @admin.display(description='Rarity', ordering='rarity')
    def rarity_badge(self, obj):
        colors = {'common': '#94a3b8', 'uncommon': '#16a34a', 'rare': '#3b82f6', 'epic': '#8b5cf6', 'legendary': '#f59e0b'}
        color = colors.get(obj.rarity, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.rarity.capitalize())

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(UserAchievement)
class UserAchievementAdmin(admin.ModelAdmin):
    list_display = ['user', 'achievement', 'earned_at', 'earned_value']
    list_filter = ['earned_at']
    search_fields = ['user__email', 'achievement__name']
    ordering = ['-earned_at']
    list_per_page = 50
    date_hierarchy = 'earned_at'


@admin.register(UserLevel)
class UserLevelAdmin(admin.ModelAdmin):
    list_display = ['user', 'level_display', 'current_xp', 'total_xp', 'total_achievements']
    search_fields = ['user__email']
    ordering = ['-current_level', '-total_xp']
    list_per_page = 30

    @admin.display(description='Level', ordering='current_level')
    def level_display(self, obj):
        return format_html('<span style="color:#6366f1;font-weight:700;">Lv. {}</span>', obj.current_level)


@admin.register(Reward)
class RewardAdmin(admin.ModelAdmin):
    list_display = ['name', 'reward_type', 'level_required', 'points_required', 'active_badge']
    list_filter = ['reward_type', 'is_active']
    search_fields = ['name']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(UserReward)
class UserRewardAdmin(admin.ModelAdmin):
    list_display = ['user', 'reward', 'unlocked_at', 'active_badge']
    list_filter = ['is_active']
    search_fields = ['user__email', 'reward__name']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')
