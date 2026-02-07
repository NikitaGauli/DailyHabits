"""
Enhanced Habit Serializers
Production-ready serializers with validation
"""

from rest_framework import serializers
from .models import Habit, HabitLog, Streak, Category, HabitCompletion


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'icon_code', 'color_value']


class StreakSerializer(serializers.ModelSerializer):
    class Meta:
        model = Streak
        fields = [
            'current_streak', 'best_streak', 'last_completed_date',
            'streak_start_date', 'total_completions', 'total_skips', 
            'total_misses', 'updated_at'
        ]


class HabitLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = HabitLog
        fields = [
            'id', 'date', 'status', 'count', 'completed_at', 
            'notes', 'mood_rating', 'energy_level', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class HabitSerializer(serializers.ModelSerializer):
    """
    Full habit serializer with nested streak data
    """
    streak = StreakSerializer(read_only=True)
    isCompleted = serializers.SerializerMethodField()
    currentStreak = serializers.SerializerMethodField()
    bestStreak = serializers.SerializerMethodField()
    
    # Camel case mappings for Flutter
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    categoryName = serializers.CharField(source='category_name', required=False)
    startDate = serializers.DateField(source='start_date', required=False)
    endDate = serializers.DateField(source='end_date', required=False, allow_null=True)
    reminderEnabled = serializers.BooleanField(source='reminder_enabled', required=False)
    reminderTime = serializers.TimeField(source='reminder_time', required=False, allow_null=True)
    customDays = serializers.JSONField(source='custom_days', required=False)
    targetCount = serializers.IntegerField(source='target_count', required=False)
    
    class Meta:
        model = Habit
        fields = [
            'id', 'title', 'description', 'category', 'categoryName',
            'time', 'frequency', 'customDays', 'targetCount',
            'startDate', 'endDate', 'iconCode', 'colorValue',
            'status', 'priority', 'reminderEnabled', 'reminderTime',
            'created_at', 'updated_at',
            # Computed fields
            'isCompleted', 'currentStreak', 'bestStreak', 'streak',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'streak']
    
    def get_isCompleted(self, obj):
        """Check if habit is completed today"""
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_currentStreak(self, obj):
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_bestStreak(self, obj):
        try:
            return obj.streak.best_streak
        except Streak.DoesNotExist:
            return 0
    
    def create(self, validated_data):
        """Create habit and initialize streak"""
        habit = Habit.objects.create(**validated_data)
        
        # Initialize streak record
        Streak.objects.create(habit=habit)
        
        return habit
    
    def to_representation(self, instance):
        """Customize output representation"""
        data = super().to_representation(instance)
        
        # Ensure consistent field names
        if 'start_date' in data:
            data['startDate'] = data.pop('start_date')
        if 'end_date' in data:
            data['endDate'] = data.pop('end_date')
        if 'icon_code' in data:
            data['iconCode'] = data.pop('icon_code')
        if 'color_value' in data:
            data['colorValue'] = data.pop('color_value')
        if 'category_name' in data:
            data['categoryName'] = data.pop('category_name')
        if 'reminder_enabled' in data:
            data['reminderEnabled'] = data.pop('reminder_enabled')
        if 'reminder_time' in data:
            data['reminderTime'] = data.pop('reminder_time')
        if 'custom_days' in data:
            data['customDays'] = data.pop('custom_days')
            
        return data


class HabitListSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for listing habits — camelCase output
    """
    isCompleted = serializers.SerializerMethodField()
    currentStreak = serializers.SerializerMethodField()
    
    class Meta:
        model = Habit
        fields = [
            'id', 'title', 'description', 'category_name', 'time', 'frequency',
            'icon_code', 'color_value', 'status', 'priority',
            'start_date', 'reminder_enabled', 'reminder_time',
            'isCompleted', 'currentStreak',
        ]
    
    def get_isCompleted(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_currentStreak(self, obj):
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def to_representation(self, instance):
        """Convert snake_case to camelCase for Flutter"""
        data = super().to_representation(instance)
        renames = {
            'category_name': 'categoryName',
            'icon_code': 'iconCode',
            'color_value': 'colorValue',
            'start_date': 'startDate',
            'reminder_enabled': 'reminderEnabled',
            'reminder_time': 'reminderTime',
        }
        for old_key, new_key in renames.items():
            if old_key in data:
                data[new_key] = data.pop(old_key)
        return data


class HabitCompletionSerializer(serializers.ModelSerializer):
    """
    Legacy completion serializer
    """
    class Meta:
        model = HabitCompletion
        fields = ['id', 'date', 'completed_at']
        read_only_fields = ['id', 'completed_at']


class TodayHabitSerializer(serializers.ModelSerializer):
    """
    Serializer for today's habit view — returns camelCase for Flutter
    """
    isCompleted = serializers.SerializerMethodField()
    completionState = serializers.SerializerMethodField()
    currentStreak = serializers.SerializerMethodField()
    bestStreak = serializers.SerializerMethodField()
    todayLog = serializers.SerializerMethodField()
    
    class Meta:
        model = Habit
        fields = [
            'id', 'title', 'description', 'category_name', 'time',
            'frequency', 'custom_days', 'target_count',
            'icon_code', 'color_value', 'status', 'priority',
            'start_date', 'end_date',
            'reminder_enabled', 'reminder_time',
            'isCompleted', 'completionState', 'currentStreak', 'bestStreak', 'todayLog',
        ]
    
    def get_isCompleted(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_completionState(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        log = HabitLog.objects.filter(habit=obj, date=today).first()
        if log:
            return log.status
        return 'pending'
    
    def get_currentStreak(self, obj):
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_bestStreak(self, obj):
        try:
            return obj.streak.best_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_todayLog(self, obj):
        from django.utils import timezone
        today = timezone.now().date()
        log = HabitLog.objects.filter(habit=obj, date=today).first()
        if log:
            return {
                'id': log.id,
                'status': log.status,
                'completedAt': log.completed_at.isoformat() if log.completed_at else None,
                'notes': log.notes,
            }
        return None
    
    def to_representation(self, instance):
        """Convert snake_case model fields to camelCase for Flutter"""
        data = super().to_representation(instance)
        
        # Map snake_case to camelCase
        renames = {
            'category_name': 'categoryName',
            'icon_code': 'iconCode',
            'color_value': 'colorValue',
            'start_date': 'startDate',
            'end_date': 'endDate',
            'reminder_enabled': 'reminderEnabled',
            'reminder_time': 'reminderTime',
            'custom_days': 'customDays',
            'target_count': 'targetCount',
        }
        for old_key, new_key in renames.items():
            if old_key in data:
                data[new_key] = data.pop(old_key)
        
        return data
