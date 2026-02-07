"""
Enhanced Habit Views
Production-ready API endpoints with full functionality
"""

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Count, Q, Prefetch
from datetime import timedelta

from .models import Habit, HabitLog, Streak, Category
from .serializers import (
    HabitSerializer, 
    HabitListSerializer,
    HabitLogSerializer,
    TodayHabitSerializer,
    CategorySerializer,
)
from achievements.services import AchievementService


class HabitViewSet(viewsets.ModelViewSet):
    """
    Full CRUD ViewSet for habits
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'list':
            return HabitListSerializer
        if self.action == 'today':
            return TodayHabitSerializer
        return HabitSerializer
    
    def get_queryset(self):
        """Filter by current user and exclude soft-deleted"""
        queryset = Habit.objects.filter(
            user=self.request.user,
            is_deleted=False
        ).select_related('streak').order_by('-created_at')
        
        # Optional filters
        status_filter = self.request.query_params.get('status')
        category = self.request.query_params.get('category')
        
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if category:
            queryset = queryset.filter(category_name=category)
        
        return queryset
    
    def perform_create(self, serializer):
        """Save with current user"""
        serializer.save(user=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """Create habit with success response"""
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            self.perform_create(serializer)
            
            # Check for habit creation achievements
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
        """Update habit with success response"""
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
        """Soft delete habit"""
        instance = self.get_object()
        instance.soft_delete()
        
        return Response({
            'success': True,
            'message': 'Habit deleted successfully',
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['get'])
    def today(self, request):
        """
        GET /api/habits/today/
        Get habits scheduled for today with completion status
        """
        today = timezone.now().date()
        weekday = today.weekday()
        
        habits = self.get_queryset().filter(status='active')
        
        # Filter by frequency
        today_habits = []
        for habit in habits:
            if habit.frequency == 'daily':
                today_habits.append(habit)
            elif habit.frequency == 'custom' and weekday in (habit.custom_days or []):
                today_habits.append(habit)
            elif habit.frequency == 'weekly':
                today_habits.append(habit)
        
        serializer = TodayHabitSerializer(today_habits, many=True)
        
        # Calculate today's progress
        total = len(today_habits)
        completed = sum(1 for h in today_habits if HabitLog.objects.filter(
            habit=h, date=today, status='completed'
        ).exists())
        
        # Get overall streak info
        max_current_streak = 0
        max_best_streak = 0
        for h in today_habits:
            try:
                max_current_streak = max(max_current_streak, h.streak.current_streak)
                max_best_streak = max(max_best_streak, h.streak.best_streak)
            except Streak.DoesNotExist:
                pass
        
        # Category counts for filter chips
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
    
    @action(detail=True, methods=['post'], url_path='toggle-complete')
    def toggle_complete(self, request, pk=None):
        """
        POST /api/habits/{id}/toggle-complete/
        Toggle habit completion for today
        """
        habit = self.get_object()
        today = timezone.now().date()
        now = timezone.now()
        
        log = HabitLog.objects.filter(habit=habit, date=today).first()
        
        if log and log.status == 'completed':
            # Uncomplete
            log.status = 'missed'
            log.completed_at = None
            log.save()
            
            # Update streak
            self._update_streak_on_uncomplete(habit)
            
            return Response({
                'success': True,
                'status': 'uncompleted',
                'isCompleted': False,
            })
        else:
            # Complete
            if log:
                log.status = 'completed'
                log.completed_at = now
                log.save()
            else:
                HabitLog.objects.create(
                    habit=habit,
                    date=today,
                    status='completed',
                    completed_at=now
                )
            
            # Update streak
            self._update_streak_on_complete(habit, today)
            
            # Check achievements
            newly_earned = AchievementService.check_and_award_achievements(
                request.user, 
                habit=habit,
                trigger_type='habit_completed'
            )
            
            return Response({
                'success': True,
                'status': 'completed',
                'isCompleted': True,
                'currentStreak': habit.streak.current_streak if hasattr(habit, 'streak') else 0,
                'newAchievements': [{
                    'id': ua.achievement.id,
                    'name': ua.achievement.name,
                    'points': ua.achievement.points,
                } for ua in newly_earned],
            })
    
    @action(detail=True, methods=['post'])
    def skip(self, request, pk=None):
        """
        POST /api/habits/{id}/skip/
        Mark habit as skipped for today
        """
        habit = self.get_object()
        today = timezone.now().date()
        
        log, created = HabitLog.objects.update_or_create(
            habit=habit,
            date=today,
            defaults={
                'status': 'skipped',
                'notes': request.data.get('reason', ''),
            }
        )
        
        # Update streak skip count
        if hasattr(habit, 'streak'):
            habit.streak.total_skips += 1
            habit.streak.save()
        
        return Response({
            'success': True,
            'status': 'skipped',
        })
    
    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):
        """
        GET /api/habits/{id}/history/
        Get habit completion history
        """
        habit = self.get_object()
        
        days = int(request.query_params.get('days', 30))
        days = min(days, 365)
        
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
            } for log in logs],
        })
    
    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """
        GET /api/habits/{id}/stats/
        Get habit-specific statistics
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
            streak_data = {
                'currentStreak': 0,
                'bestStreak': 0,
                'totalCompletions': 0,
                'totalSkips': 0,
                'totalMisses': 0,
                'lastCompleted': None,
            }
        
        # Calculate consistency
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
    
    @action(detail=False, methods=['get'])
    def categories(self, request):
        """
        GET /api/habits/categories/
        Get available categories
        """
        # Default categories
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
        
        # Get user's custom categories
        user_categories = self.get_queryset().values_list('category_name', flat=True).distinct()
        
        return Response({
            'success': True,
            'defaultCategories': default_categories,
            'userCategories': list(user_categories),
        })
    
    @action(detail=False, methods=['get'])
    def stats_summary(self, request):
        """
        GET /api/habits/stats_summary/
        Get overall habit statistics
        """
        habits = self.get_queryset().filter(status='active')
        today = timezone.now().date()
        
        total_habits = habits.count()
        
        # Today's progress
        today_completed = 0
        for habit in habits:
            if HabitLog.objects.filter(habit=habit, date=today, status='completed').exists():
                today_completed += 1
        
        # Overall streak
        max_streak = 0
        max_best_streak = 0
        for habit in habits:
            try:
                max_streak = max(max_streak, habit.streak.current_streak)
                max_best_streak = max(max_best_streak, habit.streak.best_streak)
            except Streak.DoesNotExist:
                pass
        
        # This week's completions
        week_start = today - timedelta(days=today.weekday())
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
    
    def _update_streak_on_complete(self, habit, completed_date):
        """Update streak when habit is completed"""
        streak, created = Streak.objects.get_or_create(habit=habit)
        streak.update_streak(completed_date)
    
    def _update_streak_on_uncomplete(self, habit):
        """Update streak when habit is uncompleted"""
        from analytics.services import AnalyticsService
        
        try:
            streak = habit.streak
            # Recalculate current streak
            streak.current_streak = AnalyticsService.calculate_current_streak(habit)
            streak.total_completions = max(0, streak.total_completions - 1)
            streak.save()
        except Streak.DoesNotExist:
            pass

    # ─── Habit Quality-of-Life Endpoints ──────────────────────────────────

    @action(detail=True, methods=['post'])
    def pause(self, request, pk=None):
        """
        POST /api/habits/{id}/pause/
        Pause a habit with an optional reason
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

    @action(detail=True, methods=['post'])
    def resume(self, request, pk=None):
        """
        POST /api/habits/{id}/resume/
        Resume a paused habit — optionally recover streak
        """
        habit = self.get_object()
        recover_streak = request.data.get('recoverStreak', False)
        
        habit.status = 'active'
        habit.pause_reason = ''
        habit.paused_at = None
        habit.save()
        
        message = 'Habit resumed'
        
        if recover_streak:
            try:
                streak = habit.streak
                # Give a grace recovery — set streak to 1 instead of 0
                if streak.current_streak == 0:
                    streak.current_streak = 1
                    streak.last_completed_date = timezone.now().date()
                    streak.streak_start_date = timezone.now().date()
                    streak.save()
                    message = 'Habit resumed with streak recovery'
            except Streak.DoesNotExist:
                pass
        
        return Response({'success': True, 'message': message})

    @action(detail=False, methods=['post'])
    def reorder(self, request):
        """
        POST /api/habits/reorder/
        Reorder habits by sending a list of {id, sortOrder}
        """
        order_data = request.data.get('order', [])
        if not order_data:
            return Response({
                'success': False,
                'message': 'order list is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        for item in order_data:
            Habit.objects.filter(
                id=item['id'], user=request.user
            ).update(sort_order=item['sortOrder'])
        
        return Response({
            'success': True,
            'message': f'Reordered {len(order_data)} habits'
        })

    @action(detail=True, methods=['post'], url_path='partial-complete')
    def partial_complete(self, request, pk=None):
        """
        POST /api/habits/{id}/partial-complete/
        Log a partial completion with a score (0.0 – 1.0)
        """
        habit = self.get_object()
        score = float(request.data.get('score', 0.5))
        score = max(0.0, min(1.0, score))
        
        today = timezone.now().date()
        now = timezone.now()
        
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


class HabitLogViewSet(viewsets.ModelViewSet):
    """
    ViewSet for habit logs (completion records)
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = HabitLogSerializer
    
    def get_queryset(self):
        return HabitLog.objects.filter(
            habit__user=self.request.user
        ).order_by('-date')
    
    def list(self, request):
        """
        GET /api/habit-logs/
        List habit logs with filters
        """
        queryset = self.get_queryset()
        
        # Filters
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
        
        logs = queryset[:100]  # Limit
        serializer = self.get_serializer(logs, many=True)
        
        return Response({
            'success': True,
            'logs': serializer.data,
            'count': queryset.count(),
        })
