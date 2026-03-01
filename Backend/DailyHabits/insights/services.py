"""
Insights Service — DailyHabits Application
==========================================

Business-logic layer for the smart-insights engine.  ``InsightService``
analyses a user's habit-tracking data and produces personalised,
actionable feedback including:

- **Daily motivational quotes** with a least-shown rotation algorithm.
- **Peak-performance time analysis** — identifies the time slot in which
  the user is most productive.
- **Consistency ranking** — surfaces the most (and least) consistent
  habits over a rolling 30-day window.
- **Decline detection** — week-over-week comparison that flags habits
  whose completion rate is dropping.
- **Streak milestone celebrations** — contextual messages for notable
  streak lengths (3 d, 7 d, 21 d, … 365 d).
- **Comeback encouragement** — motivational nudge when a user returns
  after ≥ 3 days of inactivity.
- **Personalised recommendations** — e.g. enable reminders, simplify
  low-consistency habits.

Design notes
------------
* All public methods are ``@staticmethod`` / ``@classmethod`` so the
  service is stateless and easy to call from views or management
  commands.
* Heavy queries are bounded by short rolling windows (7–30 days) to
  keep response times acceptable.
"""

# ===========================================================================
# Imports
# ===========================================================================

import random
from datetime import datetime, timedelta
from django.db.models import Count
from django.utils import timezone

from habits.models import Habit, HabitLog
from .models import MotivationalQuote, UserInsight


# ===========================================================================
# Service: InsightService
# ===========================================================================


class InsightService:
    """
    Stateless service for generating personalised user insights.

    All public methods accept a ``user`` argument (Django user instance)
    and return plain Python dicts ready for JSON serialisation.  The
    service has **no mutable state** — every call is self-contained.
    """

    # ------------------------------------------------------------------
    # Default motivational quotes
    # ------------------------------------------------------------------
    # These are seeded into the database on first run via ``seed_quotes``
    # and serve as a fallback when the DB table is empty.
    DEFAULT_QUOTES = [
        {"quote": "Small daily improvements lead to stunning results.", "author": "Robin Sharma"},
        {"quote": "The only bad workout is the one that didn't happen.", "author": "Unknown"},
        {"quote": "Habits are the compound interest of self-improvement.", "author": "James Clear"},
        {"quote": "Excellence is not an act, but a habit.", "author": "Aristotle"},
        {"quote": "Your habits shape your identity.", "author": "James Clear"},
        {"quote": "Consistency is what transforms average into excellence.", "author": "Unknown"},
        {"quote": "Every day is a new opportunity to grow.", "author": "Unknown"},
        {"quote": "The secret of your success is found in your daily routine.", "author": "John C. Maxwell"},
        {"quote": "Motivation is what gets you started. Habit is what keeps you going.", "author": "Jim Ryun"},
        {"quote": "We are what we repeatedly do.", "author": "Will Durant"},
        {"quote": "Success is the sum of small efforts repeated day in and day out.", "author": "Robert Collier"},
        {"quote": "The chains of habit are too light to be felt until they are too heavy to be broken.", "author": "Warren Buffett"},
        {"quote": "You'll never change your life until you change something you do daily.", "author": "John C. Maxwell"},
        {"quote": "First forget inspiration. Habit is more dependable.", "author": "Octavia Butler"},
        {"quote": "Good habits are worth being fanatical about.", "author": "John Irving"},
        {"quote": "Champions don't do extraordinary things. They do ordinary things, but they do them without thinking.", "author": "Charles Duhigg"},
        {"quote": "Quality is not an act, it is a habit.", "author": "Aristotle"},
        {"quote": "Depending on what they are, our habits will either make us or break us.", "author": "Sean Covey"},
        {"quote": "The hard days are the best because that's when champions are made.", "author": "Gabby Douglas"},
        {"quote": "It's not what we do once in a while that shapes our lives, but what we do consistently.", "author": "Tony Robbins"},
    ]

    # ------------------------------------------------------------------
    # Comeback encouragement messages
    # ------------------------------------------------------------------
    # Randomly selected when the user returns after ≥ 3 days of inactivity.
    COMEBACK_MESSAGES = [
        "Welcome back! Every journey has ups and downs. What matters is you're here now. 💪",
        "Missing a few days is okay - what's important is that you're back! Let's go! 🔥",
        "The best time to restart is now. You've got this! 🌟",
        "One step back, two steps forward. Your comeback starts today! 🚀",
        "Every expert was once a beginner. Every champion was once someone who refused to give up. 💫",
    ]

    # ------------------------------------------------------------------
    # Streak celebration messages
    # ------------------------------------------------------------------
    # Keyed by streak length (days).  Matched exactly, so a user with a
    # 7-day streak sees the "One week!" message but not the 3-day one.
    STREAK_CELEBRATIONS = {
        3: "🎉 3-day streak! You're building momentum!",
        7: "🔥 One week! You're on fire!",
        14: "⭐ Two weeks of consistency! You're unstoppable!",
        21: "🏆 21 days! They say it takes this long to build a habit!",
        30: "🎊 A full month! You're officially a habit master!",
        60: "💎 60 days! Your dedication is inspiring!",
        90: "🚀 90 days! Quarterly champion!",
        100: "💯 100 days! Triple digits!",
        365: "👑 ONE YEAR! You're a legend!",
    }

    # ==================================================================
    # Quote Management
    # ==================================================================

    @classmethod
    def seed_quotes(cls):
        """
        Populate the ``MotivationalQuote`` table with default quotes.

        Uses ``get_or_create`` so the operation is idempotent — safe to
        run on every deployment or via the admin seed-quotes endpoint.

        Returns:
            int: Number of newly created quote records.
        """
        created = 0
        for q in cls.DEFAULT_QUOTES:
            # get_or_create avoids duplicates when re-seeding
            quote, was_created = MotivationalQuote.objects.get_or_create(
                quote=q['quote'],
                defaults={
                    'author': q['author'],
                    'category': 'general',
                    'language': 'en',
                }
            )
            if was_created:
                created += 1
        return created

    @staticmethod
    def get_daily_quote(user=None, category='general'):
        """
        Retrieve a motivational quote using a *least-shown* rotation.

        The algorithm picks the quote with the lowest ``times_shown``
        counter within the requested category, increments it, and
        returns the result.  If the database is empty, a random quote
        from ``DEFAULT_QUOTES`` is returned instead.

        Args:
            user: The requesting user (reserved for future
                personalisation; currently unused).
            category (str): Quote category filter (default ``'general'``).

        Returns:
            dict: ``{'quote', 'author', 'category'}``.
        """
        # Try database first
        quotes = MotivationalQuote.objects.filter(
            is_active=True,
            category=category
        )

        if quotes.exists():
            # Pick the least-shown quote to ensure fair rotation
            quote = quotes.order_by('times_shown').first()
            quote.times_shown += 1
            quote.save()
            return {
                'quote': quote.quote,
                'author': quote.author or 'Unknown',
                'category': quote.category,
            }

        # Fallback: no DB quotes available — return a random default
        q = random.choice(InsightService.DEFAULT_QUOTES)
        return {
            'quote': q['quote'],
            'author': q['author'],
            'category': 'general',
        }

    # ==================================================================
    # Performance Analytics
    # ==================================================================

    @staticmethod
    def get_best_performance_time(user):
        """
        Determine the time-of-day slot in which the user completes the
        most habits.

        Buckets every ``completed_at`` timestamp into one of five slots
        (early morning, morning, afternoon, evening, night) and returns
        the slot with the highest count.

        Args:
            user: Django user instance.

        Returns:
            dict: ``{'time', 'timeLabel', 'percentage', 'insight'}``.
        """
        # Fetch all completion timestamps for the user
        logs = HabitLog.objects.filter(
            habit__user=user,
            status='completed',
            completed_at__isnull=False
        ).values_list('completed_at', flat=True)

        if not logs:
            return {
                'time': 'morning',
                'percentage': 0,
                'insight': 'Complete more habits to see your best performance time!',
            }

        # Define time-of-day buckets with hour ranges
        time_slots = {
            'early_morning': {'range': (5, 8), 'count': 0, 'label': 'Early Morning (5-8 AM)'},
            'morning':       {'range': (8, 12), 'count': 0, 'label': 'Morning (8 AM-12 PM)'},
            'afternoon':     {'range': (12, 17), 'count': 0, 'label': 'Afternoon (12-5 PM)'},
            'evening':       {'range': (17, 21), 'count': 0, 'label': 'Evening (5-9 PM)'},
            'night':         {'range': (21, 24), 'count': 0, 'label': 'Night (9 PM+)'},
        }

        # Classify each completion into a time slot
        for dt in logs:
            hour = dt.hour
            for slot, data in time_slots.items():
                start, end = data['range']
                # Night wraps around midnight (21:00–04:59)
                if start <= hour < end or (slot == 'night' and (hour >= 21 or hour < 5)):
                    data['count'] += 1
                    break

        total = sum(d['count'] for d in time_slots.values())
        if total == 0:
            return {'time': 'morning', 'percentage': 0, 'insight': 'No data yet'}

        # Identify the dominant time slot
        best_slot = max(time_slots.items(), key=lambda x: x[1]['count'])
        percentage = (best_slot[1]['count'] / total) * 100

        return {
            'time': best_slot[0],
            'timeLabel': best_slot[1]['label'],
            'percentage': round(percentage, 1),
            'insight': f"You're most productive in the {best_slot[1]['label']}! "
                      f"{round(percentage)}% of your habits are completed then.",
        }

    # ==================================================================
    # Consistency & Decline Analysis
    # ==================================================================

    @staticmethod
    def get_most_consistent_habits(user, limit=3):
        """
        Rank the user's active habits by 30-day consistency rate.

        Consistency is calculated as::

            completed_days / active_days * 100

        where ``active_days`` is the lesser of 30 or the number of days
        since the habit's start date.

        Args:
            user: Django user instance.
            limit (int): Maximum number of habits to return.

        Returns:
            list[dict]: Sorted descending by ``consistency``.
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )

        today = timezone.now().date()
        start_date = today - timedelta(days=30)  # Rolling 30-day window

        habit_consistency = []
        for habit in habits:
            # Number of days the habit has been active within the window
            days_active = max(1, (today - max(habit.start_date, start_date)).days + 1)
            completed = HabitLog.objects.filter(
                habit=habit,
                date__range=[start_date, today],
                status='completed'
            ).count()

            # Cap at 100% to account for multiple completions per day
            consistency = min(100, (completed / days_active) * 100)
            habit_consistency.append({
                'id': habit.id,
                'title': habit.title,
                'category': habit.category_name,
                'iconCode': habit.icon_code,
                'colorValue': habit.color_value,
                'consistency': round(consistency, 1),
                'completedDays': completed,
            })

        # Sort by consistency descending and return top N
        sorted_habits = sorted(
            habit_consistency, 
            key=lambda x: x['consistency'], 
            reverse=True
        )

        return sorted_habits[:limit]

    @staticmethod
    def get_declining_habits(user, limit=3):
        """
        Detect habits whose completion rate is dropping.

        Compares the completion count from the **last 7 days** against
        the **previous 7 days**.  A habit is flagged as declining when
        ``prev_week > 0`` and ``last_week < prev_week``.

        Args:
            user: Django user instance.
            limit (int): Maximum number of declining habits to return.

        Returns:
            list[dict]: Sorted descending by ``declinePercent``.
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )

        today = timezone.now().date()

        declining = []
        for habit in habits:
            # --- Week-over-week completion comparison ---
            last_week = HabitLog.objects.filter(
                habit=habit,
                date__range=[today - timedelta(days=7), today],
                status='completed'
            ).count()

            prev_week = HabitLog.objects.filter(
                habit=habit,
                date__range=[today - timedelta(days=14), today - timedelta(days=8)],
                status='completed'
            ).count()

            # Only flag decline when there was prior activity that has dropped
            if prev_week > 0 and last_week < prev_week:
                decline_rate = ((prev_week - last_week) / prev_week) * 100
                declining.append({
                    'id': habit.id,
                    'title': habit.title,
                    'category': habit.category_name,
                    'iconCode': habit.icon_code,
                    'colorValue': habit.color_value,
                    'lastWeekCount': last_week,
                    'prevWeekCount': prev_week,
                    'declinePercent': round(decline_rate, 1),
                    'insight': f"'{habit.title}' is down {round(decline_rate)}% this week. "
                              f"Consider adjusting your schedule or setting a reminder.",
                })

        # Return the most steeply declining habits first
        return sorted(declining, key=lambda x: x['declinePercent'], reverse=True)[:limit]

    # ==================================================================
    # Daily Insight Aggregation
    # ==================================================================

    @staticmethod
    def get_daily_insights(user):
        """
        Assemble the personalised daily-insights feed for a user.

        Calls the individual analysis methods and compiles their results
        into a unified list of insight cards, each annotated with type,
        priority, icon, and colour for the Flutter UI layer.

        Args:
            user: Django user instance.

        Returns:
            list[dict]: Ordered list of insight card payloads.
        """
        insights = []

        # --- Insight: peak performance time ---
        best_time = InsightService.get_best_performance_time(user)
        if best_time['percentage'] > 0:
            insights.append({
                'type': 'best_time',
                'title': 'Peak Performance Time',
                'message': best_time['insight'],
                'iconCode': 0xE8B5,       # schedule icon
                'colorValue': 0xFF3B82F6,  # Blue
                'priority': 'medium',
            })

        # --- Insight: star performer (most consistent habit ≥ 70%) ---
        consistent = InsightService.get_most_consistent_habits(user, 1)
        if consistent and consistent[0]['consistency'] >= 70:
            habit = consistent[0]
            insights.append({
                'type': 'consistent_habit',
                'title': 'Star Performer',
                'message': f"'{habit['title']}' is your most consistent habit at "
                          f"{habit['consistency']}% completion rate! Keep it up! 🌟",
                'iconCode': 0xE838,        # star icon
                'colorValue': 0xFF10B981,   # Green
                'priority': 'low',
                'habitId': habit['id'],
            })

        # --- Insight: declining habits alert ---
        declining = InsightService.get_declining_habits(user, 1)
        if declining:
            habit = declining[0]
            insights.append({
                'type': 'declining_habit',
                'title': 'Needs Attention',
                'message': habit['insight'],
                'iconCode': 0xE002,        # warning icon
                'colorValue': 0xFFF59E0B,   # Amber
                'priority': 'high',
                'habitId': habit['id'],
            })

        # --- Insight: streak milestones ---
        # Lazy import to avoid circular dependency with habits app
        from habits.models import Streak
        max_streak = 0
        for habit in Habit.objects.filter(user=user, status='active', is_deleted=False):
            try:
                max_streak = max(max_streak, habit.streak.current_streak)
            except Streak.DoesNotExist:
                pass  # Habit has no streak record yet

        # Match the current max streak against known celebration milestones
        for days, message in InsightService.STREAK_CELEBRATIONS.items():
            if max_streak == days:
                insights.append({
                    'type': 'streak_milestone',
                    'title': 'Streak Milestone!',
                    'message': message,
                    'iconCode': 0xE80E,        # whatshot icon
                    'colorValue': 0xFFEF4444,   # Red
                    'priority': 'high',
                })
                break  # Only show one milestone per request

        return insights

    # ==================================================================
    # Re-engagement & Recommendations
    # ==================================================================

    @staticmethod
    def get_comeback_message(user):
        """
        Generate an encouragement message for returning users.

        If the user has not completed any habit in the last 3+ days,
        a randomly selected comeback message is returned alongside the
        inactivity duration.

        Args:
            user: Django user instance.

        Returns:
            dict: ``{'showComeback', 'message', 'daysSinceLastActivity'}``.
        """
        # Find the most recent completed habit log for this user
        last_log = HabitLog.objects.filter(
            habit__user=user,
            status='completed'
        ).order_by('-date').first()

        if not last_log:
            # User has never completed a habit — no comeback needed
            return {
                'showComeback': False,
                'message': None,
            }

        days_since = (timezone.now().date() - last_log.date).days

        # Trigger comeback encouragement after 3+ days of inactivity
        if days_since >= 3:
            return {
                'showComeback': True,
                'message': random.choice(InsightService.COMEBACK_MESSAGES),
                'daysSinceLastActivity': days_since,
            }

        return {
            'showComeback': False,
            'message': None,
        }

    @staticmethod
    def get_recommendations(user):
        """
        Build a list of personalised, actionable recommendations.

        Current recommendation strategies:
        1. **Enable reminders** — flagged when any active habits lack
           reminders (research shows reminders boost consistency ~40%).
        2. **Simplify low-consistency habits** — suggests revising a
           habit when its weekly completion drops below 50%.

        Args:
            user: Django user instance.

        Returns:
            list[dict]: Recommendation card payloads.
        """
        recommendations = []

        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )

        # --- Recommendation: enable reminders ---
        no_reminder_count = habits.filter(reminder_enabled=False).count()
        if no_reminder_count > 0:
            recommendations.append({
                'type': 'reminder',
                'title': 'Set Reminders',
                'message': f"You have {no_reminder_count} habits without reminders. "
                          f"Setting reminders can improve consistency by up to 40%!",
                'actionType': 'enable_reminders',
            })

        # --- Recommendation: simplify low-consistency habits ---
        today = timezone.now().date()
        for habit in habits:
            completed = HabitLog.objects.filter(
                habit=habit,
                date__range=[today - timedelta(days=7), today],
                status='completed'
            ).count()

            if completed < 3:  # Less than ~50% for the week
                recommendations.append({
                    'type': 'adjust_habit',
                    'title': f"Revise '{habit.title}'",
                    'message': f"Consider making this habit easier or more specific. "
                              f"Start small and build up gradually.",
                    'habitId': habit.id,
                    'actionType': 'edit_habit',
                })
                break  # Show only one low-consistency recommendation at a time

        return recommendations
