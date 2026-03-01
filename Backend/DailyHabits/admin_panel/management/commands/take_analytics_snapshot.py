"""
Management command: take_analytics_snapshot
============================================
Captures today's platform metrics into PlatformAnalyticsSnapshot.
Should be run daily via cron or Celery Beat.

Usage:
    python manage.py take_analytics_snapshot
"""

from django.core.management.base import BaseCommand

from admin_panel.services import AnalyticsService


class Command(BaseCommand):
    help = 'Capture daily platform analytics snapshot.'

    def handle(self, *args, **options):
        snapshot = AnalyticsService.take_daily_snapshot()
        self.stdout.write(self.style.SUCCESS(
            f'Snapshot for {snapshot.date}: '
            f'{snapshot.total_users} users, '
            f'{snapshot.daily_active_users} DAU, '
            f'{snapshot.average_completion_rate}% completion'
        ))
