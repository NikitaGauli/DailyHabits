"""
Habits Views — REST API Endpoints for Habit Management
======================================================

This module exposes all habit-related API endpoints through two DRF ViewSets:

    :class:`HabitViewSet`
        Full CRUD plus custom actions (today, toggle-complete, skip, pause,
        resume, reorder, partial-complete, history, stats, categories,
        stats_summary).  Covers every operation the Flutter client needs.

    :class:`HabitLogViewSet`
        Read-only / filtered listing of :class:`~habits.models.HabitLog`
        records.  Useful for calendar heat-maps, CSV exports, etc.

Authentication:
    All endpoints require ``IsAuthenticated``.  Users can only access
    their own data — queryset filtering by ``request.user`` is enforced
    at the ViewSet level.

Response convention:
    Every response wraps its payload in a ``{ success, message?, ... }``
    envelope so the Flutter ``ApiClient`` can handle success/error paths
    uniformly.

Authors:
    DailyHabits Engineering Team

Since:
    v1.0.0
"""

# === Third-Party Imports =====================================================
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

# === Django Imports ==========================================================
from django.utils import timezone
from django.db.models import Count, Q, Prefetch

# === Standard Library Imports ================================================
from datetime import timedelta, datetime

# === Local Imports ===========================================================
from .models import Habit, HabitLog, Streak, Category
from .serializers import (
    HabitSerializer, 
    HabitListSerializer,
    HabitLogSerializer,
    TodayHabitSerializer,
    CategorySerializer,
)
from achievements.services import AchievementService
from gamification.services import GamificationEngine
from notifications.services import NotificationCreator


# =============================================================================
# HabitViewSet — Primary Habit CRUD + Custom Actions
# =============================================================================


class HabitViewSet(viewsets.ModelViewSet):
    """
    Full-featured ViewSet for Habit CRUD and domain actions.

    Provides:
        * Standard REST verbs (list / create / retrieve / update / destroy).
        * ``today``           — filtered habits for the current day with progress.
        * ``toggle_complete`` — mark / un-mark a habit as completed today.
        * ``skip``            — record a skip with an optional reason.
        * ``history``         — paginated log history for a single habit.
        * ``stats``           — per-habit analytics (streak + consistency).
        * ``categories``      — default + user-defined categories.
        * ``stats_summary``   — dashboard-level aggregate statistics.
        * ``pause`` / ``resume`` — habit lifecycle management.
        * ``reorder``         — bulk update sort order.
        * ``partial_complete`` — fractional completion scoring.

    All endpoints are scoped to the authenticated user and exclude
    soft-deleted habits.
    """

    permission_classes = [permissions.IsAuthenticated]
    
    # --- Serializer Selection -------------------------------------------------

    def get_serializer_class(self):
        """Return the appropriate serializer based on the current action."""
        if self.action == 'list':
            return HabitListSerializer      # Lightweight for list views
        if self.action == 'today':
            return TodayHabitSerializer      # Rich payload for today screen
        return HabitSerializer               # Full detail for CRUD
    
    # --- Queryset Filtering ---------------------------------------------------

    def get_queryset(self):
        """
        Return the authenticated user's non-deleted habits.

        Supports optional query-parameter filters:
            * ``?status=active|paused|archived``
            * ``?category=<category_name>``

        The streak relation is eagerly loaded via ``select_related`` to
        avoid N+1 queries when serializing lists.
        """
        queryset = Habit.objects.filter(
            user=self.request.user,
            is_deleted=False
        ).select_related('streak').order_by('-created_at')
        
        # Optional query-param filters
        status_filter = self.request.query_params.get('status')
        category = self.request.query_params.get('category')
        
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if category:
            queryset = queryset.filter(category_name=category)
        
        return queryset
    
    # --- Standard CRUD Overrides ----------------------------------------------

    def perform_create(self, serializer):
        """Inject the authenticated user before saving a new habit."""
        serializer.save(user=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """
        POST /api/habits/

        Create a new habit for the authenticated user.  On success the
        achievement engine is triggered to check for creation-related
        milestones (e.g. "Created your first habit!").
        """
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            self.perform_create(serializer)
            
            # Trigger achievement evaluation for habit-creation milestones
            AchievementService.check_and_award_achievements(
                request.user, 
                trigger_type='habit_created'
            )
            
            return Response({
                'success': True,
                'message': 'Habit created successfully',
                'habit': serializer.data,
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'success': False,
            'message': 'Validation failed',
            'errors': serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)
    
    def update(self, request, *args, **kwargs):
        """
        PUT / PATCH /api/habits/{id}/

        Update an existing habit.  Supports both full and partial updates
        via the ``partial`` kwarg (DRF handles PATCH automatically).
        """
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Habit updated successfully',
                'habit': serializer.data,
            })
        
        return Response({
            'success': False,
            'message': 'Validation failed',
            'errors': serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)
    
    def destroy(self, request, *args, **kwargs):
        """
        DELETE /api/habits/{id}/

        Perform a **soft delete** — the habit is flagged as deleted but
        remains in the database so historical analytics data is preserved.
        """
        instance = self.get_object()
        instance.soft_delete()
        
        return Response({
            'success': True,
            'message': 'Habit deleted successfully',
        }, status=status.HTTP_200_OK)
    
    # --- Today's Habits Endpoint ----------------------------------------------

    @action(detail=False, methods=['get'])
    def today(self, request):
        """
        GET /api/habits/today/

        Return all **active** habits scheduled for today together with a
        progress summary.  The response includes:

            * ``habits``  — serialized list (via :class:`TodayHabitSerializer`).
            * ``summary`` — aggregate dict with total, completed, remaining,
              progress percentage, streak highs, and category counts.
        """
        today = timezone.now().date()
        weekday = today.weekday()  # 0 = Monday
        
        habits = self.get_queryset().filter(status='active')
        
        # Build the today-specific habit list based on each habit's frequency
        today_habits = []
        for habit in habits:
            if habit.frequency == 'daily':
                today_habits.append(habit)
            elif habit.frequency == 'custom' and weekday in (habit.custom_days or []):
                today_habits.append(habit)
            elif habit.frequency == 'weekly':
                today_habits.append(habit)  # Weekly: shown every day of the week
        
        serializer = TodayHabitSerializer(today_habits, many=True)
        
        # --- Calculate today’s progress stats --------------------------------
        total = len(today_habits)
        completed = sum(1 for h in today_habits if HabitLog.objects.filter(
            habit=h, date=today, status='completed'
        ).exists())
        
        # Determine the highest streak values across today’s habits
        max_current_streak = 0
        max_best_streak = 0
        for h in today_habits:
            try:
                max_current_streak = max(max_current_streak, h.streak.current_streak)
                max_best_streak = max(max_best_streak, h.streak.best_streak)
            except Streak.DoesNotExist:
                pass
        
        # Tally habits per category for the frontend filter chips
        category_counts = {}
        for h in today_habits:
            cat = h.category_name or 'General'
            category_counts[cat] = category_counts.get(cat, 0) + 1
        
        return Response({
            'success': True,
            'date': today.isoformat(),
            'habits': serializer.data,
            'summary': {
                'total': total,
                'completed': completed,
                'remaining': total - completed,
                'progress': round((completed / total * 100) if total > 0 else 0, 1),
                'currentStreak': max_current_streak,
                'bestStreak': max_best_streak,
                'categories': category_counts,
            }
        })
    
    # --- Toggle Completion Endpoint -------------------------------------------

    @action(detail=True, methods=['post'], url_path='toggle-complete')
    def toggle_complete(self, request, pk=None):
        """
        POST /api/habits/{id}/toggle-complete/

        Idempotent toggle: if the habit is already completed today it
        reverts to ``missed``; otherwise it records a new completion.

        On completion the achievement engine is invoked, and any newly
        earned achievements are returned in ``newAchievements``.
        """
        habit = self.get_object()
        today = timezone.now().date()
        now = timezone.now()

        try:
            completion_count = int(request.data.get('count', 1))
        except (TypeError, ValueError):
            completion_count = 1
        completion_count = max(1, completion_count)

        notes = request.data.get('notes', '')
        mood_rating = request.data.get('moodRating')
        energy_level = request.data.get('energyLevel')
        
        # Check for an existing log entry for today
        log = HabitLog.objects.filter(habit=habit, date=today).first()
        
        if log and log.status == 'completed':
            # --- Un-complete path ------------------------------------------------
            log.status = 'missed'
            log.completed_at = None
            log.save()
            
            # Recalculate streak after revoking completion
            updated_streak = self._update_streak_on_uncomplete(habit)
            
            return Response({
                'success': True,
                'status': 'uncompleted',
                'isCompleted': False,
                'currentStreak': updated_streak,
            })
        else:
            # --- Complete path ---------------------------------------------------
            if log:
                # Update existing log (e.g. converting 'missed' → 'completed')
                log.status = 'completed'
                log.completed_at = now
                log.notes = notes or log.notes or ''
                log.mood_rating = mood_rating if mood_rating is not None else log.mood_rating
                log.energy_level = energy_level if energy_level is not None else log.energy_level
                log.count = completion_count
                log.save()
            else:
                # Create a brand-new completion log
                HabitLog.objects.create(
                    habit=habit,
                    date=today,
                    status='completed',
                    completed_at=now,
                    notes=notes,
                    mood_rating=mood_rating,
                    energy_level=energy_level,
                    count=completion_count,
                )
            
            # Extend the streak cache
            self._update_streak_on_complete(habit, today)
            
            # Evaluate completion-triggered achievements
            newly_earned = AchievementService.check_and_award_achievements(
                request.user, 
                habit=habit,
                trigger_type='habit_completed'
            )

            # Award XP, coins, and check challenges via gamification engine
            gamification_result = GamificationEngine.award_habit_completion_xp(
                request.user, habit
            )
            
            # Check milestones after XP award
            milestone_results = GamificationEngine.check_milestones(request.user)

            # ── Create a completion notification for real-time delivery ──
            streak_count = habit.streak.current_streak if hasattr(habit, 'streak') else 0
            NotificationCreator.create(
                user=request.user,
                notification_type='system',
                title=f'✅ {habit.title} completed!',
                message=f'Great job! You completed "{habit.title}" today.'
                        + (f' 🔥 {streak_count}-day streak!' if streak_count > 1 else ''),
                habit=habit,
                icon_code=0xE86C,
                color_value=0xFF22C55E,
                action_type='habit_detail',
                action_data={'habitId': habit.id},
            )

            # ── Streak milestone notifications (7, 14, 21, 30, 50, 100…) ──
            milestone_thresholds = {7, 14, 21, 30, 50, 75, 100, 150, 200, 365}
            if streak_count in milestone_thresholds:
                NotificationCreator.streak_milestone(request.user, habit, streak_count)

            # ── Achievement notifications ──
            for ua in newly_earned:
                NotificationCreator.achievement_earned(
                    request.user, ua.achievement, habit=habit,
                )

            return Response({
                'success': True,
                'status': 'completed',
                'isCompleted': True,
                'currentStreak': habit.streak.current_streak if hasattr(habit, 'streak') else 0,
                'reflection': {
                    'notes': notes,
                    'moodRating': mood_rating,
                    'energyLevel': energy_level,
                },
                'newAchievements': [{
                    'id': ua.achievement.id,
                    'name': ua.achievement.name,
                    'points': ua.achievement.points,
                } for ua in newly_earned],
                'gamification': {
                    'xpEarned': gamification_result.get('xp', 0),
                    'coinsEarned': gamification_result.get('coins', 0),
                    'multiplier': gamification_result.get('multiplier', 1.0),
                    'allDoneBonus': gamification_result.get('all_done_bonus'),
                    'milestones': milestone_results,
                },
            })
    
    # --- Skip Endpoint --------------------------------------------------------

    @action(detail=True, methods=['post'])
    def skip(self, request, pk=None):
        """
        POST /api/habits/{id}/skip/

        Record the habit as *skipped* for today with an optional reason.
        Skips increment the streak's ``total_skips`` counter but do **not**
        break the streak.
        """
        habit = self.get_object()
        today = timezone.now().date()
        
        # Upsert today's log as 'skipped'
        log, created = HabitLog.objects.update_or_create(
            habit=habit,
            date=today,
            defaults={
                'status': 'skipped',
                'notes': request.data.get('reason', ''),
            }
        )
        
        # Increment the skip counter on the streak record
        if hasattr(habit, 'streak'):
            habit.streak.total_skips += 1
            habit.streak.save()
        
        return Response({
            'success': True,
            'status': 'skipped',
        })
    
    # --- History Endpoint -----------------------------------------------------

    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):
        """
        GET /api/habits/{id}/history/?days=30

        Return the completion history (log entries) for a single habit.
        The ``days`` query parameter controls the lookback window
        (default 30, max 365).
        """
        habit = self.get_object()
        
        # Parse and clamp the lookback window
        days = int(request.query_params.get('days', 30))
        days = min(days, 365)  # Hard cap at one year
        
        today = timezone.now().date()
        start_date = today - timedelta(days=days)
        
        logs = HabitLog.objects.filter(
            habit=habit,
            date__range=[start_date, today]
        ).order_by('-date')
        
        return Response({
            'success': True,
            'habitId': habit.id,
            'habitTitle': habit.title,
            'history': [{
                'date': log.date.isoformat(),
                'status': log.status,
                'completedAt': log.completed_at.isoformat() if log.completed_at else None,
                'notes': log.notes,
                'moodRating': log.mood_rating,
                'energyLevel': log.energy_level,
                'count': log.count,
                'partialScore': log.partial_score,
            } for log in logs],
        })
    
    # --- Per-Habit Statistics Endpoint ----------------------------------------

    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """
        GET /api/habits/{id}/stats/

        Return per-habit statistics including streak data and consistency
        percentages over 7, 30, and 90 day windows.  Delegates heavy
        computation to :class:`~analytics.services.AnalyticsService`.
        """
        habit = self.get_object()
        
        try:
            streak = habit.streak
            streak_data = {
                'currentStreak': streak.current_streak,
                'bestStreak': streak.best_streak,
                'totalCompletions': streak.total_completions,
                'totalSkips': streak.total_skips,
                'totalMisses': streak.total_misses,
                'lastCompleted': streak.last_completed_date.isoformat() if streak.last_completed_date else None,
            }
        except Streak.DoesNotExist:
            # No streak record yet — return zeroed-out defaults
            streak_data = {
                'currentStreak': 0,
                'bestStreak': 0,
                'totalCompletions': 0,
                'totalSkips': 0,
                'totalMisses': 0,
                'lastCompleted': None,
            }
        
        # Delegate consistency calculations to the analytics service
        from analytics.services import AnalyticsService
        
        return Response({
            'success': True,
            'habitId': habit.id,
            'habitTitle': habit.title,
            'streak': streak_data,
            'consistency': {
                '7days': AnalyticsService.get_consistency_percentage(habit, 7),
                '30days': AnalyticsService.get_consistency_percentage(habit, 30),
                '90days': AnalyticsService.get_consistency_percentage(habit, 90),
            },
            'successRate': AnalyticsService.get_habit_success_rate(habit),
        })
    
    # --- Categories Endpoint --------------------------------------------------

    @action(detail=False, methods=['get'])
    def categories(self, request):
        """
        GET /api/habits/categories/

        Return two collections:
            * ``defaultCategories`` — system-defined category list with icon
              and colour values matching Flutter Material Icons.
            * ``userCategories``    — distinct category names the user has
              assigned to their own habits.
        """
        # System-provided defaults (icon codes are Material Icons codePoints)
        default_categories = [
            {'name': 'Health', 'iconCode': 0xE87D, 'colorValue': 0xFF10B981},
            {'name': 'Fitness', 'iconCode': 0xEB43, 'colorValue': 0xFFEF4444},
            {'name': 'Productivity', 'iconCode': 0xE8F9, 'colorValue': 0xFF3B82F6},
            {'name': 'Learning', 'iconCode': 0xE865, 'colorValue': 0xFF8B5CF6},
            {'name': 'Wellness', 'iconCode': 0xE87E, 'colorValue': 0xFFF59E0B},
            {'name': 'Finance', 'iconCode': 0xE227, 'colorValue': 0xFF06B6D4},
            {'name': 'Social', 'iconCode': 0xE7FB, 'colorValue': 0xFFEC4899},
            {'name': 'Creativity', 'iconCode': 0xE40A, 'colorValue': 0xFFF97316},
            {'name': 'Mindfulness', 'iconCode': 0xEA25, 'colorValue': 0xFF14B8A6},
            {'name': 'Other', 'iconCode': 0xE8E0, 'colorValue': 0xFF6B7280},
        ]
        
        # Gather the user’s own unique category names
        user_categories = self.get_queryset().values_list('category_name', flat=True).distinct()
        
        return Response({
            'success': True,
            'defaultCategories': default_categories,
            'userCategories': list(user_categories),
        })
    
    # --- Dashboard Stats Summary Endpoint ------------------------------------

    @action(detail=False, methods=['get'])
    def stats_summary(self, request):
        """
        GET /api/habits/stats_summary/

        Aggregate dashboard-level statistics across all **active** habits:
            * ``totalHabits``       — number of active habits.
            * ``todayCompleted``    — how many are completed today.
            * ``todayProgress``     — percentage complete for today.
            * ``currentStreak``     — highest current streak among all habits.
            * ``bestStreak``        — highest all-time streak among all habits.
            * ``weeklyCompletions`` — total log entries this ISO week.
        """
        habits = self.get_queryset().filter(status='active')
        today = timezone.now().date()
        
        total_habits = habits.count()
        
        # Count today’s completed habits
        today_completed = 0
        for habit in habits:
            if HabitLog.objects.filter(habit=habit, date=today, status='completed').exists():
                today_completed += 1
        
        # Find the highest streak values across all active habits
        max_streak = 0
        max_best_streak = 0
        for habit in habits:
            try:
                max_streak = max(max_streak, habit.streak.current_streak)
                max_best_streak = max(max_best_streak, habit.streak.best_streak)
            except Streak.DoesNotExist:
                pass
        
        # Tally this ISO-week’s completions
        week_start = today - timedelta(days=today.weekday())  # Monday
        weekly_completions = HabitLog.objects.filter(
            habit__in=habits,
            date__range=[week_start, today],
            status='completed'
        ).count()
        
        return Response({
            'success': True,
            'totalHabits': total_habits,
            'todayCompleted': today_completed,
            'todayProgress': round((today_completed / total_habits * 100) if total_habits > 0 else 0, 1),
            'currentStreak': max_streak,
            'bestStreak': max_best_streak,
            'weeklyCompletions': weekly_completions,
        })
    
    # --- Internal Streak Helpers ----------------------------------------------

    def _update_streak_on_complete(self, habit, completed_date):
        """
        Create-or-fetch the Streak record and delegate the update.

        Uses ``get_or_create`` so that a Streak row is bootstrapped
        automatically if one doesn't already exist.
        """
        streak, created = Streak.objects.get_or_create(habit=habit)
        streak.update_streak(completed_date)
    
    def _update_streak_on_uncomplete(self, habit):
        """
        Recalculate the streak after a completion is revoked.

        Delegates to :meth:`AnalyticsService.calculate_current_streak` for
        an authoritative re-count based on the log history.
        """
        from analytics.services import AnalyticsService
        
        try:
            streak = habit.streak
            # Full re-count from log history keeps cache aligned with source of truth.
            streak.current_streak = AnalyticsService.calculate_current_streak(habit)
            streak.best_streak = AnalyticsService.calculate_best_streak(habit)
            streak.total_completions = HabitLog.objects.filter(
                habit=habit,
                status='completed',
            ).count()
            streak.total_skips = HabitLog.objects.filter(
                habit=habit,
                status='skipped',
            ).count()
            streak.total_misses = HabitLog.objects.filter(
                habit=habit,
                status='missed',
            ).count()

            latest_completion = HabitLog.objects.filter(
                habit=habit,
                status='completed',
            ).order_by('-date').first()
            streak.last_completed_date = latest_completion.date if latest_completion else None
            if streak.current_streak > 0 and streak.last_completed_date:
                streak.streak_start_date = streak.last_completed_date - timedelta(days=streak.current_streak - 1)
            else:
                streak.streak_start_date = None
            streak.save()
            return streak.current_streak
        except Streak.DoesNotExist:
            return 0

    # =========================================================================
    # Habit Quality-of-Life Endpoints
    # =========================================================================

    # --- Pause Endpoint -------------------------------------------------------

    @action(detail=True, methods=['post'])
    def pause(self, request, pk=None):
        """
        POST /api/habits/{id}/pause/

        Transition a habit to the ``paused`` state with an optional
        user-supplied reason.  While paused, the habit will not appear
        on the *Today* screen and its streak will not degrade.
        """
        habit = self.get_object()
        reason = request.data.get('reason', '')
        
        habit.status = 'paused'
        habit.pause_reason = reason
        habit.paused_at = timezone.now()
        habit.save()
        
        return Response({
            'success': True,
            'message': 'Habit paused',
            'pauseReason': reason,
        })

    # --- Archive Endpoint -----------------------------------------------------

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """
        POST /api/habits/{id}/archive/

        Archive a habit while keeping all historical logs and streak data.
        Archived habits are excluded from the default active list and today view.
        """
        habit = self.get_object()
        habit.status = 'archived'
        habit.pause_reason = request.data.get('reason', habit.pause_reason)
        habit.save(update_fields=['status', 'pause_reason', 'updated_at'])

        return Response({
            'success': True,
            'message': 'Habit archived successfully',
            'habitId': habit.id,
        })

    # --- Unarchive Endpoint ---------------------------------------------------

    @action(detail=True, methods=['post'])
    def unarchive(self, request, pk=None):
        """
        POST /api/habits/{id}/unarchive/

        Restore an archived habit back to active tracking.
        """
        habit = self.get_object()
        habit.status = 'active'
        habit.save(update_fields=['status', 'updated_at'])

        return Response({
            'success': True,
            'message': 'Habit unarchived successfully',
            'habitId': habit.id,
        })

    # --- Archived List Endpoint ----------------------------------------------

    @action(detail=False, methods=['get'])
    def archived(self, request):
        """
        GET /api/habits/archived/

        Return all archived habits for the authenticated user.
        """
        archived_habits = self.get_queryset().filter(status='archived').order_by('-updated_at')
        serializer = HabitListSerializer(archived_habits, many=True)

        return Response({
            'success': True,
            'count': archived_habits.count(),
            'habits': serializer.data,
        })

    # --- Resume Endpoint ------------------------------------------------------

    @action(detail=True, methods=['post'])
    def resume(self, request, pk=None):
        """
        POST /api/habits/{id}/resume/

        Transition a paused habit back to ``active``.  If the client sends
        ``{ "recoverStreak": true }`` the endpoint will grant a *grace
        recovery*, restoring the streak to 1 rather than leaving it at 0.
        """
        habit = self.get_object()
        recover_streak = request.data.get('recoverStreak', False)
        
        habit.status = 'active'
        habit.pause_reason = ''
        habit.paused_at = None
        habit.save()
        
        message = 'Habit resumed'
        
        # Optionally grant a streak grace-recovery
        if recover_streak:
            try:
                streak = habit.streak
                # Grace recovery: set streak to 1 so the user isn't penalised
                if streak.current_streak == 0:
                    streak.current_streak = 1
                    streak.last_completed_date = timezone.now().date()
                    streak.streak_start_date = timezone.now().date()
                    streak.save()
                    message = 'Habit resumed with streak recovery'
            except Streak.DoesNotExist:
                pass
        
        return Response({'success': True, 'message': message})

    # --- Reorder Endpoint -----------------------------------------------------

    @action(detail=False, methods=['post'])
    def reorder(self, request):
        """
        POST /api/habits/reorder/

        Bulk-update the ``sort_order`` of multiple habits in a single
        request.  Expects ``{ "order": [{ "id": 1, "sortOrder": 0 }, ...] }``.
        Only habits owned by the authenticated user are affected.
        """
        order_data = request.data.get('order', [])
        if not order_data:
            return Response({
                'success': False,
                'message': 'order list is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Apply each sort-order update (scoped to the current user)
        for item in order_data:
            Habit.objects.filter(
                id=item['id'], user=request.user
            ).update(sort_order=item['sortOrder'])
        
        return Response({
            'success': True,
            'message': f'Reordered {len(order_data)} habits'
        })

    # --- Partial Completion Endpoint ------------------------------------------

    @action(detail=True, methods=['post'], url_path='partial-complete')
    def partial_complete(self, request, pk=None):
        """
        POST /api/habits/{id}/partial-complete/

        Log a fractional completion for today.  The ``score`` field
        (0.0–1.0) is clamped to valid bounds.  A partial-complete does
        **not** count as a full completion for streak purposes.
        """
        habit = self.get_object()
        score = float(request.data.get('score', 0.5))
        score = max(0.0, min(1.0, score))  # Clamp to [0.0, 1.0]
        
        today = timezone.now().date()
        now = timezone.now()
        
        # Upsert today's log with partial status and score
        log, created = HabitLog.objects.update_or_create(
            habit=habit,
            date=today,
            defaults={
                'status': 'partial',
                'partial_score': score,
                'completed_at': now,
                'notes': request.data.get('notes', ''),
            }
        )
        
        return Response({
            'success': True,
            'status': 'partial',
            'partialScore': score,
        })

    # --- Mark Missed Endpoint -------------------------------------------------

    @action(detail=True, methods=['post'], url_path='mark-missed')
    def mark_missed(self, request, pk=None):
        """
        POST /api/habits/{id}/mark-missed/

        Explicitly mark a habit day as missed and optionally store a note.
        Accepts an optional ``date`` in ISO format; defaults to today.
        """
        habit = self.get_object()
        date_str = request.data.get('date')
        target_date = timezone.now().date()

        if date_str:
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response({
                    'success': False,
                    'message': 'Invalid date format. Use YYYY-MM-DD.',
                }, status=status.HTTP_400_BAD_REQUEST)

        note = request.data.get('notes', request.data.get('reason', ''))

        HabitLog.objects.update_or_create(
            habit=habit,
            date=target_date,
            defaults={
                'status': 'missed',
                'completed_at': None,
                'count': 0,
                'notes': note,
                'partial_score': 0.0,
            },
        )

        # Recalculate streak cache and aggregate counters from source-of-truth logs.
        self._update_streak_on_uncomplete(habit)

        NotificationCreator.create(
            user=request.user,
            notification_type='missed',
            title=f'Missed day logged for {habit.title}',
            message=f'"{habit.title}" was marked as missed for {target_date.isoformat()}.',
            habit=habit,
            icon_code=0xE002,
            color_value=0xFFF59E0B,
            action_type='habit_detail',
            action_data={'habitId': habit.id},
        )

        return Response({
            'success': True,
            'status': 'missed',
            'date': target_date.isoformat(),
            'notes': note,
        })

    # --- Missed Days Summary Endpoint ----------------------------------------

    @action(detail=False, methods=['get'], url_path='missed-days')
    def missed_days(self, request):
        """
        GET /api/habits/missed-days/?days=30

        Return missed-day summary and records for the requested lookback period.
        """
        days = int(request.query_params.get('days', 30))
        days = min(max(days, 1), 365)
        today = timezone.now().date()
        start_date = today - timedelta(days=days - 1)

        missed_logs = HabitLog.objects.filter(
            habit__user=request.user,
            habit__is_deleted=False,
            status='missed',
            date__range=[start_date, today],
        ).select_related('habit').order_by('-date', 'habit__title')

        by_habit = {}
        for log in missed_logs:
            hid = log.habit_id
            if hid not in by_habit:
                by_habit[hid] = {
                    'habitId': log.habit_id,
                    'habitTitle': log.habit.title,
                    'missedCount': 0,
                }
            by_habit[hid]['missedCount'] += 1

        return Response({
            'success': True,
            'range': {
                'startDate': start_date.isoformat(),
                'endDate': today.isoformat(),
                'days': days,
            },
            'totalMissed': missed_logs.count(),
            'habits': list(by_habit.values()),
            'records': [{
                'habitId': log.habit_id,
                'habitTitle': log.habit.title,
                'date': log.date.isoformat(),
                'notes': log.notes,
            } for log in missed_logs],
        })


# =============================================================================
# HabitLogViewSet — Completion Record Browsing
# =============================================================================


class HabitLogViewSet(viewsets.ModelViewSet):
    """
    Read / filter interface for :class:`~habits.models.HabitLog` entries.

    Primarily used by the frontend’s calendar heat-map and history views.
    All logs are scoped to the authenticated user.  Supports query-param
    filters for ``habit``, ``status``, ``start_date``, and ``end_date``.
    Results are capped at 100 rows to prevent unbounded payloads.
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = HabitLogSerializer
    
    def get_queryset(self):
        """Return logs for habits owned by the authenticated user."""
        return HabitLog.objects.filter(
            habit__user=self.request.user
        ).order_by('-date')
    
    def list(self, request):
        """
        GET /api/habit-logs/?habit=<id>&status=<s>&start_date=<d>&end_date=<d>

        Filterable listing of habit log entries.  All filters are optional;
        when none are supplied the 100 most recent logs are returned.
        """
        queryset = self.get_queryset()
        
        # --- Optional query-param filters ------------------------------------
        habit_id = request.query_params.get('habit')
        status_filter = request.query_params.get('status')
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        if habit_id:
            queryset = queryset.filter(habit_id=habit_id)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if start_date:
            queryset = queryset.filter(date__gte=start_date)
        if end_date:
            queryset = queryset.filter(date__lte=end_date)
        
        logs = queryset[:100]  # Hard cap to prevent oversized responses
        serializer = self.get_serializer(logs, many=True)
        
        return Response({
            'success': True,
            'logs': serializer.data,
            'count': queryset.count(),
        })
