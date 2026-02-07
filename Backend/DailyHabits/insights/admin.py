"""
Insights Admin
"""

from django.contrib import admin
from .models import MotivationalQuote, UserInsight, InsightTemplate, UserPreferences


@admin.register(MotivationalQuote)
class MotivationalQuoteAdmin(admin.ModelAdmin):
    list_display = ['quote', 'author', 'category', 'times_shown', 'is_active']
    list_filter = ['category', 'is_active', 'language']
    search_fields = ['quote', 'author']
    ordering = ['-times_shown']


@admin.register(UserInsight)
class UserInsightAdmin(admin.ModelAdmin):
    list_display = ['user', 'insight_type', 'title', 'priority', 'is_read', 'created_at']
    list_filter = ['insight_type', 'priority', 'is_read']
    search_fields = ['user__email', 'title', 'message']
    ordering = ['-created_at']


@admin.register(InsightTemplate)
class InsightTemplateAdmin(admin.ModelAdmin):
    list_display = ['insight_type', 'title_template', 'is_active']
    list_filter = ['is_active']


@admin.register(UserPreferences)
class UserPreferencesAdmin(admin.ModelAdmin):
    list_display = ['user', 'theme', 'language', 'smart_insights_enabled', 'gamification_enabled']
    list_filter = ['theme', 'language']
    search_fields = ['user__email']
