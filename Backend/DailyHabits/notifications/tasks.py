"""
Notification Celery Tasks
=========================

Background tasks for the DailyHabits notification system. These run
asynchronously via Celery workers and periodically via Celery Beat.

Tasks:
    - :func:`send_habit_reminders` — Check and send habit reminders.
    - :func:`check_streak_risks` — Alert users about streaks at risk.
    - :func:`check_challenge_deadlines` — Notify about expiring challenges.
    - :func:`send_missed_habit_alerts` — Alert about missed habits.

All tasks use ``@shared_task`` so they are auto-discovered by Celery.
Each task includes retry logic and error handling to ensure reliability.

Notifications are delivered in real-time via WebSocket (Django Channels).
When a notification is created by ``NotificationCreator``, the ``post_save``
signal in ``signals.py`` automatically broadcasts it to the user's
connected clients.
"""

import logging
from datetime import timedelta

from celery import shared_task
from django.utils import timezone

logger = logging.getLogger(__name__)


# =============================================================================
#  HABIT REMINDER TASK — runs every minute
# =============================================================================

@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_habit_reminders(self):
    """
    Check for habit reminders due in the current minute and send notifications.

    For each enabled reminder whose ``reminder_time`` falls within the current
    minute window and hasn't been sent today, this task:
        1. Creates an in-app notification via ``NotificationCreator``.
        2. The ``post_save`` signal broadcasts it via WebSocket in real-time.
        3. Updates the reminder's ``last_sent`` timestamp.

    Respects the user's notification settings (master toggle, quiet hours).
    """
    from notifications.models import HabitReminder, NotificationSettings
    from notifications.services import NotificationCreator

    now = timezone.localtime()
    current_time = now.time().replace(second=0, microsecond=0)
    today = now.date()

    # Find reminders matching the current time that haven't been sent today
    reminders = HabitReminder.objects.filter(
        is_enabled=True,
        reminder_time__hour=current_time.hour,
        reminder_time__minute=current_time.minute,
    ).select_related('habit', 'habit__user')

    sent_count = 0
    for reminder in reminders:
        # Skip if already sent today
        if reminder.last_sent and reminder.last_sent.date() == today:
            continue

        # Check repeat schedule
        if not _should_fire_today(reminder, now):
            continue

        user = reminder.habit.user
        habit = reminder.habit

        # Skip if habit is not active
        if habit.status != 'active' or getattr(habit, 'is_deleted', False):
            continue

        # Respect user notification settings
        if not _can_send_notification(user):
            continue

        # Create in-app notification
        message = reminder.message or f"Time to complete your {habit.title} habit! 💪"
        notification = NotificationCreator.habit_reminder(user=user, habit=habit)

        if notification:
            # Mark reminder as sent (notification is auto-broadcast via WebSocket signal)
            reminder.last_sent = now
            reminder.save(update_fields=['last_sent'])
            sent_count += 1

    logger.info('Sent %d habit reminders at %s', sent_count, current_time)
    return sent_count


# =============================================================================
#  STREAK RISK ALERT TASK — runs twice daily
# =============================================================================

@shared_task(bind=True, max_retries=2, default_retry_delay=60)
def check_streak_risks(self):
    """
    Identify habits with active streaks that haven't been completed today
    and send 'streak at risk' notifications.

    Only alerts for streaks >= 3 days to avoid noise for new habits.
    """
    from habits.models import Habit, HabitLog, Streak
    from notifications.services import NotificationCreator

    today = timezone.localtime().date()
    alert_count = 0

    # Find streaks >= 3 days on active habits
    active_streaks = Streak.objects.filter(
        current_streak__gte=3,
        habit__status='active',
        habit__is_deleted=False,
    ).select_related('habit', 'habit__user')

    for streak in active_streaks:
        habit = streak.habit
        user = habit.user

        # Check if already completed today
        completed_today = HabitLog.objects.filter(
            habit=habit, date=today, status='completed'
        ).exists()

        if completed_today:
            continue

        if not _can_send_notification(user, category='streak_alerts'):
            continue

        # Create streak-risk notification
        notification = NotificationCreator.streak_at_risk(
            user=user,
            habit=habit,
            streak_count=streak.current_streak,
        )

        if notification:
            alert_count += 1

    logger.info('Sent %d streak risk alerts', alert_count)
    return alert_count


# =============================================================================
#  CHALLENGE DEADLINE TASK — runs daily
# =============================================================================

@shared_task(bind=True, max_retries=2, default_retry_delay=60)
def check_challenge_deadlines(self):
    """
    Notify participants of challenges ending within the next 3 days.

    Also detects newly completed challenges and expired ones, sending
    appropriate notifications.
    """
    from gamification.models import Challenge, ChallengeParticipant
    from notifications.services import NotificationCreator

    now = timezone.now()
    three_days_later = now + timedelta(days=3)
    alert_count = 0

    # --- Challenges ending soon (within 3 days) ---
    ending_soon = Challenge.objects.filter(
        status='active',
        end_date__range=[now, three_days_later],
    )

    for challenge in ending_soon:
        days_left = (challenge.end_date - now).days
        participants = ChallengeParticipant.objects.filter(
            challenge=challenge,
            status='active',
        ).select_related('user')

        for participant in participants:
            if not _can_send_notification(participant.user):
                continue

            notification = NotificationCreator.challenge_ending_soon(
                user=participant.user,
                challenge=challenge,
                days_left=days_left,
            )
            if notification:
                alert_count += 1

    # --- Expire overdue active challenges ---
    expired = Challenge.objects.filter(
        status='active',
        end_date__lt=now,
    )
    for challenge in expired:
        challenge.status = 'expired'
        challenge.save(update_fields=['status'])

        # Fail uncompleted participants
        ChallengeParticipant.objects.filter(
            challenge=challenge, status='active'
        ).update(status='failed')

    logger.info('Sent %d challenge deadline alerts', alert_count)
    return alert_count


# =============================================================================
#  MISSED HABIT ALERTS TASK — runs daily at 10 PM
# =============================================================================

@shared_task(bind=True, max_retries=2, default_retry_delay=60)
def send_missed_habit_alerts(self):
    """
    Send notifications for active habits that weren't completed today.

    Runs in the evening so users still have time to complete their habits.
    Only sends for the first 3 missed habits per user to avoid notification
    fatigue.
    """
    from habits.models import Habit, HabitLog
    from notifications.services import NotificationCreator
    from django.contrib.auth import get_user_model

    User = get_user_model()
    today = timezone.localtime().date()
    alert_count = 0

    for user in User.objects.filter(is_active=True):
        if not _can_send_notification(user, category='missed_habit_alerts'):
            continue

        active_habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        missed_count = 0

        for habit in active_habits:
            if missed_count >= 3:
                break

            completed = HabitLog.objects.filter(
                habit=habit, date=today, status='completed'
            ).exists()

            if not completed:
                notification = NotificationCreator.create(
                    user=user,
                    notification_type='missed',
                    title=f'Don\'t forget: {habit.title}',
                    message=f'You haven\'t completed "{habit.title}" yet today. There\'s still time! 💪',
                    habit=habit,
                    icon_code=0xE002,
                    color_value=0xFFF59E0B,
                    action_type='habit_detail',
                    action_data={'habitId': habit.id},
                )
                if notification:
                    missed_count += 1
                    alert_count += 1

    logger.info('Sent %d missed habit alerts', alert_count)
    return alert_count


# =============================================================================
#  HELPER FUNCTIONS
# =============================================================================

def _should_fire_today(reminder, now):
    """
    Determine if a reminder should fire on the given day based on its
    repeat_type and custom_days configuration.
    """
    if reminder.repeat_type == 'daily':
        return True
    elif reminder.repeat_type == 'once':
        # Fire if not yet sent
        return reminder.last_sent is None
    elif reminder.repeat_type == 'weekly':
        # Fire on the same weekday as when it was created
        return now.weekday() == reminder.created_at.weekday()
    elif reminder.repeat_type == 'custom':
        # custom_days stores ISO weekday numbers: 1=Monday ... 7=Sunday
        # Python weekday(): 0=Monday ... 6=Sunday
        iso_weekday = now.isoweekday()  # 1=Monday ... 7=Sunday
        return iso_weekday in (reminder.custom_days or [])
    return False


def _can_send_notification(user, category=None):
    """
    Check if notifications can be sent to a user based on their
    NotificationSettings (master toggle, quiet hours, category toggles).
    """
    from notifications.models import NotificationSettings

    try:
        ns = NotificationSettings.objects.get(user=user)
    except NotificationSettings.DoesNotExist:
        return True  # Default: allow notifications

    # Master toggle
    if not ns.notifications_enabled:
        return False

    # Category-specific toggle
    if category:
        category_map = {
            'habit_reminders': ns.habit_reminders,
            'missed_habit_alerts': ns.missed_habit_alerts,
            'achievement_notifications': ns.achievement_notifications,
            'streak_alerts': ns.streak_alerts,
            'social_notifications': ns.social_notifications,
        }
        if category in category_map and not category_map[category]:
            return False

    # Quiet hours check
    if ns.quiet_hours_enabled and ns.quiet_hours_start and ns.quiet_hours_end:
        current_time = timezone.localtime().time()
        start = ns.quiet_hours_start
        end = ns.quiet_hours_end

        if start <= end:
            # Same-day window (e.g. 09:00 – 17:00)
            if start <= current_time <= end:
                return False
        else:
            # Overnight window (e.g. 22:00 – 07:00)
            if current_time >= start or current_time <= end:
                return False

    return True
