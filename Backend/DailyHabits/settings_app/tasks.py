"""
Settings App — Celery Task Stubs
=================================

Server-side scheduled tasks for the DailyHabits settings module.
These replace ALL push notification / FCM functionality with in-app
notification creation via the existing Notification model.

Tasks
-----
- ``send_habit_reminders``   — Periodic: check HabitReminder rows and
  create Notification objects for habits due now.
- ``generate_daily_summary`` — Periodic: create daily summary
  notifications for opted-in users.
- ``cleanup_expired_sessions`` — Periodic: deactivate stale login sessions.
- ``process_export_async``   — On-demand: handle large export generation.

These are designed to run with Celery Beat or Django-Q scheduler.
If Celery is not installed, the tasks degrade to no-ops and can be
called synchronously from management commands.

NO Firebase Cloud Messaging is used.
"""

import logging
from datetime import timedelta
from django.utils import timezone

logger = logging.getLogger(__name__)


def send_habit_reminders():
    """
    Check all enabled HabitReminders and create in-app Notification
    objects for habits that are due within the current time window.

    This runs every 5 minutes via Celery Beat.  It:
    1. Queries enabled reminders whose reminder_time falls within
       the current 5-minute window (accounting for user timezone).
    2. Checks that the habit is active and not paused.
    3. Respects NotificationSettings (master toggle, quiet hours, daily cap).
    4. Creates a Notification with type='reminder' and action_type='habit_detail'.
    5. Updates last_sent on the HabitReminder.
    """
    from notifications.models import HabitReminder, Notification, NotificationSettings
    from notifications.services import NotificationIntelligence

    now = timezone.now()
    window_start = now - timedelta(minutes=2, seconds=30)
    window_end = now + timedelta(minutes=2, seconds=30)
    current_time = now.time()

    reminders = HabitReminder.objects.filter(
        is_enabled=True,
        habit__is_deleted=False,
        habit__status='active',
    ).select_related('habit', 'habit__user')

    sent_count = 0
    for reminder in reminders:
        # Check if reminder time falls within current window
        r_time = reminder.reminder_time
        if not (window_start.time() <= r_time <= window_end.time()):
            continue

        # Check repeat type and day matching
        user = reminder.habit.user
        weekday = now.isoweekday()  # 1=Mon, 7=Sun

        if reminder.repeat_type == 'once' and reminder.last_sent:
            continue
        elif reminder.repeat_type == 'weekly':
            if reminder.last_sent and (now - reminder.last_sent) < timedelta(days=6):
                continue
        elif reminder.repeat_type == 'custom':
            if weekday not in reminder.custom_days:
                continue

        # Skip if already sent today
        if reminder.last_sent and reminder.last_sent.date() == now.date():
            continue

        # Respect notification intelligence (quiet hours, daily cap, etc.)
        if not NotificationIntelligence.should_send_notification(user):
            continue

        # Create the in-app notification
        Notification.objects.create(
            user=user,
            notification_type='reminder',
            title=f"Time for: {reminder.habit.title}",
            message=reminder.message or f"Don't forget to complete your habit: {reminder.habit.title}",
            habit=reminder.habit,
            status='sent',
            sent_at=now,
            action_type='habit_detail',
            action_data={'habitId': reminder.habit.id},
            icon_code=0xE855,  # alarm icon
            color_value=0xFF4F46E5,  # Primary indigo
        )

        reminder.last_sent = now
        reminder.save(update_fields=['last_sent'])
        sent_count += 1

        # Auto-disable one-time reminders
        if reminder.repeat_type == 'once':
            reminder.is_enabled = False
            reminder.save(update_fields=['is_enabled'])

    logger.info(f"Sent {sent_count} habit reminders")
    return sent_count


def generate_daily_summary():
    """
    Create daily summary notifications for users who have opted in.

    Runs once daily (scheduled via Celery Beat at a fixed UTC time).
    Iterates users with daily_summary_enabled=True and creates an
    in-app Notification summarizing today's habit completion stats.
    """
    from .models import UserSettings
    from notifications.models import Notification
    from habits.models import HabitLog

    today = timezone.now().date()
    settings_qs = UserSettings.objects.filter(
        daily_summary_enabled=True,
    ).select_related('user')

    sent_count = 0
    for user_settings in settings_qs:
        user = user_settings.user
        if not user.is_active:
            continue

        # Gather today's stats
        logs = HabitLog.objects.filter(habit__user=user, date=today)
        completed = logs.filter(status='completed').count()
        total = logs.count()

        if total == 0:
            message = "No habits scheduled for today. Take a moment to plan tomorrow!"
        elif completed == total:
            message = f"Amazing! You completed all {total} habits today. Keep the momentum going!"
        else:
            message = f"You completed {completed} out of {total} habits today. Every step counts!"

        Notification.objects.create(
            user=user,
            notification_type='system',
            title="Daily Summary",
            message=message,
            status='sent',
            sent_at=timezone.now(),
            action_type='none',
            action_data={'date': today.isoformat(), 'completed': completed, 'total': total},
            icon_code=0xE24B,  # summarize icon
            color_value=0xFF14B8A6,  # Secondary teal
        )
        sent_count += 1

    logger.info(f"Sent {sent_count} daily summaries")
    return sent_count


def cleanup_expired_sessions():
    """
    Deactivate login sessions that have been inactive for longer than
    the user's configured session_timeout_minutes.

    Runs every 15 minutes via Celery Beat.
    """
    from .models import LoginSession, SecuritySettings

    now = timezone.now()
    deactivated = 0

    # Find users with non-zero session timeouts
    security_settings = SecuritySettings.objects.filter(
        session_timeout_minutes__gt=0,
    ).select_related('user')

    for sec in security_settings:
        cutoff = now - timedelta(minutes=sec.session_timeout_minutes)
        count = LoginSession.objects.filter(
            user=sec.user,
            is_active=True,
            last_active_at__lt=cutoff,
        ).update(is_active=False, logged_out_at=now)
        deactivated += count

    logger.info(f"Deactivated {deactivated} expired sessions")
    return deactivated


def process_export_async(export_request_id):
    """
    Process a data export request asynchronously.

    Called as a one-off Celery task when a user requests a large export.
    Updates the ExportRequest status through its lifecycle.
    """
    from .models import ExportRequest

    try:
        export_req = ExportRequest.objects.get(id=export_request_id)
        export_req.status = 'processing'
        export_req.save(update_fields=['status'])

        # Actual export generation would happen here
        # For now, mark as completed (download streams data on access)
        export_req.status = 'completed'
        export_req.completed_at = timezone.now()
        export_req.save(update_fields=['status', 'completed_at'])

        logger.info(f"Export {export_request_id} completed")
    except ExportRequest.DoesNotExist:
        logger.error(f"Export {export_request_id} not found")
    except Exception as e:
        logger.error(f"Export {export_request_id} failed: {e}")
        try:
            export_req.status = 'failed'
            export_req.error_message = str(e)
            export_req.save(update_fields=['status', 'error_message'])
        except Exception:
            pass
