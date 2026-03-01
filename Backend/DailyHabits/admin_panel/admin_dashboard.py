"""
admin_panel/admin_dashboard.py — Custom Admin Dashboard View
=============================================================
Provides a data-rich dashboard home page for the Django admin,
powered by AnalyticsService aggregation queries and Chart.js
visualisations.

This module patches ``django.contrib.admin.site`` at import time
so all existing ``@admin.register()`` decorators across the project
continue to work without modification.
"""

import json
import logging
from datetime import timedelta

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.template.response import TemplateResponse
from django.utils import timezone

from habits.models import Habit, HabitLog, Streak
from .models import (
    AuditLog, FeatureFlag, ContentModerationQueue, UserWarning,
)

logger = logging.getLogger('admin_panel')
User = get_user_model()


def get_dashboard_context() -> dict:
    """Build the analytics context dict for the admin index page."""
    # Lazy import to avoid circular import at module level
    from .services import AnalyticsService

    ctx: dict = {}
    try:
        today = timezone.now().date()
        week_ago = today - timedelta(days=7)

        # ── KPI Cards ─────────────────────────────────────────────
        overview = AnalyticsService.get_overview_stats()
        ctx['overview'] = overview

        # ── Growth chart data (last 30 days) ──────────────────────
        growth = AnalyticsService.get_growth_trends(days=30)
        ctx['growth_labels'] = json.dumps([str(d['date']) for d in growth])
        ctx['growth_new_users'] = json.dumps([d['new_users'] for d in growth])
        ctx['growth_active_users'] = json.dumps(
            [d['daily_active_users'] for d in growth]
        )

        # ── Engagement & retention ────────────────────────────────
        ctx['engagement'] = AnalyticsService.get_engagement_metrics(days=30)
        ctx['retention'] = AnalyticsService.get_retention_metrics()

        # ── Habit status distribution (pie chart) ─────────────────
        status_dist = (
            HabitLog.objects.filter(date__gte=week_ago)
            .values('status')
            .annotate(count=Count('id'))
            .order_by('status')
        )
        ctx['status_labels'] = json.dumps(
            [s['status'].capitalize() for s in status_dist]
        )
        ctx['status_values'] = json.dumps([s['count'] for s in status_dist])

        # ── Top categories (bar chart) ────────────────────────────
        top_cats = (
            Habit.objects.filter(is_deleted=False)
            .values('category_name')
            .annotate(count=Count('id'))
            .order_by('-count')[:8]
        )
        ctx['category_labels'] = json.dumps(
            [c['category_name'] or 'Uncategorised' for c in top_cats]
        )
        ctx['category_values'] = json.dumps([c['count'] for c in top_cats])

        # ── Recent audit log ──────────────────────────────────────
        ctx['recent_audit_logs'] = (
            AuditLog.objects.select_related('admin_user')
            .order_by('-created_at')[:10]
        )

        # ── Moderation & flags ────────────────────────────────────
        ctx['pending_moderation'] = (
            ContentModerationQueue.objects.filter(status='pending').count()
        )
        ctx['unresolved_warnings'] = (
            UserWarning.objects.filter(acknowledged=False).count()
        )
        ctx['total_feature_flags'] = FeatureFlag.objects.count()
        ctx['enabled_feature_flags'] = (
            FeatureFlag.objects.filter(is_enabled=True).count()
        )

        # ── Top streaks ───────────────────────────────────────────
        ctx['top_streaks'] = (
            Streak.objects.select_related('habit', 'habit__user')
            .filter(current_streak__gt=0)
            .order_by('-current_streak')[:5]
        )

        # ── Recent signups ────────────────────────────────────────
        ctx['recent_users'] = User.objects.order_by('-created_at')[:5]

        # ── Streak distribution for bar chart ─────────────────────
        streak_ranges = [
            ('1-3', Q(current_streak__gte=1, current_streak__lte=3)),
            ('4-7', Q(current_streak__gte=4, current_streak__lte=7)),
            ('8-14', Q(current_streak__gte=8, current_streak__lte=14)),
            ('15-30', Q(current_streak__gte=15, current_streak__lte=30)),
            ('31+', Q(current_streak__gte=31)),
        ]
        ctx['streak_labels'] = json.dumps([r[0] for r in streak_ranges])
        ctx['streak_values'] = json.dumps(
            [Streak.objects.filter(q).count() for _, q in streak_ranges]
        )

        # ── Completion rate trend (last 14 days) ──────────────────
        cr_labels: list[str] = []
        cr_values: list[float] = []
        for i in range(13, -1, -1):
            d = today - timedelta(days=i)
            cr_labels.append(str(d))
            day_logs = HabitLog.objects.filter(date=d)
            total = day_logs.count()
            completed = day_logs.filter(status='completed').count()
            cr_values.append(
                round(completed / total * 100, 1) if total else 0.0
            )
        ctx['cr_labels'] = json.dumps(cr_labels)
        ctx['cr_values'] = json.dumps(cr_values)

    except Exception:
        logger.exception('Dashboard analytics context failed')

    return ctx


def configure_admin_site() -> None:
    """
    Patch the default admin.site with DailyHabits branding
    and register a custom index view that injects analytics context.
    """
    admin.site.site_header = 'DailyHabits Super Admin'
    admin.site.site_title = 'DailyHabits Admin'
    admin.site.index_title = 'Platform Control Center'

    # Store the original index method
    _original_index = admin.AdminSite.index

    def custom_index(self, request, extra_context=None):
        extra_context = extra_context or {}
        extra_context.update(get_dashboard_context())
        return _original_index(self, request, extra_context=extra_context)

    # Monkey-patch the index method
    admin.AdminSite.index = custom_index
