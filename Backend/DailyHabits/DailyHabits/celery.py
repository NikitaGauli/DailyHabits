"""
Celery Configuration — DailyHabits Project
===========================================

Configures the Celery distributed task queue for asynchronous and periodic
background tasks, including:
    - Scheduled habit reminder notifications
    - Streak-at-risk alerts
    - Challenge deadline notifications
    - Stale device-token cleanup

The default broker is **Redis**. In development, Celery runs as a separate
process alongside the Django dev server::

    celery -A DailyHabits worker --loglevel=info
    celery -A DailyHabits beat --loglevel=info

Settings Reference:
    https://docs.celeryq.dev/en/stable/userguide/configuration.html
"""

import os

from celery import Celery
from celery.schedules import crontab

# Ensure the Django settings module is available to Celery workers.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

app = Celery('DailyHabits')

# Pull configuration from Django settings, using the CELERY_ namespace.
# e.g. CELERY_BROKER_URL in settings.py → broker_url in Celery.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Auto-discover tasks.py in every installed Django app.
app.autodiscover_tasks()

# =============================================================================
#  PERIODIC TASK SCHEDULE (Celery Beat)
# =============================================================================

app.conf.beat_schedule = {
    # Check and send habit reminders every minute
    'send-habit-reminders': {
        'task': 'notifications.tasks.send_habit_reminders',
        'schedule': 60.0,  # Every 60 seconds
    },

    # Check for streaks at risk — twice daily (morning and evening)
    'check-streak-risks-morning': {
        'task': 'notifications.tasks.check_streak_risks',
        'schedule': crontab(hour=8, minute=0),
    },
    'check-streak-risks-evening': {
        'task': 'notifications.tasks.check_streak_risks',
        'schedule': crontab(hour=20, minute=0),
    },

    # Check challenges nearing deadline — daily at 9 AM
    'check-challenge-deadlines': {
        'task': 'notifications.tasks.check_challenge_deadlines',
        'schedule': crontab(hour=9, minute=0),
    },

    # Send missed-habit alerts — daily at 10 PM
    'send-missed-habit-alerts': {
        'task': 'notifications.tasks.send_missed_habit_alerts',
        'schedule': crontab(hour=22, minute=0),
    },

    # Persist missed-day logs shortly after midnight
    'track-missed-habits': {
        'task': 'notifications.tasks.track_missed_habits',
        'schedule': crontab(hour=0, minute=10),
    },

    # Run ML-based habit clustering weekly on Monday at 6 AM
    'run-weekly-habit-analysis': {
        'task': 'recommendation_engine.tasks.run_weekly_habit_analysis',
        'schedule': crontab(hour=6, minute=0, day_of_week='monday'),
    },
}

app.conf.timezone = 'Asia/Kathmandu'  # type: ignore[assignment]
