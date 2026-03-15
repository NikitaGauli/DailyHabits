"""
Analytics Service — analytics/services.py

Contains the core business logic for every analytics calculation used across
the DailyHabits application. All methods are stateless ``@staticmethod``’s
grouped inside ``AnalyticsService`` so that views, management commands, and
celery tasks can invoke them without instantiating the class.

Key responsibilities:
    • Streak calculation (current & best) for individual habits.
    • Consistency and success-rate metrics over configurable time windows.
    • Charting data: weekly bar-chart payloads and monthly calendar heatmaps.
    • Dashboard summary aggregation across all of a user’s active habits.
    • Category-level and difficulty-level breakdowns for the insights screen.
    • Week-over-week comparison and long-term monthly trend analysis.
    • Year-level productivity heatmap for the annual overview.

Design note:
    Calculations query the ``HabitLog`` table directly rather than reading
    from the cached summary models, keeping the service as the single source
    of truth. The cached models are populated *from* this service.
"""

from datetime import datetime, timedelta
from django.db.models import Count, Sum, Avg, Q
from django.utils import timezone
from calendar import monthrange

from habits.models import Habit, HabitLog, Streak


# =============================================================================
# Analytics Service
# =============================================================================

class AnalyticsService:
    """
    Stateless service class encapsulating all analytics computations.

    Every public method is a ``@staticmethod`` that accepts the minimum
    required arguments (a ``Habit`` or ``User`` instance, plus optional
    parameters) and returns plain Python data structures ready for JSON
    serialisation.
    """
    
    # =================================================================
    # Streak Calculations
    # =================================================================

    @staticmethod
    def calculate_current_streak(habit):
        """
        Calculate the current consecutive-day streak for a habit.

        Walks backwards from today (or yesterday, if today is not yet
        completed) counting unbroken 'completed' log entries.

        Args:
            habit: A ``Habit`` model instance.

        Returns:
            int: Number of consecutive completed days (0 if none).
        """
        today = timezone.now().date()
        streak = 0
        check_date = today

        # If today’s habit is not yet completed, start counting from yesterday
        today_log = HabitLog.objects.filter(
            habit=habit, 
            date=today, 
            status='completed'
        ).exists()
        
        if not today_log:
            check_date = today - timedelta(days=1)

        # Walk backwards day-by-day until a non-completed day is found
        while True:
            log_exists = HabitLog.objects.filter(
                habit=habit, 
                date=check_date, 
                status='completed'
            ).exists()
            
            if log_exists:
                streak += 1
                check_date -= timedelta(days=1)
            else:
                break  # Streak is broken
        
        return streak
    
    @staticmethod
    def calculate_best_streak(habit):
        """
        Find the longest consecutive-day completion streak ever achieved.

        Loads all 'completed' dates in chronological order and performs a
        single pass to detect the maximum run of consecutive calendar days.

        Args:
            habit: A ``Habit`` model instance.

        Returns:
            int: Length of the best streak (0 if no completions).
        """
        logs = HabitLog.objects.filter(
            habit=habit, 
            status='completed'
        ).order_by('date').values_list('date', flat=True)
        
        if not logs:
            return 0
        
        logs = list(logs)
        best = current = 1  # At least one log exists → minimum streak of 1

        for i in range(1, len(logs)):
            if (logs[i] - logs[i-1]).days == 1:
                # Consecutive day — extend the current streak
                current += 1
                best = max(best, current)
            else:
                # Gap detected — reset current streak
                current = 1
        
        return best
    
    # =================================================================
    # Consistency & Success-Rate Metrics
    # =================================================================

    @staticmethod
    def get_consistency_percentage(habit, days=30):
        """
        Calculate the consistency rate over a rolling window.

        Consistency = (completed days / eligible days) × 100. The window is
        clamped to the habit’s ``start_date`` so days before the habit existed
        are excluded from the denominator.

        Args:
            habit: A ``Habit`` model instance.
            days:  Look-back window size in days (default 30).

        Returns:
            float: Consistency % rounded to one decimal place.
        """
        today = timezone.now().date()
        start_date = today - timedelta(days=days-1)

        # Clamp the window start to the habit’s creation date
        actual_start = max(start_date, habit.start_date) if habit.start_date else start_date
        actual_days = (today - actual_start).days + 1  # Inclusive day count
        
        if actual_days <= 0:
            return 0.0
        
        completed = HabitLog.objects.filter(
            habit=habit,
            date__range=[actual_start, today],
            status='completed'
        ).count()
        
        return round((completed / actual_days) * 100, 1)
    
    @staticmethod
    def get_habit_success_rate(habit):
        """
        Calculate the overall success rate for a habit.

        Success rate = (completed logs / total logs) × 100. Unlike consistency,
        this metric counts only days that have a log entry (completed, skipped,
        or missed) rather than every calendar day.

        Args:
            habit: A ``Habit`` model instance.

        Returns:
            float: Success rate % rounded to one decimal place.
        """
        total_logs = HabitLog.objects.filter(habit=habit).count()
        if total_logs == 0:
            return 0.0
        
        completed = HabitLog.objects.filter(habit=habit, status='completed').count()
        return round((completed / total_logs) * 100, 1)
    
    # =================================================================
    # Chart / Visualisation Data
    # =================================================================

    @staticmethod
    def get_weekly_data(user, weeks_back=0):
        """
        Build a 7-element list of daily completion data for the bar chart.

        Each element contains the day name, date, completed count, total
        active habits, completion rate, and whether the day is today.

        Args:
            user:       The requesting ``User`` instance.
            weeks_back: Number of weeks to step back from the current week
                        (0 = current week).

        Returns:
            list[dict]: Seven dicts keyed Mon–Sun.
        """
        today = timezone.now().date()
        # Calculate the Monday that starts the target week
        week_start = today - timedelta(days=today.weekday()) - timedelta(weeks=weeks_back)

        # Total active (non-deleted) habits for the user
        active_habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        ).count()
        
        data = []
        day_names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

        # Iterate over each day of the week (Mon=0 … Sun=6)
        for i in range(7):
            day = week_start + timedelta(days=i)
            completed = HabitLog.objects.filter(
                habit__user=user,
                habit__status='active',
                habit__is_deleted=False,
                date=day,
                status='completed'
            ).count()
            
            rate = (completed / active_habits * 100) if active_habits > 0 else 0
            
            data.append({
                'day': day_names[i],
                'date': day.isoformat(),
                'completed': completed,
                'total': active_habits,
                'rate': round(rate, 1),
                'isToday': day == today,
            })
        
        return data
    
    @staticmethod
    def get_monthly_heatmap(user, year, month):
        """
        Generate calendar-heatmap data for a given month.

        Returns one dict per calendar day with an ``intensity`` value
        (0.0–1.0) representing the fraction of active habits completed.
        The frontend uses this to colour-code the calendar cells.

        Args:
            user:  The requesting ``User`` instance.
            year:  Calendar year (e.g. 2026).
            month: Calendar month (1–12).

        Returns:
            list[dict]: One entry per day of the month.
        """
        days_in_month = monthrange(year, month)[1]
        today = timezone.now().date()
        
        active_habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        ).count()
        
        heatmap = []
        for day in range(1, days_in_month + 1):
            date = datetime(year, month, day).date()

            # Count completed logs for this specific date
            completed = HabitLog.objects.filter(
                habit__user=user,
                habit__status='active',
                habit__is_deleted=False,
                date=date,
                status='completed'
            ).count()

            # Normalise to a 0.0–1.0 intensity score for the heatmap colour
            intensity = (completed / active_habits) if active_habits > 0 else 0
            
            heatmap.append({
                'date': date.isoformat(),
                'day': day,
                'weekday': date.weekday(),
                'completed': completed,
                'total': active_habits,
                'intensity': round(intensity, 2),
                'isPast': date < today,
                'isToday': date == today,
                'isFuture': date > today,
            })
        
        return heatmap
    
    # =================================================================
    # Per-Habit Statistics
    # =================================================================

    @staticmethod
    def get_habit_stats(user):
        """
        Compile detailed statistics for every active habit belonging to a user.

        Returns a list sorted by 30-day consistency (most consistent first),
        making it easy for the frontend to render a ranked habits table.

        Args:
            user: The requesting ``User`` instance.

        Returns:
            list[dict]: One dict per active habit with streaks, consistency,
                        and success-rate fields.
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        stats = []
        for habit in habits:
            # Calculate streaks for this habit
            current_streak = AnalyticsService.calculate_current_streak(habit)
            best_streak = AnalyticsService.calculate_best_streak(habit)
            
            stats.append({
                'habitId': habit.id,
                'title': habit.title,
                'category': habit.category_name,
                'color': habit.color_value,
                'iconCode': habit.icon_code,
                'currentStreak': current_streak,
                'bestStreak': best_streak,
                'consistency30d': AnalyticsService.get_consistency_percentage(habit, 30),
                'consistency7d': AnalyticsService.get_consistency_percentage(habit, 7),
                'successRate': AnalyticsService.get_habit_success_rate(habit),
            })
        
        # Sort by 30-day consistency descending (best performers first)
        stats.sort(key=lambda x: x['consistency30d'], reverse=True)
        
        return stats
    
    # =================================================================
    # Dashboard Summary
    # =================================================================

    @staticmethod
    def get_dashboard_summary(user):
        """
        Build the high-level summary payload for the analytics dashboard.

        Aggregates today’s completion count, the user’s best and current
        streak, average 30-day consistency, and this week’s completion
        total into a single dict.

        Args:
            user: The requesting ``User`` instance.

        Returns:
            dict: Keys include ``totalHabits``, ``todayCompleted``,
                  ``todayRate``, ``currentStreak``, ``bestStreak``,
                  ``avgConsistency``, and ``weeklyCompletions``.
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        total_habits = habits.count()
        today = timezone.now().date()

        # ── Today’s completion count ──────────────────────────────────────
        today_completed = HabitLog.objects.filter(
            habit__user=user,
            habit__status='active',
            habit__is_deleted=False,
            date=today,
            status='completed'
        ).count()

        # ── Streak & consistency aggregation across all habits ───────────
        overall_current_streak = 0
        overall_best_streak = 0
        total_consistency = 0

        for habit in habits:
            # Recompute from logs to avoid stale cache edge-cases.
            current_streak = AnalyticsService.calculate_current_streak(habit)
            best_streak = AnalyticsService.calculate_best_streak(habit)
            overall_current_streak = max(overall_current_streak, current_streak)
            overall_best_streak = max(overall_best_streak, best_streak)
            
            total_consistency += AnalyticsService.get_consistency_percentage(habit, 30)

        # Derive averages (guard against division by zero)
        avg_consistency = (total_consistency / total_habits) if total_habits > 0 else 0
        today_rate = (today_completed / total_habits * 100) if total_habits > 0 else 0

        # ── This week’s completion total ──────────────────────────────────
        week_start = today - timedelta(days=today.weekday())  # Monday
        weekly_completions = HabitLog.objects.filter(
            habit__user=user,
            habit__status='active',
            habit__is_deleted=False,
            date__range=[week_start, today],
            status='completed'
        ).count()
        
        return {
            'totalHabits': total_habits,
            'todayCompleted': today_completed,
            'todayRate': round(today_rate, 1),
            'currentStreak': overall_current_streak,
            'bestStreak': overall_best_streak,
            'avgConsistency': round(avg_consistency, 1),
            'weeklyCompletions': weekly_completions,
        }
    
    # =================================================================
    # Category Breakdown
    # =================================================================

    @staticmethod
    def get_category_breakdown(user):
        """
        Group the user’s active habits by category and compute the average
        30-day consistency for each group.

        Args:
            user: The requesting ``User`` instance.

        Returns:
            list[dict]: Sorted by ``avgConsistency`` descending. Each dict
                        contains ``category``, ``habitCount``,
                        ``avgConsistency``, and ``habits`` (list of titles).
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        categories = {}
        for habit in habits:
            cat = habit.category_name or 'General'  # Fallback for uncategorised habits
            if cat not in categories:
                categories[cat] = {
                    'name': cat,
                    'habits': [],
                    'totalConsistency': 0,
                    'count': 0,
                }
            
            consistency = AnalyticsService.get_consistency_percentage(habit, 30)
            categories[cat]['habits'].append(habit.title)
            categories[cat]['totalConsistency'] += consistency
            categories[cat]['count'] += 1
        
        # Build the response list and sort by average consistency
        result = []
        for cat, data in categories.items():
            avg = data['totalConsistency'] / data['count'] if data['count'] > 0 else 0
            result.append({
                'category': cat,
                'habitCount': data['count'],
                'avgConsistency': round(avg, 1),
                'habits': data['habits'],
            })
        
        result.sort(key=lambda x: x['avgConsistency'], reverse=True)
        return result
    
    # =================================================================
    # Completion Trend
    # =================================================================

    @staticmethod
    def get_completion_trend(user, days=30):
        """
        Generate a day-by-day completion trend for a line/area chart.

        Args:
            user: The requesting ``User`` instance.
            days: Number of past days to include (default 30).

        Returns:
            list[dict]: One entry per day with ``date``, ``completed``,
                        ``total``, and ``rate``.
        """
        today = timezone.now().date()
        start_date = today - timedelta(days=days-1)
        
        active_habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        ).count()
        
        trend = []
        for i in range(days):
            date = start_date + timedelta(days=i)
            completed = HabitLog.objects.filter(
                habit__user=user,
                habit__status='active',
                habit__is_deleted=False,
                date=date,
                status='completed'
            ).count()
            
            rate = (completed / active_habits * 100) if active_habits > 0 else 0
            
            trend.append({
                'date': date.isoformat(),
                'completed': completed,
                'total': active_habits,
                'rate': round(rate, 1),
            })
        
        return trend

    # =================================================================
    # Enhanced Analytics — Week-over-Week Comparison
    # =================================================================

    @staticmethod
    def get_weekly_comparison(user):
        """
        Compare the current week’s performance against the previous week.

        Returns daily averages for both weeks, a percentage change, and a
        trend label ('improving', 'stable', or 'declining') based on a
        ±5 % threshold.

        Args:
            user: The requesting ``User`` instance.

        Returns:
            dict: ``thisWeek``, ``lastWeek`` sub-dicts, ``changePercent``,
                  and ``trend``.
        """
        today = timezone.now().date()
        this_week_start = today - timedelta(days=today.weekday())  # Monday
        last_week_start = this_week_start - timedelta(days=7)
        last_week_end = this_week_start - timedelta(days=1)  # Sunday
        
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        # Count completions for each week
        this_week = HabitLog.objects.filter(
            habit__in=habits, date__range=[this_week_start, today], status='completed'
        ).count()
        
        last_week = HabitLog.objects.filter(
            habit__in=habits, date__range=[last_week_start, last_week_end], status='completed'
        ).count()

        # Compute daily averages (this week may be partial)
        days_this_week = (today - this_week_start).days + 1
        this_week_daily = round(this_week / days_this_week, 1) if days_this_week > 0 else 0
        last_week_daily = round(last_week / 7, 1)  # Last week is always 7 days

        # Percentage change relative to last week’s daily average
        if last_week > 0:
            change_pct = round(((this_week_daily - last_week_daily) / last_week_daily) * 100, 1)
        else:
            change_pct = 100.0 if this_week > 0 else 0.0

        # Classify trend using a ±5 % dead-band to avoid noise
        trend = 'improving' if change_pct > 5 else ('declining' if change_pct < -5 else 'stable')
        
        return {
            'thisWeek': {
                'completions': this_week,
                'dailyAverage': this_week_daily,
                'daysTracked': days_this_week,
            },
            'lastWeek': {
                'completions': last_week,
                'dailyAverage': last_week_daily,
                'daysTracked': 7,
            },
            'changePercent': change_pct,
            'trend': trend,
        }

    # =================================================================
    # Enhanced Analytics — Difficulty Scoring
    # =================================================================

    @staticmethod
    def get_difficulty_scores(user):
        """
        Assign a difficulty score (1–5) to each active habit based on its
        recent completion rates.

        Lower consistency → higher difficulty. The labels range from
        'Easy' (score 1, ≥80 %) to 'Very Hard' (score 5, <20 %).

        Args:
            user: The requesting ``User`` instance.

        Returns:
            list[dict]: Sorted hardest-first, each with ``difficulty``,
                        ``difficultyLabel``, and consistency metrics.
        """
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        scores = []
        for habit in habits:
            consistency_7d = AnalyticsService.get_consistency_percentage(habit, 7)
            consistency_30d = AnalyticsService.get_consistency_percentage(habit, 30)

            # Inverse mapping: lower consistency → higher difficulty tier
            avg_consistency = (consistency_7d + consistency_30d) / 2
            if avg_consistency >= 80:
                difficulty = 1  # Easy
            elif avg_consistency >= 60:
                difficulty = 2
            elif avg_consistency >= 40:
                difficulty = 3  # Medium
            elif avg_consistency >= 20:
                difficulty = 4
            else:
                difficulty = 5  # Very Hard
            
            labels = {1: 'Easy', 2: 'Moderate', 3: 'Medium', 4: 'Challenging', 5: 'Very Hard'}
            
            scores.append({
                'habitId': habit.id,
                'title': habit.title,
                'category': habit.category_name,
                'difficulty': difficulty,
                'difficultyLabel': labels[difficulty],
                'consistency7d': consistency_7d,
                'consistency30d': consistency_30d,
            })
        
        scores.sort(key=lambda x: x['difficulty'], reverse=True)
        return scores

    # =================================================================
    # Enhanced Analytics — Long-Term Monthly Trends
    # =================================================================

    @staticmethod
    def get_long_term_trends(user, months=6):
        """
        Compute monthly completion rates over the last N months for a
        long-term trend line.

        Args:
            user:   The requesting ``User`` instance.
            months: Number of past months to include (default 6, max 12).

        Returns:
            list[dict]: Chronological list with ``month`` label,
                        ``completions``, ``possibleCompletions``, and
                        ``completionRate``.
        """
        today = timezone.now().date()
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        habit_count = habits.count()
        if habit_count == 0:
            return []
        
        trends = []
        for i in range(months - 1, -1, -1):
            # Calculate approximate month boundaries (walk backwards)
            month_end = today.replace(day=1) - timedelta(days=1) if i > 0 else today
            if i > 0:
                for _ in range(i - 1):
                    month_end = (month_end.replace(day=1) - timedelta(days=1))
            
            month_start = month_end.replace(day=1)
            if i == 0:
                month_start = today.replace(day=1)
                month_end = today
            
            completed = HabitLog.objects.filter(
                habit__in=habits,
                date__range=[month_start, month_end],
                status='completed'
            ).count()
            
            days_in_period = (month_end - month_start).days + 1
            possible = habit_count * days_in_period
            rate = round((completed / possible * 100) if possible > 0 else 0, 1)
            
            trends.append({
                'month': month_start.strftime('%b %Y'),
                'monthStart': month_start.isoformat(),
                'completions': completed,
                'possibleCompletions': possible,
                'completionRate': rate,
            })
        
        return trends

    # =================================================================
    # Enhanced Analytics — Category Success Ratio
    # =================================================================

    @staticmethod
    def get_category_success_ratio(user):
        """
        Calculate the success ratio per habit category.

        Success ratio = (completed logs / total logs) × 100 for every
        habit in the category, giving a more granular view than the
        consistency-based ``get_category_breakdown``.

        Args:
            user: The requesting ``User`` instance.

        Returns:
            list[dict]: Sorted by ``successRatio`` descending.
        """
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        categories = {}
        for habit in habits:
            cat = habit.category_name or 'General'  # Default for uncategorised
            if cat not in categories:
                categories[cat] = {
                    'completed': 0,
                    'total': 0,
                    'habits': 0,
                }
            
            # Accumulate completed and total log counts for this category
            comp = HabitLog.objects.filter(habit=habit, status='completed').count()
            total = HabitLog.objects.filter(habit=habit).count()
            categories[cat]['completed'] += comp
            categories[cat]['total'] += total
            categories[cat]['habits'] += 1
        
        # Build sorted result list
        result = []
        for cat, data in categories.items():
            ratio = round((data['completed'] / data['total'] * 100) if data['total'] > 0 else 0, 1)
            result.append({
                'category': cat,
                'habitCount': data['habits'],
                'completed': data['completed'],
                'totalLogs': data['total'],
                'successRatio': ratio,
            })
        
        result.sort(key=lambda x: x['successRatio'], reverse=True)
        return result

    # =================================================================
    # Enhanced Analytics — Year-Level Productivity Heatmap
    # =================================================================

    @staticmethod
    def get_productivity_heatmap(user, year):
        """
        Generate a full-year productivity heatmap (GitHub-contribution style).

        Each calendar day from Jan 1 to today (or Dec 31 if viewing a past
        year) receives an ``intensity`` value [0.0, 1.0] representing the
        fraction of active habits completed.

        Args:
            user: The requesting ``User`` instance.
            year: Calendar year to generate the heatmap for.

        Returns:
            list[dict]: One entry per day with ``date``, ``intensity``,
                        and ``completed``.
        """
        from calendar import monthrange
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        habit_count = habits.count()
        if habit_count == 0:
            return []
        
        today = timezone.now().date()
        start = timezone.datetime(year, 1, 1).date()  # Jan 1
        end = min(timezone.datetime(year, 12, 31).date(), today)  # Cap at today

        heatmap = []
        current = start
        while current <= end:
            # Count completed logs for this day across all active habits
            completed = HabitLog.objects.filter(
                habit__in=habits, date=current, status='completed'
            ).count()

            # Clamp intensity to [0.0, 1.0]
            intensity = round(min(1.0, completed / habit_count), 2)
            heatmap.append({
                'date': current.isoformat(),
                'intensity': intensity,
                'completed': completed,
            })
            current += timedelta(days=1)
        
        return heatmap