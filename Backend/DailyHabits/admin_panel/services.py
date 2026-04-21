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
from django.db.models.functions import ExtractHour

from achievements.models import UserAchievement
from gamification.models import Challenge, ChallengeParticipant, XPEvent
from habits.models import Habit, HabitLog, Streak
from notifications.models import Notification
from settings_app.models import LoginSession
from authentication.models import LoginActivity
from settings_app.models import SupportTicket
from social.models import FeedPost, GroupChallenge, GroupHabit

from .models import (
    AuditLog,
    NotificationCampaign,
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

    @staticmethod
    def _safe_div(numerator: float, denominator: float) -> float:
        if denominator <= 0:
            return 0.0
        return round((numerator / denominator) * 100, 1)

    @staticmethod
    def _daily_series(start_date, end_date, value_map: dict) -> list[dict]:
        rows = []
        day = start_date
        while day <= end_date:
            rows.append({'date': day.isoformat(), 'value': value_map.get(day, 0)})
            day += timedelta(days=1)
        return rows

    @staticmethod
    def _segment_user_queryset(queryset, segment: str):
        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)
        thirty_days_ago = now - timedelta(days=30)

        normalized = (segment or 'all').lower()
        if normalized == 'active':
            return queryset.filter(last_login__gte=seven_days_ago)
        if normalized == 'inactive':
            return queryset.filter(Q(last_login__lt=thirty_days_ago) | Q(last_login__isnull=True))
        if normalized == 'new':
            return queryset.filter(created_at__gte=seven_days_ago)
        return queryset

    @staticmethod
    def get_comprehensive_analytics(
        days: int = 30,
        compare_days: int | None = None,
        category: str = 'all',
        segment: str = 'all',
    ) -> dict:
        """Build a full admin analytics report payload with filters and comparisons."""
        today = timezone.now().date()
        end_date = today
        start_date = today - timedelta(days=max(days - 1, 0))

        compare_window = compare_days if compare_days is not None else days
        previous_end = start_date - timedelta(days=1)
        previous_start = previous_end - timedelta(days=max(compare_window - 1, 0))

        users_qs = AnalyticsService._segment_user_queryset(User.objects.all(), segment)

        habits_qs = Habit.objects.filter(user__in=users_qs, is_deleted=False)
        if category and category.lower() != 'all':
            habits_qs = habits_qs.filter(category_name__iexact=category)

        logs_period = HabitLog.objects.filter(
            habit__in=habits_qs,
            date__gte=start_date,
            date__lte=end_date,
        )
        logs_previous = HabitLog.objects.filter(
            habit__in=habits_qs,
            date__gte=previous_start,
            date__lte=previous_end,
        )

        # User growth + engagement
        signup_daily = (
            users_qs.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(count=Count('id'))
            .order_by('day')
        )
        signup_map = {row['day']: row['count'] for row in signup_daily}
        base_users = users_qs.filter(created_at__date__lt=start_date).count()
        growth_series = []
        running_users = base_users
        day = start_date
        while day <= end_date:
            new_users = signup_map.get(day, 0)
            running_users += new_users
            growth_series.append({
                'date': day.isoformat(),
                'new_users': new_users,
                'total_users': running_users,
            })
            day += timedelta(days=1)

        dau = users_qs.filter(last_login__date=end_date).count()
        wau = users_qs.filter(last_login__date__gte=end_date - timedelta(days=6)).count()
        mau = users_qs.filter(last_login__date__gte=end_date - timedelta(days=29)).count()

        retention = AnalyticsService.get_retention_metrics()
        churn_rate = round(max(0.0, 100.0 - retention.get('day_30_retention', 0.0)), 1)

        # Completion trend + comparison
        daily_stats = (
            logs_period.values('date')
            .annotate(
                total=Count('id'),
                completed=Count('id', filter=Q(status='completed')),
            )
            .order_by('date')
        )
        daily_map = {
            row['date']: {
                'total': row['total'],
                'completed': row['completed'],
            }
            for row in daily_stats
        }
        completion_trend = []
        day = start_date
        while day <= end_date:
            total = daily_map.get(day, {}).get('total', 0)
            completed = daily_map.get(day, {}).get('completed', 0)
            completion_trend.append({
                'date': day.isoformat(),
                'completed': completed,
                'total': total,
                'rate': AnalyticsService._safe_div(completed, total),
            })
            day += timedelta(days=1)

        period_total = logs_period.count()
        period_completed = logs_period.filter(status='completed').count()
        previous_total = logs_previous.count()
        previous_completed = logs_previous.filter(status='completed').count()

        period_rate = AnalyticsService._safe_div(period_completed, period_total)
        previous_rate = AnalyticsService._safe_div(previous_completed, previous_total)
        completion_rate_change = round(period_rate - previous_rate, 1)

        # Habit performance
        habits_for_rank = habits_qs.annotate(
            completed_count=Count(
                'logs',
                filter=Q(
                    logs__date__gte=start_date,
                    logs__date__lte=end_date,
                    logs__status='completed',
                ),
            ),
            total_logs=Count(
                'logs',
                filter=Q(logs__date__gte=start_date, logs__date__lte=end_date),
            ),
        )

        ranked = []
        for habit in habits_for_rank:
            completed_count = int(getattr(habit, 'completed_count', 0) or 0)
            total_logs = int(getattr(habit, 'total_logs', 0) or 0)
            completion_rate = AnalyticsService._safe_div(completed_count, total_logs)
            ranked.append({
                'habit_id': habit.id,
                'title': habit.title,
                'category': habit.category_name,
                'completed': completed_count,
                'total': total_logs,
                'completion_rate': completion_rate,
                'difficulty_score': habit.difficulty_score,
            })
        ranked.sort(key=lambda item: (item['completion_rate'], item['completed']), reverse=True)

        category_performance_raw = (
            logs_period.values('habit__category_name')
            .annotate(
                total=Count('id'),
                completed=Count('id', filter=Q(status='completed')),
            )
            .order_by('-completed')
        )
        category_performance = []
        for row in category_performance_raw:
            category_performance.append({
                'category': row['habit__category_name'] or 'General',
                'completed': row['completed'],
                'total': row['total'],
                'completion_rate': AnalyticsService._safe_div(row['completed'], row['total']),
            })

        # Simple heatmap matrix (weekday x hour bucket)
        heat_rows = (
            logs_period.filter(status='completed', completed_at__isnull=False)
            .annotate(hour=ExtractHour('completed_at'))
            .values('date', 'hour')
            .annotate(count=Count('id'))
        )
        heatmap_map = {}
        for row in heat_rows:
            weekday = row['date'].weekday()
            hour = row['hour'] or 0
            bucket = int(hour // 3)
            key = f'{weekday}-{bucket}'
            heatmap_map[key] = heatmap_map.get(key, 0) + row['count']
        heatmap_cells = []
        max_heat = max(heatmap_map.values()) if heatmap_map else 1
        for weekday in range(7):
            for bucket in range(8):
                count = heatmap_map.get(f'{weekday}-{bucket}', 0)
                heatmap_cells.append({
                    'weekday': weekday,
                    'time_bucket': bucket,
                    'label': f'{bucket * 3:02d}:00-{(bucket + 1) * 3:02d}:00',
                    'count': count,
                    'intensity': round(count / max_heat, 2) if max_heat else 0.0,
                })

        # Behavioral insights
        hour_data = [0] * 24
        day_data = [0] * 7
        for row in heat_rows:
            hour = row['hour'] or 0
            day_idx = row['date'].weekday()
            hour_data[hour] += row['count']
            day_data[day_idx] += row['count']

        hour_pattern = [{'hour': i, 'count': hour_data[i]} for i in range(24)]
        day_pattern = [
            {'day_index': i, 'day_label': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i], 'count': day_data[i]}
            for i in range(7)
        ]

        status_breakdown = {
            'completed': logs_period.filter(status='completed').count(),
            'skipped': logs_period.filter(status='skipped').count(),
            'missed': logs_period.filter(status='missed').count(),
            'partial': logs_period.filter(status='partial').count(),
        }

        # AI-style behavior clusters with rule-based segmentation
        user_rates = []
        user_logs = (
            logs_period.values('habit__user_id')
            .annotate(total=Count('id'), completed=Count('id', filter=Q(status='completed')))
        )
        for row in user_logs:
            rate = AnalyticsService._safe_div(row['completed'], row['total'])
            user_rates.append({'user_id': row['habit__user_id'], 'rate': rate})
        clusters = {
            'highly_consistent': 0,
            'steady_progress': 0,
            'at_risk': 0,
        }
        for row in user_rates:
            if row['rate'] >= 75:
                clusters['highly_consistent'] += 1
            elif row['rate'] >= 45:
                clusters['steady_progress'] += 1
            else:
                clusters['at_risk'] += 1

        # Notification & reminder effectiveness
        reminder_with = logs_period.filter(habit__reminder_enabled=True)
        reminder_without = logs_period.filter(habit__reminder_enabled=False)
        reminder_with_total = reminder_with.count()
        reminder_without_total = reminder_without.count()
        reminder_with_completed = reminder_with.filter(status='completed').count()
        reminder_without_completed = reminder_without.filter(status='completed').count()

        campaign_qs = NotificationCampaign.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date,
        )
        campaign_summary = {
            'campaigns_sent': campaign_qs.filter(status='sent').count(),
            'avg_delivery_rate': round(
                campaign_qs.aggregate(avg=Avg('delivered_count')).get('avg') or 0.0,
                1,
            ),
            'avg_open_rate': round(
                campaign_qs.aggregate(
                    avg=Avg(
                        F('opened_count') * 100.0 / (F('delivered_count') + 0.0001)
                    )
                ).get('avg') or 0.0,
                1,
            ),
        }
        reminder_notifications = Notification.objects.filter(
            notification_type='reminder',
            created_at__date__gte=start_date,
            created_at__date__lte=end_date,
        )
        reminder_read = reminder_notifications.filter(status='read').count()
        reminder_total = reminder_notifications.count()

        # System usage reports
        api_usage_raw = (
            AuditLog.objects.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(count=Count('id'))
            .order_by('day')
        )
        api_usage_map = {row['day']: row['count'] for row in api_usage_raw}
        api_usage_trend = AnalyticsService._daily_series(start_date, end_date, api_usage_map)

        login_sessions = LoginSession.objects.filter(logged_in_at__date__lte=end_date)
        if segment and segment.lower() != 'all':
            login_sessions = login_sessions.filter(user__in=users_qs)

        platform_breakdown = list(
            login_sessions.values('platform').annotate(count=Count('id')).order_by('-count')
        )
        if not platform_breakdown:
            platform_breakdown = list(
                LoginActivity.objects.filter(login_at__date__gte=start_date, login_at__date__lte=end_date)
                .values('device_type')
                .annotate(count=Count('id'))
                .order_by('-count')
            )
            platform_breakdown = [
                {'platform': row['device_type'] or 'unknown', 'count': row['count']}
                for row in platform_breakdown
            ]

        hourly_activity = [
            {'hour': hour, 'count': count}
            for hour, count in enumerate(hour_data)
        ]
        peak_activity = sorted(hourly_activity, key=lambda row: row['count'], reverse=True)[:5]

        # Comparison block
        dau_previous = users_qs.filter(last_login__date=previous_end).count()
        comparison = {
            'current_period': {
                'completion_rate': period_rate,
                'completed_logs': period_completed,
                'active_users': dau,
                'new_users': users_qs.filter(created_at__date__gte=start_date, created_at__date__lte=end_date).count(),
            },
            'previous_period': {
                'completion_rate': previous_rate,
                'completed_logs': previous_completed,
                'active_users': dau_previous,
                'new_users': users_qs.filter(created_at__date__gte=previous_start, created_at__date__lte=previous_end).count(),
            },
            'delta': {
                'completion_rate': round(period_rate - previous_rate, 1),
                'completed_logs': period_completed - previous_completed,
                'active_users': dau - dau_previous,
            },
        }

        # AI-driven summaries + simple predictive trend
        trend_direction = 'increased' if completion_rate_change >= 0 else 'decreased'
        projected_rate = max(0.0, min(100.0, round(period_rate + (completion_rate_change * 0.6), 1)))
        ai_summary = [
            f'Completion rate {trend_direction} by {abs(completion_rate_change)}% versus the previous period.',
            f'DAU is {dau} and MAU is {mau}, with churn estimated at {churn_rate}%.',
            f'Users with reminders show a {AnalyticsService._safe_div(reminder_with_completed, reminder_with_total)}% completion rate.',
        ]

        return {
            'filters': {
                'days': days,
                'compare_days': compare_window,
                'category': category,
                'segment': segment,
                'date_from': start_date.isoformat(),
                'date_to': end_date.isoformat(),
            },
            'user_growth_engagement': {
                'registrations_over_time': growth_series,
                'active_users': {'dau': dau, 'wau': wau, 'mau': mau},
                'retention': retention,
                'churn_rate': churn_rate,
            },
            'habit_performance': {
                'most_completed_habits': ranked[:8],
                'least_completed_habits': list(reversed(ranked[-8:] if ranked else [])),
                'category_performance': category_performance,
                'completion_trend': completion_trend,
                'consistency_heatmap': heatmap_cells,
            },
            'behavioral_insights': {
                'time_of_day_pattern': hour_pattern,
                'day_of_week_pattern': day_pattern,
                'success_vs_failure': status_breakdown,
                'behavior_clusters': [
                    {'cluster': key, 'users': value}
                    for key, value in clusters.items()
                ],
            },
            'notification_effectiveness': {
                'with_reminders': {
                    'completed': reminder_with_completed,
                    'total': reminder_with_total,
                    'completion_rate': AnalyticsService._safe_div(reminder_with_completed, reminder_with_total),
                },
                'without_reminders': {
                    'completed': reminder_without_completed,
                    'total': reminder_without_total,
                    'completion_rate': AnalyticsService._safe_div(reminder_without_completed, reminder_without_total),
                },
                'campaign_summary': campaign_summary,
                'reminder_read_rate': AnalyticsService._safe_div(reminder_read, reminder_total),
            },
            'system_usage': {
                'api_usage_trend': api_usage_trend,
                'peak_activity_hours': peak_activity,
                'hourly_activity': hourly_activity,
                'platform_breakdown': platform_breakdown,
            },
            'advanced_reporting': {
                'comparison': comparison,
                'export_formats': ['csv', 'pdf'],
            },
            'ai_insights': {
                'auto_summary': ai_summary,
                'predicted_next_period_completion_rate': projected_rate,
            },
        }
