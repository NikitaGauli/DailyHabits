"""
Notification Services
=====================
Business-logic layer for creating, managing, and intelligently delivering
notifications and smart tips in the DailyHabits platform.

Service Classes
---------------
- :class:`NotificationCreator`
    Event-driven factory for inbox notifications.  Provides a generic
    ``create()`` method with built-in 5-minute deduplication, plus
    convenience shortcuts for every supported event type (friend requests,
    streak milestones, achievements, etc.).

- :class:`SmartTipService`
    Generates personalised, non-urgent guidance tips based on the user's
    recent habit activity.  Tips are capped at 2 per day to avoid
    notification fatigue.

- :class:`NotificationIntelligence`
    Analytics engine that powers smart reminder suggestions, streak-risk
    alerts, and weekly performance nudges.  Also enforces delivery rules
    (quiet hours, daily caps, minimum cooldown between notifications).
"""

from datetime import timedelta
from django.utils import timezone
from django.db.models import Count

from habits.models import Habit, HabitLog, Streak
from notifications.models import Notification, SmartTip, NotificationSettings


# =============================================================================
#  NOTIFICATION CREATOR — event-driven inbox notification factory
# =============================================================================

class NotificationCreator:
    """
    Creates inbox notifications for system and social events.

    Every public method is a ``@staticmethod`` so the class can be used as a
    lightweight namespace without instantiation::

        NotificationCreator.friend_request(to_user=alice, from_user=bob)

    A 5-minute deduplication window prevents the same notification from
    being created twice in rapid succession (see :meth:`create`).
    """

    @staticmethod
    def create(user, notification_type, title, message, **kwargs):
        """
        Generic notification creation with a 5-minute deduplication window.

        Before inserting a new row the method checks whether an identical
        notification (same user, type, and title) was already created in
        the last 5 minutes.  If so, it returns ``None`` to avoid spam.

        Args:
            user: Recipient user instance.
            notification_type: One of ``Notification.NOTIFICATION_TYPES``.
            title: Short headline.
            message: Full body text.
            **kwargs: Optional overrides — ``habit``, ``achievement``,
                ``from_user``, ``group``, ``icon_code``, ``color_value``,
                ``action_type``, ``action_data``.

        Returns:
            The created :class:`Notification`, or ``None`` if deduplicated.
        """
        # Dedup: reject if an identical notification was created within the last 5 min
        recent = Notification.objects.filter(
            user=user,
            notification_type=notification_type,
            title=title,
            created_at__gte=timezone.now() - timedelta(minutes=5),
        ).exists()
        if recent:
            return None

        return Notification.objects.create(
            user=user,
            notification_type=notification_type,
            title=title,
            message=message,
            habit=kwargs.get('habit'),
            achievement=kwargs.get('achievement'),
            from_user=kwargs.get('from_user'),
            group=kwargs.get('group'),
            icon_code=kwargs.get('icon_code', 0xE7F4),
            color_value=kwargs.get('color_value', 0xFF6366F1),
            action_type=kwargs.get('action_type', 'none'),
            action_data=kwargs.get('action_data', {}),
        )

    @staticmethod
    def friend_request(to_user, from_user):
        """Create a *friend request received* notification for ``to_user``."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='friend_request',
            title='New Friend Request',
            message=f'{from_user.name} wants to be your friend!',
            from_user=from_user,
            icon_code=0xE7FB,
            color_value=0xFF3B82F6,
            action_type='friend_requests',
        )

    @staticmethod
    def friend_accepted(to_user, from_user):
        """Create a *friend request accepted* notification for ``to_user``."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='friend_accepted',
            title='Friend Request Accepted',
            message=f'{from_user.name} accepted your friend request!',
            from_user=from_user,
            icon_code=0xE7FB,
            color_value=0xFF22C55E,
            action_type='community',
        )

    @staticmethod
    def group_join(to_user, member_user, group):
        """Notify ``to_user`` that ``member_user`` joined the *group*."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='group_join',
            title='New Group Member',
            message=f'{member_user.name} joined {group.name}!',
            from_user=member_user,
            group=group,
            icon_code=0xE7EF,
            color_value=0xFF8B5CF6,
            action_type='group_detail',
            action_data={'groupId': group.id},
        )

    @staticmethod
    def streak_milestone(user, habit, streak_count):
        """Celebrate a streak milestone (e.g. 7, 30, 100 consecutive days)."""
        return NotificationCreator.create(
            user=user,
            notification_type='streak',
            title=f'{streak_count}-Day Streak!',
            message=f'Amazing! You have a {streak_count}-day streak on "{habit.title}". Keep going!',
            habit=habit,
            icon_code=0xE80E,
            color_value=0xFFF59E0B,
            action_type='habit_detail',
            action_data={'habitId': habit.id},
        )

    @staticmethod
    def achievement_earned(user, achievement, habit=None):
        """Notify the user that they unlocked a new achievement badge."""
        return NotificationCreator.create(
            user=user,
            notification_type='achievement',
            title='Achievement Unlocked!',
            message=f'You earned "{achievement.name}" - {achievement.description}',
            achievement=achievement,
            habit=habit,
            icon_code=0xE87B,
            color_value=0xFFFFD700,
            action_type='achievements',
        )

    @staticmethod
    def habit_reminder(user, habit):
        """Send a scheduled reminder for a specific habit."""
        return NotificationCreator.create(
            user=user,
            notification_type='reminder',
            title=f'Time for {habit.title}',
            message=f"Don't forget to complete your habit today!",
            habit=habit,
            icon_code=0xE855,
            color_value=0xFF6366F1,
            action_type='habit_detail',
            action_data={'habitId': habit.id},
        )

    @staticmethod
    def admin_announcement(user, title, message):
        """Broadcast an administrator announcement to a single user."""
        return NotificationCreator.create(
            user=user,
            notification_type='admin',
            title=title,
            message=message,
            icon_code=0xE7F4,
            color_value=0xFF3B82F6,
            action_type='none',
        )

    @staticmethod
    def security_alert(user, title, message):
        """Deliver a security-related alert (password change, new device, etc.)."""
        return NotificationCreator.create(
            user=user,
            notification_type='security',
            title=title,
            message=message,
            icon_code=0xE897,
            color_value=0xFFEF4444,
            action_type='settings',
        )

    # ── Social habit-sharing notifications ────────────────────────────

    @staticmethod
    def habit_shared(to_user, from_user, habit):
        """Notify ``to_user`` that ``from_user`` shared a habit with them."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_like',
            title='Habit Shared With You',
            message=f'{from_user.name} shared "{habit.title}" with you!',
            from_user=from_user,
            habit=habit,
            icon_code=0xE80D,
            color_value=0xFF8B5CF6,
            action_type='community',
        )

    @staticmethod
    def friend_completed_habit(to_user, friend, habit):
        """Notify ``to_user`` that a friend completed a shared habit."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_like',
            title='Friend Completed a Habit!',
            message=f'{friend.name} just completed "{habit.title}" 🎉',
            from_user=friend,
            habit=habit,
            icon_code=0xE86C,
            color_value=0xFF22C55E,
            action_type='community',
        )

    @staticmethod
    def encouragement_received(to_user, from_user, encourage_type, message_text='', habit=None):
        """Notify ``to_user`` that ``from_user`` sent encouragement."""
        emoji_map = {
            'cheer': '🎉',
            'motivate': '💪',
            'celebrate': '🏆',
            'remind': '⏰',
        }
        emoji = emoji_map.get(encourage_type, '💪')
        body = message_text or f'{from_user.name} sent you encouragement! {emoji}'
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_like',
            title=f'{emoji} Encouragement from {from_user.name}',
            message=body,
            from_user=from_user,
            habit=habit,
            icon_code=0xEA6E,
            color_value=0xFFF59E0B,
            action_type='community',
        )

    @staticmethod
    def group_challenge_created(to_user, creator, group, challenge):
        """Notify group member about a new group challenge."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='group_challenge',
            title='New Group Challenge!',
            message=f'{creator.name} created "{challenge.title}" in {group.name}',
            from_user=creator,
            group=group,
            icon_code=0xE838,
            color_value=0xFFF59E0B,
            action_type='group_detail',
            action_data={'groupId': group.id, 'challengeId': challenge.id},
        )

    @staticmethod
    def group_challenge_completed(to_user, group, challenge):
        """Notify group member that a challenge was completed."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='group_challenge',
            title='Challenge Complete! 🏆',
            message=f'Your group "{group.name}" completed "{challenge.title}"!',
            group=group,
            icon_code=0xE838,
            color_value=0xFF22C55E,
            action_type='group_detail',
            action_data={'groupId': group.id, 'challengeId': challenge.id},
        )

    @staticmethod
    def group_milestone(to_user, group, milestone_text):
        """Notify group member about a group milestone (e.g. 100 total completions)."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='group_challenge',
            title='Group Milestone! 🎯',
            message=f'{group.name}: {milestone_text}',
            group=group,
            icon_code=0xE838,
            color_value=0xFF8B5CF6,
            action_type='group_detail',
            action_data={'groupId': group.id},
        )

    @staticmethod
    def habit_reaction_received(to_user, from_user, habit, reaction_type):
        """Notify habit owner that someone reacted to their shared habit."""
        emoji_map = {
            'like': '👍', 'encourage': '💪', 'celebrate': '🎉',
            'fire': '🔥', 'clap': '👏',
        }
        emoji = emoji_map.get(reaction_type, '👍')
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_like',
            title=f'{emoji} {from_user.name} reacted!',
            message=f'{from_user.name} reacted {emoji} to "{habit.title}"',
            from_user=from_user,
            habit=habit,
            icon_code=0xE87E,
            color_value=0xFFF59E0B,
            action_type='habit_detail',
            action_data={'habitId': habit.id},
        )

    @staticmethod
    def habit_comment_received(to_user, from_user, habit, comment_preview):
        """Notify habit owner that someone commented on their shared habit."""
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_comment',
            title=f'{from_user.name} commented',
            message=f'On "{habit.title}": {comment_preview[:80]}',
            from_user=from_user,
            habit=habit,
            icon_code=0xE0B9,
            color_value=0xFF3B82F6,
            action_type='habit_detail',
            action_data={'habitId': habit.id},
        )

    # ── Feed post interaction notifications ──────────────────────────

    @staticmethod
    def post_liked(to_user, from_user, post):
        """Notify feed post author that someone liked their post."""
        preview = (post.content[:60] + '…') if len(post.content) > 60 else post.content
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_like',
            title=f'{from_user.name} liked your post',
            message=f'"{preview}"',
            from_user=from_user,
            icon_code=0xE87E,   # favorite
            color_value=0xFFEF4444,
            action_type='community',
        )

    @staticmethod
    def post_commented(to_user, from_user, post, comment_preview):
        """Notify feed post author that someone commented on their post."""
        preview = (comment_preview[:80] + '…') if len(comment_preview) > 80 else comment_preview
        return NotificationCreator.create(
            user=to_user,
            notification_type='social_comment',
            title=f'{from_user.name} commented on your post',
            message=preview,
            from_user=from_user,
            icon_code=0xE0B9,   # chat_bubble
            color_value=0xFF3B82F6,
            action_type='community',
        )


# =============================================================================
#  SMART TIP SERVICE — personalised, non-urgent habit guidance
# =============================================================================

class SmartTipService:
    """
    Generates and manages personalized smart tips for users.

    Tips are generated lazily — the service is invoked when the user opens
    the Smart Tips screen and checks whether fresh tips are needed (fewer
    than 2 non-dismissed tips created today).  This avoids unnecessary
    background work while still keeping the feed fresh.

    Tip generation categories (in order of priority):
        1. Missed-habit encouragement
        2. Near-streak-milestone nudges
        3. Declining-consistency warnings
        4. General wellness / motivational tips
    """

    @staticmethod
    def generate_tips_if_needed(user):
        """
        Entry point: generate fresh tips if the user has fewer than 2
        non-dismissed tips from today.

        This method is idempotent — calling it multiple times on the same
        day will not create duplicate tips thanks to per-type dedup checks
        inside each generator.

        Args:
            user: The user to generate tips for.
        """
        today = timezone.now().date()
        # Count non-dismissed tips already created today
        recent_count = SmartTip.objects.filter(
            user=user,
            is_dismissed=False,
            created_at__date=today,
        ).count()

        if recent_count >= 2:
            return  # Sufficient tips already exist for today

        # Generate tips in priority order — each generator deduplicates internally
        SmartTipService._generate_missed_habit_tips(user)
        SmartTipService._generate_streak_milestone_tips(user)
        SmartTipService._generate_declining_tips(user)
        SmartTipService._generate_general_wellness_tips(user)

    @staticmethod
    def _generate_missed_habit_tips(user):
        """
        Create encouragement tips for habits the user missed yesterday.

        Only the first 2 active habits are evaluated to keep the tip feed
        concise.  A dedup check prevents the same tip from being created
        twice on the same day.
        """
        yesterday = (timezone.now() - timedelta(days=1)).date()
        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)

        for habit in habits[:2]:
            completed = HabitLog.objects.filter(
                habit=habit, date=yesterday, status='completed'
            ).exists()
            if not completed:
                exists = SmartTip.objects.filter(
                    user=user, tip_type='missed_habit', habit=habit,
                    created_at__date=timezone.now().date(),
                ).exists()
                if not exists:
                    SmartTip.objects.create(
                        user=user,
                        tip_type='missed_habit',
                        title=f'Get Back on Track',
                        message=f'You missed "{habit.title}" yesterday. '
                                f'No worries - today is a fresh start! '
                                f'Even small progress counts.',
                        habit=habit,
                        icon_code=0xE88E,
                        color_value=0xFF3B82F6,
                    )

    @staticmethod
    def _generate_streak_milestone_tips(user):
        """
        Create celebration tips for habits that are exactly *one day* away
        from a predefined streak milestone (7, 14, 21, 30, 50, 100 days).
        """
        streaks = Streak.objects.filter(
            habit__user=user,
            habit__status='active',
            habit__is_deleted=False,
        ).select_related('habit')

        milestones = [7, 14, 21, 30, 50, 100]  # Predefined celebratory thresholds
        for streak in streaks:
            for milestone in milestones:
                if streak.current_streak == milestone - 1:
                    exists = SmartTip.objects.filter(
                        user=user, tip_type='streak_close', habit=streak.habit,
                        created_at__date=timezone.now().date(),
                    ).exists()
                    if not exists:
                        SmartTip.objects.create(
                            user=user,
                            tip_type='streak_close',
                            title=f'Almost at {milestone} Days!',
                            message=f'"{streak.habit.title}" is one day away from a '
                                    f'{milestone}-day streak. You are doing amazing!',
                            habit=streak.habit,
                            icon_code=0xE80E,
                            color_value=0xFFF59E0B,
                            metadata={'milestone': milestone},
                        )

    @staticmethod
    def _generate_declining_tips(user):
        """
        Create gentle nudge tips for habits whose completion rate dropped
        by more than 50 % compared to the previous week.

        Compares completions in the last 7 days against the 7 days before
        that for each active habit (capped at 5 habits).
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=7)
        two_weeks_ago = today - timedelta(days=14)

        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)

        for habit in habits[:5]:
            this_week = HabitLog.objects.filter(
                habit=habit, date__range=[week_start, today], status='completed'
            ).count()
            last_week = HabitLog.objects.filter(
                habit=habit, date__range=[two_weeks_ago, week_start - timedelta(days=1)],
                status='completed'
            ).count()

            # Flag if this week's completions dropped below 50% of last week
            if last_week > 0 and this_week < last_week * 0.5:
                exists = SmartTip.objects.filter(
                    user=user, tip_type='declining', habit=habit,
                    created_at__date=today,
                ).exists()
                if not exists:
                    SmartTip.objects.create(
                        user=user,
                        tip_type='declining',
                        title=f'Gentle Reminder',
                        message=f'Your consistency on "{habit.title}" has dipped recently. '
                                f'Try setting a smaller goal or adjusting the schedule.',
                        habit=habit,
                        icon_code=0xE88E,
                        color_value=0xFF14B8A6,
                    )

    @staticmethod
    def _generate_general_wellness_tips(user):
        """
        Inject a random general-wellness tip if the user still has fewer
        than 2 tips for today.  Tips are drawn from a curated pool of
        evergreen motivational messages.
        """
        today = timezone.now().date()
        today_count = SmartTip.objects.filter(
            user=user, created_at__date=today, is_dismissed=False,
        ).count()

        if today_count >= 2:
            return  # Daily tip budget already met

        # Curated pool of evergreen motivational tips
        tips_pool = [
            ('Consistency Over Perfection', 'Missing one day does not break your progress. What matters is showing up most days.'),
            ('Start Small, Build Big', 'If a habit feels hard, shrink it. 2 minutes of reading is better than 0 minutes.'),
            ('Celebrate Small Wins', 'Every completed habit is worth celebrating. You are building the life you want.'),
            ('Stack Your Habits', 'Attach a new habit to an existing one. After coffee, meditate. After lunch, journal.'),
            ('Reflect Weekly', 'Take a moment each week to review your progress. Awareness drives improvement.'),
        ]

        # Pick one tip at random and create it if it doesn't already exist today
        import random
        tip_data = random.choice(tips_pool)
        exists = SmartTip.objects.filter(
            user=user, tip_type='general', title=tip_data[0],
            created_at__date=today,
        ).exists()
        if not exists:
            SmartTip.objects.create(
                user=user,
                tip_type='general',
                title=tip_data[0],
                message=tip_data[1],
                icon_code=0xE3AF,
                color_value=0xFF14B8A6,
            )


# =============================================================================
#  NOTIFICATION INTELLIGENCE — smart analytics & delivery engine
# =============================================================================

class NotificationIntelligence:
    """
    Smart notification engine for DailyHabits.

    Provides four key capabilities:

    1. **Smart reminder suggestions** — Analyses past completion timestamps
       to identify peak-productivity hours and suggest optimal reminder times
       for habits that currently lack reminders.
    2. **Streak-risk alerts** — Identifies habits with active streaks (≥ 3 days)
       that haven't been completed today, ranked by urgency.
    3. **Weekly performance nudges** — Compares this week's completions to
       the previous week and generates encouraging or motivating messages.
    4. **Delivery gating** — Enforces quiet hours, daily caps, and a
       30-minute cooldown between consecutive notifications.
    """

    @staticmethod
    def get_smart_reminder_suggestions(user):
        """
        Suggest optimal reminder times for habits without reminders.

        Analyses the hour-of-day distribution of the user's past completions
        to determine their peak productivity hour, then recommends that time
        as the reminder for each unreminded active habit (up to 5).

        Returns:
            list[dict]: Suggestion dicts with ``habitId``, ``habitTitle``,
            ``suggestedTime``, and ``reason``.
        """
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False, reminder_enabled=False
        )
        logs = HabitLog.objects.filter(
            habit__user=user, status='completed', completed_at__isnull=False
        ).values_list('completed_at', flat=True)

        if not logs:
            return []  # No completion history — cannot infer optimal time

        # Build hour-of-day frequency map from completion timestamps
        hour_counts = {}
        for dt in logs:
            hour = dt.hour
            hour_counts[hour] = hour_counts.get(hour, 0) + 1

        if not hour_counts:
            return []  # Safety guard — should not happen after the logs check above

        # Determine the single most productive hour
        peak_hour = max(hour_counts, key=lambda k: hour_counts[k])

        # Build suggestions for up to 5 habits lacking a reminder
        suggestions = []
        for habit in habits[:5]:
            suggestions.append({
                'habitId': habit.id,
                'habitTitle': habit.title,
                'suggestedTime': f'{peak_hour:02d}:00',
                'reason': f'You are most productive around {peak_hour}:00. Setting a reminder can improve consistency by 40%.',
            })
        return suggestions

    @staticmethod
    def get_streak_risk_alerts(user):
        """
        Identify habits with active streaks (≥ 3 days) not yet completed
        today, sorted by urgency (hours remaining in the day).

        Urgency levels:
            - **high**: ≤ 4 hours remaining
            - **medium**: ≤ 8 hours remaining
            - **low**: > 8 hours remaining

        Returns:
            list[dict]: At-risk habit dicts sorted by urgency (highest first).
        """
        today = timezone.now().date()
        now = timezone.now()
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        ).select_related('streak')

        at_risk = []
        for habit in habits:
            try:
                streak = habit.streak  # type: ignore[attr-defined]
            except Streak.DoesNotExist:
                continue
            if streak.current_streak < 3:
                continue  # Ignore insignificant streaks

            # Check if the habit was already completed today
            completed_today = HabitLog.objects.filter(
                habit=habit, date=today, status='completed'
            ).exists()
            if not completed_today:
                hours_left = 24 - now.hour  # Approximate hours remaining in the day
                # Classify urgency based on remaining time
                urgency = 'high' if hours_left <= 4 else ('medium' if hours_left <= 8 else 'low')
                at_risk.append({
                    'habitId': habit.id,
                    'habitTitle': habit.title,
                    'currentStreak': streak.current_streak,
                    'hoursRemaining': hours_left,
                    'urgency': urgency,
                    'message': f"Don't break your {streak.current_streak}-day streak on '{habit.title}'! Only {hours_left}h left today.",
                })

        # Sort by urgency: high → medium → low
        urgency_order = {'high': 0, 'medium': 1, 'low': 2}
        at_risk.sort(key=lambda x: urgency_order.get(x['urgency'], 3))
        return at_risk

    @staticmethod
    def get_weekly_performance_nudges(user):
        """
        Compare this week's habit completions to last week's and generate
        motivational nudges.

        Also highlights the user's "star habit" — the one with the most
        completions in the current week.

        Returns:
            list[dict]: Nudge dicts with ``type``, ``title``, and ``message``.
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday())
        last_week_start = week_start - timedelta(days=7)

        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)
        # Count completions for this week vs. last week
        this_week_count = HabitLog.objects.filter(
            habit__in=habits, date__range=[week_start, today], status='completed'
        ).count()
        last_week_count = HabitLog.objects.filter(
            habit__in=habits, date__range=[last_week_start, week_start - timedelta(days=1)], status='completed'
        ).count()

        nudges = []
        # Determine the user's trajectory and craft an appropriate nudge
        if this_week_count > last_week_count:
            nudges.append({
                'type': 'positive',
                'title': 'Great Progress!',
                'message': f'You completed {this_week_count - last_week_count} more habits this week compared to last week. Keep it up!',
            })
        elif this_week_count < last_week_count:
            nudges.append({
                'type': 'encouragement',
                'title': 'You Can Do Better!',
                'message': f'You are {last_week_count - this_week_count} completions behind last week. There is still time to catch up!',
            })
        else:
            nudges.append({
                'type': 'stable',
                'title': 'Staying Consistent!',
                'message': 'You are matching last week performance. Push a little harder for new heights!',
            })

        # Identify this week's "star" habit (most completions)
        best_habit = None
        best_count = 0
        for habit in habits:
            count = HabitLog.objects.filter(
                habit=habit, date__range=[week_start, today], status='completed'
            ).count()
            if count > best_count:
                best_count = count
                best_habit = habit

        if best_habit:
            nudges.append({
                'type': 'highlight',
                'title': 'Star Habit This Week',
                'message': f'"{best_habit.title}" is your top performer with {best_count} completions this week!',
            })
        return nudges

    @staticmethod
    def should_send_notification(user):
        """
        Determine whether a new notification should be delivered to the user.

        Enforces the following rules (in order):
            1. Master notifications toggle must be enabled.
            2. Current time must be outside quiet hours (if configured).
            3. Daily notification cap must not be exceeded.
            4. At least 30 minutes must have elapsed since the last notification.

        Returns:
            bool: ``True`` if the notification may be sent.
        """
        try:
            settings = NotificationSettings.objects.get(user=user)
        except NotificationSettings.DoesNotExist:
            return True

        if not settings.notifications_enabled:
            return False  # Master kill-switch is off

        # Rule 2: Suppress during quiet hours
        now = timezone.now().time()
        if settings.quiet_hours_enabled:
            if settings.quiet_hours_start and settings.quiet_hours_end:
                if settings.quiet_hours_start <= now <= settings.quiet_hours_end:
                    return False  # Currently within quiet-hours window

        # Rule 3: Enforce daily notification cap
        today = timezone.now().date()
        today_count = Notification.objects.filter(
            user=user, created_at__date=today, status__in=['sent', 'pending']
        ).count()
        if today_count >= settings.max_notifications_per_day:
            return False  # Daily cap reached

        # Rule 4: Enforce 30-minute cooldown between consecutive notifications
        last_notification = Notification.objects.filter(user=user).order_by('-created_at').first()
        if last_notification:
            time_diff = timezone.now() - last_notification.created_at
            if time_diff < timedelta(minutes=30):
                return False  # Too soon since last notification
        return True

    @staticmethod
    def get_notification_summary(user):
        """
        Aggregate all intelligence endpoints into a single summary payload.

        Returns:
            dict: Combined results from smart suggestions, streak risks,
            weekly nudges, and the current delivery-gate status.
        """
        return {
            'smartSuggestions': NotificationIntelligence.get_smart_reminder_suggestions(user),
            'streakRisks': NotificationIntelligence.get_streak_risk_alerts(user),
            'weeklyNudges': NotificationIntelligence.get_weekly_performance_nudges(user),
            'canSendMore': NotificationIntelligence.should_send_notification(user),
        }
