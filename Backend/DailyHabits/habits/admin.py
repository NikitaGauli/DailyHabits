"""
Habits Admin
"""

from django.contrib import admin
from .models import Category, Habit, HabitLog, Streak, HabitCompletion


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'is_default', 'created_at']
    search_fields = ['name']


@admin.register(Habit)
class HabitAdmin(admin.ModelAdmin):
    list_display = ['title', 'user', 'category_name', 'frequency', 'status', 'is_deleted', 'created_at']
    list_filter = ['status', 'frequency', 'is_deleted', 'category_name']
    search_fields = ['title', 'user__email', 'description']
    ordering = ['-created_at']
    readonly_fields = ['created_at', 'updated_at', 'deleted_at']


@admin.register(HabitLog)
class HabitLogAdmin(admin.ModelAdmin):
    list_display = ['habit', 'date', 'status', 'count', 'completed_at']
    list_filter = ['status', 'date']
    search_fields = ['habit__title', 'habit__user__email']
    ordering = ['-date', '-completed_at']


@admin.register(Streak)
class StreakAdmin(admin.ModelAdmin):
    list_display = ['habit', 'current_streak', 'best_streak', 'total_completions', 'last_completed_date']
    search_fields = ['habit__title', 'habit__user__email']
    ordering = ['-current_streak']


@admin.register(HabitCompletion)
class HabitCompletionAdmin(admin.ModelAdmin):
    list_display = ['habit', 'date', 'completed_at']
    list_filter = ['date']
    ordering = ['-date']
