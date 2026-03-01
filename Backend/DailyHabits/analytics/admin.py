from django.contrib import admin
from django.utils.html import format_html

from .models import DailySummary, WeeklySummary, MonthlySummary, HabitAnalytics


@admin.register(DailySummary)
class DailySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'total_habits', 'completed_count', 'rate_display']
    list_filter = ['date']
    search_fields = ['user__email']
    ordering = ['-date']
    list_per_page = 50
    date_hierarchy = 'date'

    @admin.display(description='Completion Rate')
    def rate_display(self, obj):
        rate = obj.completion_rate or 0
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{:.0f}%</span>', color, rate)


@admin.register(WeeklySummary)
class WeeklySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'week_start', 'week_number', 'year', 'total_completions']
    list_filter = ['year', 'week_number']
    ordering = ['-week_start']
    list_per_page = 50
    search_fields = ['user__email']


@admin.register(MonthlySummary)
class MonthlySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'year', 'month', 'total_completions', 'rate_display']
    list_filter = ['year', 'month']
    ordering = ['-year', '-month']
    list_per_page = 50
    search_fields = ['user__email']

    @admin.display(description='Avg Completion Rate')
    def rate_display(self, obj):
        rate = obj.average_completion_rate or 0
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{:.0f}%</span>', color, rate)


@admin.register(HabitAnalytics)
class HabitAnalyticsAdmin(admin.ModelAdmin):
    list_display = ['habit', 'total_completions', 'rate_display', 'trend_badge']
    list_filter = ['trend_direction']
    search_fields = ['habit__title', 'habit__user__email']

    @admin.display(description='Completion Rate')
    def rate_display(self, obj):
        rate = obj.lifetime_completion_rate or 0
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{:.0f}%</span>', color, rate)

    @admin.display(description='Trend', ordering='trend_direction')
    def trend_badge(self, obj):
        icons = {'up': '↑', 'down': '↓', 'stable': '→'}
        colors = {'up': '#16a34a', 'down': '#dc2626', 'stable': '#f59e0b'}
        icon = icons.get(obj.trend_direction, '?')
        color = colors.get(obj.trend_direction, '#94a3b8')
        return format_html('<span style="color:{};font-weight:700;font-size:1.2em;">{}</span>', color, icon)
