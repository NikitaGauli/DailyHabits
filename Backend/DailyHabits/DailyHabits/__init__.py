"""
DailyHabits Project — Package Init
====================================

Imports the Celery app on Django startup so that ``@shared_task``
decorators in all installed apps are automatically registered with
the Celery worker.

See Also:
    - DailyHabits/celery.py — Celery application configuration.
"""

# Import the Celery app so it is always available when Django starts.
# This ensures that shared_task will use this app.
# Graceful fallback: if Celery is not installed, skip — the project
# still runs without background tasks (use management commands instead).
try:
    from .celery import app as celery_app
    __all__ = ('celery_app',)
except ImportError:
    celery_app = None
    __all__ = ()
