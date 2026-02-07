"""
Notification Services
NotificationCreator: Creates inbox notifications for events
SmartTipService: Generates personalized smart tips
NotificationIntelligence: Smart reminders, streak risk alerts, fatigue prevention
"""

from datetime import timedelta
from django.utils import timezone
from django.db.models import Count

from habits.models import Habit, HabitLog, Streak
from notifications.models import Notification, SmartTip, NotificationSettings


# ===========================================================================
#  NOTIFICATION CREATOR - event-driven inbox notification creation
# ===========================================================================

class NotificationCreator:
    """Creates inbox notifications for system and social events."""

    @staticmethod
    def create(user, notification_type, title, message, **kwargs):
        """Generic notification creation with dedup check."""
        # Dedup: don't create duplicate within last 5 minutes
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
        return NotificationCreator.create(
            user=user,
            notification_type='security',
            title=title,
            message=message,
            icon_code=0xE897,
            color_value=0xFFEF4444,
            action_type='settings',
        )


# ===========================================================================
#  SMART TIP SERVICE - generates personalized tips
# ===========================================================================

class SmartTipService:
    """Generates and manages personalized smart tips."""

    @staticmethod
    def generate_tips_if_needed(user):
        """Generate fresh tips if user has fewer than 2 non-dismissed tips from today."""
        today = timezone.now().date()
        recent_count = SmartTip.objects.filter(
            user=user,
            is_dismissed=False,
            created_at__date=today,
        ).count()

        if recent_count >= 2:
            return  # Enough tips for today

        SmartTipService._generate_missed_habit_tips(user)
        SmartTipService._generate_streak_milestone_tips(user)
        SmartTipService._generate_declining_tips(user)
        SmartTipService._generate_general_wellness_tips(user)

    @staticmethod
    def _generate_missed_habit_tips(user):
        """Tips for habits missed yesterday."""
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
        """Tips for habits near streak milestones."""
        streaks = Streak.objects.filter(
            habit__user=user,
            habit__status='active',
            habit__is_deleted=False,
        ).select_related('habit')

        milestones = [7, 14, 21, 30, 50, 100]
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
        """Tips for habits with declining consistency."""
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
        """General wellness tips if user has few tips today."""
        today = timezone.now().date()
        today_count = SmartTip.objects.filter(
            user=user, created_at__date=today, is_dismissed=False,
        ).count()

        if today_count >= 2:
            return

        tips_pool = [
            ('Consistency Over Perfection', 'Missing one day does not break your progress. What matters is showing up most days.'),
            ('Start Small, Build Big', 'If a habit feels hard, shrink it. 2 minutes of reading is better than 0 minutes.'),
            ('Celebrate Small Wins', 'Every completed habit is worth celebrating. You are building the life you want.'),
            ('Stack Your Habits', 'Attach a new habit to an existing one. After coffee, meditate. After lunch, journal.'),
            ('Reflect Weekly', 'Take a moment each week to review your progress. Awareness drives improvement.'),
        ]

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


# ===========================================================================
#  NOTIFICATION INTELLIGENCE - existing smart analysis engine
# ===========================================================================

class NotificationIntelligence:
    """Smart notification engine for DailyHabits."""

    @staticmethod
    def get_smart_reminder_suggestions(user):
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False, reminder_enabled=False
        )
        logs = HabitLog.objects.filter(
            habit__user=user, status='completed', completed_at__isnull=False
        ).values_list('completed_at', flat=True)

        if not logs:
            return []

        hour_counts = {}
        for dt in logs:
            hour = dt.hour
            hour_counts[hour] = hour_counts.get(hour, 0) + 1

        if not hour_counts:
            return []

        peak_hour = max(hour_counts, key=lambda k: hour_counts[k])
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
        today = timezone.now().date()
        now = timezone.now()
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        ).select_related('streak')

        at_risk = []
        for habit in habits:
            try:
                streak = habit.streak
            except Streak.DoesNotExist:
                continue
            if streak.current_streak < 3:
                continue
            completed_today = HabitLog.objects.filter(
                habit=habit, date=today, status='completed'
            ).exists()
            if not completed_today:
                hours_left = 24 - now.hour
                urgency = 'high' if hours_left <= 4 else ('medium' if hours_left <= 8 else 'low')
                at_risk.append({
                    'habitId': habit.id,
                    'habitTitle': habit.title,
                    'currentStreak': streak.current_streak,
                    'hoursRemaining': hours_left,
                    'urgency': urgency,
                    'message': f"Don't break your {streak.current_streak}-day streak on '{habit.title}'! Only {hours_left}h left today.",
                })

        urgency_order = {'high': 0, 'medium': 1, 'low': 2}
        at_risk.sort(key=lambda x: urgency_order.get(x['urgency'], 3))
        return at_risk

    @staticmethod
    def get_weekly_performance_nudges(user):
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday())
        last_week_start = week_start - timedelta(days=7)

        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)
        this_week_count = HabitLog.objects.filter(
            habit__in=habits, date__range=[week_start, today], status='completed'
        ).count()
        last_week_count = HabitLog.objects.filter(
            habit__in=habits, date__range=[last_week_start, week_start - timedelta(days=1)], status='completed'
        ).count()

        nudges = []
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
        try:
            settings = NotificationSettings.objects.get(user=user)
        except NotificationSettings.DoesNotExist:
            return True

        if not settings.notifications_enabled:
            return False

        now = timezone.now().time()
        if settings.quiet_hours_enabled:
            if settings.quiet_hours_start and settings.quiet_hours_end:
                if settings.quiet_hours_start <= now <= settings.quiet_hours_end:
                    return False

        today = timezone.now().date()
        today_count = Notification.objects.filter(
            user=user, created_at__date=today, status__in=['sent', 'pending']
        ).count()
        if today_count >= settings.max_notifications_per_day:
            return False

        last_notification = Notification.objects.filter(user=user).order_by('-created_at').first()
        if last_notification:
            time_diff = timezone.now() - last_notification.created_at
            if time_diff < timedelta(minutes=30):
                return False
        return True

    @staticmethod
    def get_notification_summary(user):
        return {
            'smartSuggestions': NotificationIntelligence.get_smart_reminder_suggestions(user),
            'streakRisks': NotificationIntelligence.get_streak_risk_alerts(user),
            'weeklyNudges': NotificationIntelligence.get_weekly_performance_nudges(user),
            'canSendMore': NotificationIntelligence.should_send_notification(user),
        }
