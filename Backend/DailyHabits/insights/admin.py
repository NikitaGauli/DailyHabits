from django.contrib import admin
from django.utils.html import format_html

from .models import MotivationalQuote, UserInsight, InsightTemplate, UserPreferences


@admin.register(MotivationalQuote)
class MotivationalQuoteAdmin(admin.ModelAdmin):
    list_display = ['quote_preview', 'author', 'category', 'times_shown', 'active_badge']
    list_filter = ['category', 'is_active', 'language']
    search_fields = ['quote', 'author']
    ordering = ['-times_shown']
    list_per_page = 30

    @admin.display(description='Quote')
    def quote_preview(self, obj):
        text = obj.quote or ''
        return text[:80] + '…' if len(text) > 80 else text

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(UserInsight)
class UserInsightAdmin(admin.ModelAdmin):
    list_display = ['user', 'insight_type', 'title', 'priority_badge', 'read_badge', 'created_at']
    list_filter = ['insight_type', 'priority', 'is_read', 'created_at']
    search_fields = ['user__email', 'title', 'message']
    ordering = ['-created_at']
    list_per_page = 50
    date_hierarchy = 'created_at'

    @admin.display(description='Priority', ordering='priority')
    def priority_badge(self, obj):
        colors = {'low': '#94a3b8', 'medium': '#f59e0b', 'high': '#dc2626'}
        color = colors.get(obj.priority, '#94a3b8')
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.priority.upper())

    @admin.display(description='Read', ordering='is_read')
    def read_badge(self, obj):
        if obj.is_read:
            return format_html('<span style="color:{};">✓</span>', '#16a34a')
        return format_html('<span style="color:{};">●</span>', '#f59e0b')


@admin.register(InsightTemplate)
class InsightTemplateAdmin(admin.ModelAdmin):
    list_display = ['insight_type', 'title_template', 'active_badge']
    list_filter = ['is_active']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(UserPreferences)
class UserPreferencesAdmin(admin.ModelAdmin):
    list_display = ['user', 'theme', 'language', 'smart_insights_enabled', 'gamification_enabled']
    list_filter = ['theme', 'language']
    search_fields = ['user__email']
