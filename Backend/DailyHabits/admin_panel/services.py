"""
admin_panel/services.py — Business Logic & Analytics Aggregation
================================================================
Stateless service methods that keep views thin and testable.
"""

import logging
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, F, Q, Sum
from django.db.models.functions import TruncDate
from django.utils import timezone

from achievements.models import UserAchievement
from gamification.models import Challenge, ChallengeParticipant, XPEvent
from habits.models import Habit, HabitLog, Streak
from settings_app.models import SupportTicket
from social.models import FeedPost, GroupChallenge, GroupHabit

from .models import (
    AuditLog,
    PlatformAnalyticsSnapshot,
    Report,
)

logger = logging.getLogger('admin_panel')
User = get_user_model()


# ═══════════════════════════════════════════════════════════════════════════════
#  AUDIT SERVICE
# ═══════════════════════════════════════════════════════════════════════════════

class AuditService:
    """Creates immutable audit log entries for admin actions."""

    @staticmethod
    def log(
        *,
        admin_user,
        action: str,
        resource_type: str = '',
        resource_id: str = '',
        description: str = '',
        changes: dict | None = None,
        request=None,
        severity: str = 'info',
        metadata: dict | None = None,
    ) -> AuditLog:
        ip = ''
        user_agent = ''
        if request:
            ip = (
                request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip()
                or request.META.get('REMOTE_ADDR', '')
            )
            user_agent = request.META.get('HTTP_USER_AGENT', '')

        return AuditLog.objects.create(
            admin_user=admin_user,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id),
            description=description,
            changes=changes or {},
            ip_address=ip or None,
            user_agent=user_agent,
            severity=severity,
            metadata=metadata or {},
        )


# ═══════════════════════════════════════════════════════════════════════════════
#  ANALYTICS SERVICE
# ═══════════════════════════════════════════════════════════════════════════════

class AnalyticsService:
    """Aggregation queries for the admin dashboard."""

    @staticmethod
    def get_overview_stats() -> dict:
        """Compute real-time KPI stats for the overview dashboard."""
        now = timezone.now()
        today = now.date()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)

        total_users = User.objects.count()
        active_today = User.objects.filter(last_login__date=today).count()
        new_today = User.objects.filter(created_at__date=today).count()
        new_this_week = User.objects.filter(created_at__date__gte=week_ago).count()

        total_habits = Habit.objects.filter(is_deleted=False).count()
        completed_today = HabitLog.objects.filter(
            date=today, status='completed',
        ).count()

        # Average completion rate (last 7 days)
        last_7_logs = HabitLog.objects.filter(date__gte=week_ago)
        total_logs = last_7_logs.count()
        completed_logs = last_7_logs.filter(status='completed').count()
        avg_rate = round(completed_logs / total_logs * 100, 1) if total_logs else 0.0

        active_streaks = Streak.objects.filter(current_streak__gt=0).count()
        total_groups = GroupHabit.objects.filter(is_active=True).count()
        active_challenges = Challenge.objects.filter(status='active').count()
        pending_reports = Report.objects.filter(status='pending').count()
        open_tickets = SupportTicket.objects.filter(
            status__in=['open', 'in_progress'],
        ).count()
        xp_today = XPEvent.objects.filter(
            created_at__date=today,
        ).aggregate(total=Sum('amount'))['total'] or 0

        return {
            'total_users': total_users,
            'active_users_today': active_today,
            'new_users_today': new_today,
            'new_users_this_week': new_this_week,
            'total_habits': total_habits,
            'habits_completed_today': completed_today,
            'average_completion_rate': avg_rate,
            'active_streaks': active_streaks,
            'total_groups': total_groups,
            'total_challenges_active': active_challenges,
            'pending_reports': pending_reports,
            'open_support_tickets': open_tickets,
            'total_xp_today': xp_today,
        }

    @staticmethod
    def get_growth_trends(days: int = 30) -> list[dict]:
        """
        Return daily user-growth trend data for the last N days.
        Uses PlatformAnalyticsSnapshots if available, otherwise live queries.
        """
        end = timezone.now().date()
        start = end - timedelta(days=days)

        snapshots = PlatformAnalyticsSnapshot.objects.filter(
            date__gte=start, date__lte=end,
        ).order_by('date').values(
            'date', 'total_users', 'new_users',
            'daily_active_users', 'average_completion_rate',
        )

        if snapshots.exists():
            return [
                {
                    'date': s['date'],
                    'total_users': s['total_users'],
                    'new_users': s['new_users'],
                    'daily_active_users': s['daily_active_users'],
                    'completion_rate': s['average_completion_rate'],
                }
                for s in snapshots
            ]

        # Fallback: live aggregation (slower but works without snapshots)
        from django.db.models.functions import TruncDate

        daily_signups = (
            User.objects.filter(created_at__date__gte=start)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(count=Count('id'))
            .order_by('day')
        )
        signup_map = {d['day']: d['count'] for d in daily_signups}

        daily_active = (
            User.objects.filter(last_login__date__gte=start)
            .annotate(day=TruncDate('last_login'))
            .values('day')
            .annotate(count=Count('id'))
            .order_by('day')
        )
        active_map = {d['day']: d['count'] for d in daily_active}

        running_total = User.objects.filter(created_at__date__lt=start).count()
        results = []
        current = start
        while current <= end:
            new = signup_map.get(current, 0)
            running_total += new
            results.append({
                'date': current,
                'total_users': running_total,
                'new_users': new,
                'daily_active_users': active_map.get(current, 0),
                'completion_rate': 0.0,
            })
            current += timedelta(days=1)

        return results

    @staticmethod
    def get_engagement_metrics(days: int = 30) -> dict:
        """Engagement breakdown for the analytics section."""
        today = timezone.now().date()
        start = today - timedelta(days=days)

        logs = HabitLog.objects.filter(date__gte=start)
        total = logs.count()
        completed = logs.filter(status='completed').count()
        skipped = logs.filter(status='skipped').count()
        missed = logs.filter(status='missed').count()

        # Streak distribution
        streak_dist = (
            Streak.objects.filter(current_streak__gt=0)
            .values('current_streak')
            .annotate(count=Count('id'))
            .order_by('current_streak')
        )

        # Top categories
        category_stats = (
            Habit.objects.filter(is_deleted=False)
            .values('category_name')
            .annotate(count=Count('id'))
            .order_by('-count')[:10]
        )

        # Challenge achievement ratings normalized to a 10-point scale.
        group_challenges = GroupChallenge.objects.filter(created_at__date__gte=start)
        group_total = group_challenges.count()
        group_completed = group_challenges.filter(status='completed').count()
        group_rating_10 = round(group_completed / group_total * 10, 1) if group_total else 0.0

        individual_participants = ChallengeParticipant.objects.filter(
            challenge__scope='personal', joined_at__date__gte=start,
        )
        individual_total = individual_participants.count()
        individual_completed = individual_participants.filter(status='completed').count()
        individual_rating_10 = (
            round(individual_completed / individual_total * 10, 1)
            if individual_total else 0.0
        )

        return {
            'period_days': days,
            'total_logs': total,
            'completed': completed,
            'skipped': skipped,
            'missed': missed,
            'completion_rate': round(completed / total * 100, 1) if total else 0.0,
            'streak_distribution': list(streak_dist),
            'top_categories': list(category_stats),
            'group_challenge_rating_10': group_rating_10,
            'group_challenges_completed': group_completed,
            'group_challenges_total': group_total,
            'individual_challenge_rating_10': individual_rating_10,
            'individual_challenges_completed': individual_completed,
            'individual_challenges_total': individual_total,
        }

    @staticmethod
    def get_retention_metrics() -> dict:
        """Cohort-based retention approximation."""
        today = timezone.now().date()

        def retention(days_ago):
            cohort_start = today - timedelta(days=days_ago + 7)
            cohort_end = today - timedelta(days=days_ago)
            check_start = today - timedelta(days=7)

            cohort = User.objects.filter(
                created_at__date__gte=cohort_start,
                created_at__date__lte=cohort_end,
            )
            cohort_size = cohort.count()
            if cohort_size == 0:
                return 0.0

            retained = cohort.filter(last_login__date__gte=check_start).count()
            return round(retained / cohort_size * 100, 1)

        return {
            'day_1_retention': retention(1),
            'day_7_retention': retention(7),
            'day_30_retention': retention(30),
        }

    @staticmethod
    def take_daily_snapshot() -> PlatformAnalyticsSnapshot:
        """
        Capture and persist today's aggregated metrics.
        Called by a scheduled management command or Celery task.
        """
        today = timezone.now().date()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)

        stats = AnalyticsService.get_overview_stats()
        retention = AnalyticsService.get_retention_metrics()

        snapshot, _ = PlatformAnalyticsSnapshot.objects.update_or_create(
            date=today,
            defaults={
                'total_users': stats['total_users'],
                'new_users': stats['new_users_today'],
                'daily_active_users': stats['active_users_today'],
                'weekly_active_users': User.objects.filter(
                    last_login__date__gte=week_ago,
                ).count(),
                'monthly_active_users': User.objects.filter(
                    last_login__date__gte=month_ago,
                ).count(),
                'total_habits': stats['total_habits'],
                'habits_completed_today': stats['habits_completed_today'],
                'average_completion_rate': stats['average_completion_rate'],
                'total_streaks_active': stats['active_streaks'],
                'total_shared_habits': 0,
                'total_groups': stats['total_groups'],
                'total_feed_posts': FeedPost.objects.filter(
                    created_at__date=today,
                ).count(),
                'total_xp_earned': stats['total_xp_today'],
                'total_achievements_unlocked': UserAchievement.objects.filter(
                    earned_at__date=today,
                ).count(),
                'total_challenges_active': stats['total_challenges_active'],
                'day_1_retention': retention['day_1_retention'],
                'day_7_retention': retention['day_7_retention'],
                'day_30_retention': retention['day_30_retention'],
                'total_reports_pending': stats['pending_reports'],
                'total_support_tickets_open': stats['open_support_tickets'],
            },
        )
        return snapshot
