"""
Management command: ``send_reminders``
======================================

Standalone runner that executes the same logic as the Celery scheduled tasks,
but without requiring a Celery worker or Redis broker. Useful for:

    * Local development without Redis
    * One-shot execution via cron / Windows Task Scheduler
    * Debugging notification delivery

Usage::

    # Run all scheduled notification checks once
    python manage.py send_reminders

    # Run only a specific task
    python manage.py send_reminders --task habit_reminders
    python manage.py send_reminders --task streak_risks
    python manage.py send_reminders --task challenge_deadlines
    python manage.py send_reminders --task missed_habits
    python manage.py send_reminders --task cleanup_tokens
"""

from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Run notification scheduled tasks without Celery'

    TASK_MAP = {
        'habit_reminders': 'notifications.tasks.send_habit_reminders',
        'streak_risks': 'notifications.tasks.check_streak_risks',
        'challenge_deadlines': 'notifications.tasks.check_challenge_deadlines',
        'missed_habits': 'notifications.tasks.send_missed_habit_alerts',
        'cleanup_tokens': 'notifications.tasks.cleanup_stale_device_tokens',
    }

    def add_arguments(self, parser):
        parser.add_argument(
            '--task',
            type=str,
            choices=list(self.TASK_MAP.keys()),
            help='Run a specific task instead of all tasks.',
        )

    def handle(self, *args, **options):
        from notifications.tasks import (
            send_habit_reminders,
            check_streak_risks,
            check_challenge_deadlines,
            send_missed_habit_alerts,
            cleanup_stale_device_tokens,
        )

        all_tasks = {
            'habit_reminders': send_habit_reminders,
            'streak_risks': check_streak_risks,
            'challenge_deadlines': check_challenge_deadlines,
            'missed_habits': send_missed_habit_alerts,
            'cleanup_tokens': cleanup_stale_device_tokens,
        }

        chosen = options.get('task')
        tasks_to_run = {chosen: all_tasks[chosen]} if chosen else all_tasks

        for name, func in tasks_to_run.items():
            self.stdout.write(self.style.NOTICE(f'Running: {name}'))
            try:
                func()
                self.stdout.write(self.style.SUCCESS(f'  ✓ {name} completed'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  ✗ {name} failed: {e}'))
