"""
Analytics Service
Core business logic for analytics calculations
"""

from datetime import datetime, timedelta
from django.db.models import Count, Sum, Avg, Q
from django.utils import timezone
from calendar import monthrange

from habits.models import Habit, HabitLog, Streak


class AnalyticsService:
    """
    Service class for all analytics calculations
    """
    
    @staticmethod
    def calculate_current_streak(habit):
        """
        Calculate consecutive days completed from today backwards
        """
        today = timezone.now().date()
        streak = 0
        check_date = today
        
        # Check if today is completed, if not start from yesterday
        today_log = HabitLog.objects.filter(
            habit=habit, 
            date=today, 
            status='completed'
        ).exists()
        
        if not today_log:
            check_date = today - timedelta(days=1)
        
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
                break
        
        return streak
    
    @staticmethod
    def calculate_best_streak(habit):
        """
        Calculate the longest consecutive days streak ever achieved
        """
        logs = HabitLog.objects.filter(
            habit=habit, 
            status='completed'
        ).order_by('date').values_list('date', flat=True)
        
        if not logs:
            return 0
        
        logs = list(logs)
        best = current = 1
        
        for i in range(1, len(logs)):
            if (logs[i] - logs[i-1]).days == 1:
                current += 1
                best = max(best, current)
            else:
                current = 1
        
        return best
    
    @staticmethod
    def get_consistency_percentage(habit, days=30):
        """
        Calculate consistency rate over a specified period
        """
        today = timezone.now().date()
        start_date = today - timedelta(days=days-1)
        
        # Get habit start date to avoid counting days before habit existed
        actual_start = max(start_date, habit.start_date) if habit.start_date else start_date
        actual_days = (today - actual_start).days + 1
        
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
        Calculate overall success rate (completed / total tracked days)
        """
        total_logs = HabitLog.objects.filter(habit=habit).count()
        if total_logs == 0:
            return 0.0
        
        completed = HabitLog.objects.filter(habit=habit, status='completed').count()
        return round((completed / total_logs) * 100, 1)
    
    @staticmethod
    def get_weekly_data(user, weeks_back=0):
        """
        Get weekly completion data for charts
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday()) - timedelta(weeks=weeks_back)
        
        active_habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        ).count()
        
        data = []
        day_names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        
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
        Get calendar heatmap data for a month
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
            
            completed = HabitLog.objects.filter(
                habit__user=user,
                habit__status='active',
                habit__is_deleted=False,
                date=date,
                status='completed'
            ).count()
            
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
    
    @staticmethod
    def get_habit_stats(user):
        """
        Get detailed stats for each habit
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        stats = []
        for habit in habits:
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
        
        # Sort by consistency (most consistent first)
        stats.sort(key=lambda x: x['consistency30d'], reverse=True)
        
        return stats
    
    @staticmethod
    def get_dashboard_summary(user):
        """
        Get overall dashboard summary
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        total_habits = habits.count()
        today = timezone.now().date()
        
        # Today's completion
        today_completed = HabitLog.objects.filter(
            habit__user=user,
            habit__status='active',
            habit__is_deleted=False,
            date=today,
            status='completed'
        ).count()
        
        # Calculate overall stats
        overall_current_streak = 0
        overall_best_streak = 0
        total_consistency = 0
        
        for habit in habits:
            try:
                streak = habit.streak
                overall_current_streak = max(overall_current_streak, streak.current_streak)
                overall_best_streak = max(overall_best_streak, streak.best_streak)
            except Streak.DoesNotExist:
                pass
            
            total_consistency += AnalyticsService.get_consistency_percentage(habit, 30)
        
        avg_consistency = (total_consistency / total_habits) if total_habits > 0 else 0
        today_rate = (today_completed / total_habits * 100) if total_habits > 0 else 0
        
        # This week's total completions
        week_start = today - timedelta(days=today.weekday())
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
    
    @staticmethod
    def get_category_breakdown(user):
        """
        Get completion rates by category
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        categories = {}
        for habit in habits:
            cat = habit.category_name or 'General'
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
    
    @staticmethod
    def get_completion_trend(user, days=30):
        """
        Get daily completion trend for trend line chart
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

    # ─── ENHANCED ANALYTICS ────────────────────────────────────────────

    @staticmethod
    def get_weekly_comparison(user):
        """
        Compare this week vs last week for weekly insights
        """
        today = timezone.now().date()
        this_week_start = today - timedelta(days=today.weekday())
        last_week_start = this_week_start - timedelta(days=7)
        last_week_end = this_week_start - timedelta(days=1)
        
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        this_week = HabitLog.objects.filter(
            habit__in=habits, date__range=[this_week_start, today], status='completed'
        ).count()
        
        last_week = HabitLog.objects.filter(
            habit__in=habits, date__range=[last_week_start, last_week_end], status='completed'
        ).count()
        
        days_this_week = (today - this_week_start).days + 1
        this_week_daily = round(this_week / days_this_week, 1) if days_this_week > 0 else 0
        last_week_daily = round(last_week / 7, 1)
        
        if last_week > 0:
            change_pct = round(((this_week_daily - last_week_daily) / last_week_daily) * 100, 1)
        else:
            change_pct = 100.0 if this_week > 0 else 0.0
        
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

    @staticmethod
    def get_difficulty_scores(user):
        """
        Calculate difficulty scores based on completion rates
        Easy habits (high completion) get lower scores; hard ones get higher.
        """
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        scores = []
        for habit in habits:
            consistency_7d = AnalyticsService.get_consistency_percentage(habit, 7)
            consistency_30d = AnalyticsService.get_consistency_percentage(habit, 30)
            
            # Inverse relation: lower consistency = higher difficulty
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

    @staticmethod
    def get_long_term_trends(user, months=6):
        """
        Long-term consistency trends — monthly averages over N months
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
            # Approximate month start/end
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

    @staticmethod
    def get_category_success_ratio(user):
        """
        Success ratio per category — completed vs total logs
        """
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        
        categories = {}
        for habit in habits:
            cat = habit.category_name or 'General'
            if cat not in categories:
                categories[cat] = {
                    'completed': 0,
                    'total': 0,
                    'habits': 0,
                }
            
            comp = HabitLog.objects.filter(habit=habit, status='completed').count()
            total = HabitLog.objects.filter(habit=habit).count()
            categories[cat]['completed'] += comp
            categories[cat]['total'] += total
            categories[cat]['habits'] += 1
        
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

    @staticmethod
    def get_productivity_heatmap(user, year):
        """
        Year-level productivity heatmap — one intensity value per day
        """
        from calendar import monthrange
        habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        habit_count = habits.count()
        if habit_count == 0:
            return []
        
        today = timezone.now().date()
        start = timezone.datetime(year, 1, 1).date()
        end = min(timezone.datetime(year, 12, 31).date(), today)
        
        heatmap = []
        current = start
        while current <= end:
            completed = HabitLog.objects.filter(
                habit__in=habits, date=current, status='completed'
            ).count()
            
            intensity = round(min(1.0, completed / habit_count), 2)
            heatmap.append({
                'date': current.isoformat(),
                'intensity': intensity,
                'completed': completed,
            })
            current += timedelta(days=1)
        
        return heatmap