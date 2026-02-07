"""
Achievements Admin
"""

from django.contrib import admin
from .models import Achievement, UserAchievement, UserLevel, Reward, UserReward


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ['name', 'achievement_type', 'rarity', 'points', 'target_value', 'is_active']
    list_filter = ['achievement_type', 'rarity', 'is_active']
    search_fields = ['name', 'description']
    ordering = ['order', 'level_required']


@admin.register(UserAchievement)
class UserAchievementAdmin(admin.ModelAdmin):
    list_display = ['user', 'achievement', 'earned_at', 'earned_value']
    list_filter = ['earned_at']
    search_fields = ['user__email', 'achievement__name']
    ordering = ['-earned_at']


@admin.register(UserLevel)
class UserLevelAdmin(admin.ModelAdmin):
    list_display = ['user', 'current_level', 'current_xp', 'total_xp', 'total_achievements']
    search_fields = ['user__email']
    ordering = ['-current_level', '-total_xp']


@admin.register(Reward)
class RewardAdmin(admin.ModelAdmin):
    list_display = ['name', 'reward_type', 'level_required', 'points_required', 'is_active']
    list_filter = ['reward_type', 'is_active']


@admin.register(UserReward)
class UserRewardAdmin(admin.ModelAdmin):
    list_display = ['user', 'reward', 'unlocked_at', 'is_active']
    list_filter = ['is_active']
