"""
Habits Serializers — DRF Serializers for the Habits API
=======================================================

This module provides the full set of Django REST Framework serializers used to
convert Habit-related model instances to and from JSON.  Because the Flutter
frontend expects **camelCase** field names while Django models use
**snake_case**, every serializer that faces the client includes an explicit
``to_representation`` override that performs the mapping.

Serializer hierarchy (ordered by weight):
    - :class:`CategorySerializer`       — Lightweight category payload.
    - :class:`StreakSerializer`          — Read-only streak data.
    - :class:`HabitLogSerializer`        — Individual daily-log CRUD.
    - :class:`HabitSerializer`           — Full habit detail (create/update).
    - :class:`HabitListSerializer`       — Minimal list representation.
    - :class:`HabitCompletionSerializer` — Legacy completion records.
    - :class:`TodayHabitSerializer`      — Today's dashboard with live status.

Authors:
    DailyHabits Engineering Team

Since:
    v1.0.0
"""

# === Third-Party Imports =====================================================
from rest_framework import serializers

# === Local Imports ===========================================================
from .models import Habit, HabitLog, Streak, Category, HabitCompletion


# =============================================================================
# Simple / Utility Serializers
# =============================================================================


class CategorySerializer(serializers.ModelSerializer):
    """Serializer for :class:`~habits.models.Category` — read/write."""

    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'icon_code', 'color_value']


class StreakSerializer(serializers.ModelSerializer):
    """Read-only serializer exposing cached streak statistics."""

    class Meta:
        model = Streak
        fields = [
            'current_streak', 'best_streak', 'last_completed_date',
            'streak_start_date', 'total_completions', 'total_skips', 
            'total_misses', 'updated_at'
        ]


class HabitLogSerializer(serializers.ModelSerializer):
    """
    Serializer for individual :class:`~habits.models.HabitLog` entries.

    Used when the client queries or creates daily completion / skip / miss
    records.  The ``id`` and ``created_at`` fields are read-only.
    """

    class Meta:
        model = HabitLog
        fields = [
            'id', 'date', 'status', 'count', 'completed_at', 
            'notes', 'mood_rating', 'energy_level', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


# =============================================================================
# Full Habit Serializer (Detail / Create / Update)
# =============================================================================


class HabitSerializer(serializers.ModelSerializer):
    """
    Primary serializer for creating, updating, and retrieving habit details.

    Features:
        * Nested read-only ``streak`` data via :class:`StreakSerializer`.
        * Computed fields (``isCompleted``, ``currentStreak``, ``bestStreak``)
          calculated from related models at serialization time.
        * Explicit camelCase ↔ snake_case field mappings via ``source`` kwarg
          so the Flutter client receives idiomatic JSON.

    On **create**, a companion :class:`~habits.models.Streak` row is
    automatically initialised with zero values.
    """

    # --- Nested / Computed Fields --------------------------------------------

    streak = StreakSerializer(read_only=True)
    isCompleted = serializers.SerializerMethodField()   # True if completed today
    currentStreak = serializers.SerializerMethodField()  # Live current streak
    bestStreak = serializers.SerializerMethodField()     # All-time best
    
    # --- CamelCase ↔ snake_case Mappings for Flutter -------------------------

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
            'status', 'priority', 'visibility',
            'reminderEnabled', 'reminderTime',
            'created_at', 'updated_at',
            # Computed fields
            'isCompleted', 'currentStreak', 'bestStreak', 'streak',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'streak']
    
    def get_isCompleted(self, obj):
        """Return ``True`` if the habit has a 'completed' log entry for today."""
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_currentStreak(self, obj):
        """Safely fetch the current streak, defaulting to 0."""
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_bestStreak(self, obj):
        """Safely fetch the all-time best streak, defaulting to 0."""
        try:
            return obj.streak.best_streak
        except Streak.DoesNotExist:
            return 0
    
    def create(self, validated_data):
        """
        Create a new Habit and bootstrap its Streak record.

        Streak initialisation is performed eagerly so that downstream
        serializers can always rely on ``habit.streak`` existing.
        """
        habit = Habit.objects.create(**validated_data)
        
        # Bootstrap streak record with default zero values
        Streak.objects.create(habit=habit)
        
        return habit
    
    def to_representation(self, instance):
        """
        Post-process the serialized dict to guarantee camelCase keys.

        Although ``source`` mappings handle most fields, this catch-all
        renames any residual snake_case keys that slip through (e.g. from
        ``SerializerMethodField`` or raw model fields).
        """
        data = super().to_representation(instance)
        
        # Residual snake_case → camelCase cleanup
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


# =============================================================================
# Lightweight List Serializer
# =============================================================================


class HabitListSerializer(serializers.ModelSerializer):
    """
    Slimmed-down read-only serializer used for the habit list endpoint.

    Omits heavy nested data (full streak object, logs) and instead exposes
    only the two most useful computed fields — ``isCompleted`` and
    ``currentStreak`` — keeping the payload small and list rendering fast.
    """

    isCompleted = serializers.SerializerMethodField()
    currentStreak = serializers.SerializerMethodField()
    
    class Meta:
        model = Habit
        fields = [
            'id', 'title', 'description', 'category_name', 'time', 'frequency',
            'icon_code', 'color_value', 'status', 'priority', 'visibility',
            'start_date', 'reminder_enabled', 'reminder_time',
            'isCompleted', 'currentStreak',
        ]
    
    def get_isCompleted(self, obj):
        """Return ``True`` if the habit has a 'completed' log for today."""
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_currentStreak(self, obj):
        """Safely fetch the current streak; returns 0 when no streak row exists."""
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def to_representation(self, instance):
        """
        Rename snake_case model field names to camelCase for the Flutter client.

        A deterministic rename map is applied after the default serialization
        so that every list item matches the contract the frontend expects.
        """
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


# =============================================================================
# Legacy Completion Serializer
# =============================================================================


class HabitCompletionSerializer(serializers.ModelSerializer):
    """
    Serializer for the deprecated :class:`~habits.models.HabitCompletion` model.

    Retained for backwards compatibility with older mobile app versions.
    New features should use :class:`HabitLogSerializer` instead.

    .. deprecated:: 2.0
    """

    class Meta:
        model = HabitCompletion
        fields = ['id', 'date', 'completed_at']
        read_only_fields = ['id', 'completed_at']


# =============================================================================
# Today's Dashboard Serializer
# =============================================================================


class TodayHabitSerializer(serializers.ModelSerializer):
    """
    Rich serializer powering the *Today* screen in the Flutter app.

    In addition to the base habit fields this serializer resolves five
    computed properties per habit:

        * ``isCompleted``     — boolean, has a 'completed' log today.
        * ``completionState`` — string status of today's log (or 'pending').
        * ``currentStreak``   — int, consecutive-day streak.
        * ``bestStreak``      — int, all-time record streak.
        * ``todayLog``        — dict snapshot of today's log entry (or null).

    All snake_case model fields are renamed to camelCase in
    ``to_representation``.
    """

    # --- Computed SerializerMethodFields -------------------------------------

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
        """Return ``True`` if the habit has a 'completed' log for today."""
        from django.utils import timezone
        today = timezone.now().date()
        return HabitLog.objects.filter(
            habit=obj, 
            date=today, 
            status='completed'
        ).exists()
    
    def get_completionState(self, obj):
        """
        Return the status string of today's log, or ``'pending'`` if
        no log entry exists yet.
        """
        from django.utils import timezone
        today = timezone.now().date()
        log = HabitLog.objects.filter(habit=obj, date=today).first()
        if log:
            return log.status
        return 'pending'
    
    def get_currentStreak(self, obj):
        """Safely fetch the current streak; defaults to 0."""
        try:
            return obj.streak.current_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_bestStreak(self, obj):
        """Safely fetch the all-time best streak; defaults to 0."""
        try:
            return obj.streak.best_streak
        except Streak.DoesNotExist:
            return 0
    
    def get_todayLog(self, obj):
        """
        Return a lightweight dict snapshot of today's log entry.

        Returns:
            dict | None: ``{ id, status, completedAt, notes }`` when a log
            exists, otherwise ``None``.
        """
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
        """
        Rename snake_case model fields to camelCase for the Flutter client.

        Applies the same deterministic rename map used by
        :class:`HabitListSerializer` plus additional fields specific to
        the today view (``endDate``, ``customDays``, ``targetCount``).
        """
        data = super().to_representation(instance)
        
        # Deterministic snake_case → camelCase rename map
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
