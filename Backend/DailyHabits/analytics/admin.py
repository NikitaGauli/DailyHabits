"""
Analytics Admin
"""

from django.contrib import admin
from .models import DailySummary, WeeklySummary, MonthlySummary, HabitAnalytics


@admin.register(DailySummary)
class DailySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'total_habits', 'completed_count', 'completion_rate']
    list_filter = ['date']
    search_fields = ['user__email']
    ordering = ['-date']


@admin.register(WeeklySummary)
class WeeklySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'week_start', 'week_number', 'year', 'total_completions']
    list_filter = ['year', 'week_number']
    ordering = ['-week_start']


@admin.register(MonthlySummary)
class MonthlySummaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'year', 'month', 'total_completions', 'average_completion_rate']
    list_filter = ['year', 'month']
    ordering = ['-year', '-month']


@admin.register(HabitAnalytics)
class HabitAnalyticsAdmin(admin.ModelAdmin):
    list_display = ['habit', 'total_completions', 'lifetime_completion_rate', 'trend_direction']
    list_filter = ['trend_direction']
