"""
Insights Service
Smart insights, motivational content, and personalized recommendations
"""

import random
from datetime import datetime, timedelta
from django.db.models import Count
from django.utils import timezone

from habits.models import Habit, HabitLog
from .models import MotivationalQuote, UserInsight


class InsightService:
    """
    Service for generating personalized insights
    """
    
    # Default motivational quotes
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
    
    # Comeback encouragement messages
    COMEBACK_MESSAGES = [
        "Welcome back! Every journey has ups and downs. What matters is you're here now. 💪",
        "Missing a few days is okay - what's important is that you're back! Let's go! 🔥",
        "The best time to restart is now. You've got this! 🌟",
        "One step back, two steps forward. Your comeback starts today! 🚀",
        "Every expert was once a beginner. Every champion was once someone who refused to give up. 💫",
    ]
    
    # Streak celebration messages
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
    
    @classmethod
    def seed_quotes(cls):
        """
        Seed default quotes to database
        """
        created = 0
        for q in cls.DEFAULT_QUOTES:
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
        Get a motivational quote for today
        """
        # Try database first
        quotes = MotivationalQuote.objects.filter(
            is_active=True,
            category=category
        )
        
        if quotes.exists():
            # Get least shown quotes to ensure variety
            quote = quotes.order_by('times_shown').first()
            quote.times_shown += 1
            quote.save()
            return {
                'quote': quote.quote,
                'author': quote.author or 'Unknown',
                'category': quote.category,
            }
        
        # Fallback to default quotes
        q = random.choice(InsightService.DEFAULT_QUOTES)
        return {
            'quote': q['quote'],
            'author': q['author'],
            'category': 'general',
        }
    
    @staticmethod
    def get_best_performance_time(user):
        """
        Analyze when user completes habits most frequently
        """
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
        
        time_slots = {
            'early_morning': {'range': (5, 8), 'count': 0, 'label': 'Early Morning (5-8 AM)'},
            'morning': {'range': (8, 12), 'count': 0, 'label': 'Morning (8 AM-12 PM)'},
            'afternoon': {'range': (12, 17), 'count': 0, 'label': 'Afternoon (12-5 PM)'},
            'evening': {'range': (17, 21), 'count': 0, 'label': 'Evening (5-9 PM)'},
            'night': {'range': (21, 24), 'count': 0, 'label': 'Night (9 PM+)'},
        }
        
        for dt in logs:
            hour = dt.hour
            for slot, data in time_slots.items():
                start, end = data['range']
                if start <= hour < end or (slot == 'night' and (hour >= 21 or hour < 5)):
                    data['count'] += 1
                    break
        
        total = sum(d['count'] for d in time_slots.values())
        if total == 0:
            return {'time': 'morning', 'percentage': 0, 'insight': 'No data yet'}
        
        best_slot = max(time_slots.items(), key=lambda x: x[1]['count'])
        percentage = (best_slot[1]['count'] / total) * 100
        
        return {
            'time': best_slot[0],
            'timeLabel': best_slot[1]['label'],
            'percentage': round(percentage, 1),
            'insight': f"You're most productive in the {best_slot[1]['label']}! "
                      f"{round(percentage)}% of your habits are completed then.",
        }
    
    @staticmethod
    def get_most_consistent_habits(user, limit=3):
        """
        Find the most consistent habits
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        today = timezone.now().date()
        start_date = today - timedelta(days=30)
        
        habit_consistency = []
        for habit in habits:
            # Calculate consistency over last 30 days
            days_active = max(1, (today - max(habit.start_date, start_date)).days + 1)
            completed = HabitLog.objects.filter(
                habit=habit,
                date__range=[start_date, today],
                status='completed'
            ).count()
            
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
        
        sorted_habits = sorted(
            habit_consistency, 
            key=lambda x: x['consistency'], 
            reverse=True
        )
        
        return sorted_habits[:limit]
    
    @staticmethod
    def get_declining_habits(user, limit=3):
        """
        Find habits with declining performance
        """
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        today = timezone.now().date()
        
        declining = []
        for habit in habits:
            # Last 7 days vs previous 7 days
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
        
        return sorted(declining, key=lambda x: x['declinePercent'], reverse=True)[:limit]
    
    @staticmethod
    def get_daily_insights(user):
        """
        Generate personalized daily insights
        """
        insights = []
        
        # Best performance time
        best_time = InsightService.get_best_performance_time(user)
        if best_time['percentage'] > 0:
            insights.append({
                'type': 'best_time',
                'title': 'Peak Performance Time',
                'message': best_time['insight'],
                'iconCode': 0xE8B5,
                'colorValue': 0xFF3B82F6,
                'priority': 'medium',
            })
        
        # Most consistent habits
        consistent = InsightService.get_most_consistent_habits(user, 1)
        if consistent and consistent[0]['consistency'] >= 70:
            habit = consistent[0]
            insights.append({
                'type': 'consistent_habit',
                'title': 'Star Performer',
                'message': f"'{habit['title']}' is your most consistent habit at "
                          f"{habit['consistency']}% completion rate! Keep it up! 🌟",
                'iconCode': 0xE838,
                'colorValue': 0xFF10B981,
                'priority': 'low',
                'habitId': habit['id'],
            })
        
        # Declining habits alert
        declining = InsightService.get_declining_habits(user, 1)
        if declining:
            habit = declining[0]
            insights.append({
                'type': 'declining_habit',
                'title': 'Needs Attention',
                'message': habit['insight'],
                'iconCode': 0xE002,
                'colorValue': 0xFFF59E0B,
                'priority': 'high',
                'habitId': habit['id'],
            })
        
        # Streak status
        from habits.models import Streak
        max_streak = 0
        for habit in Habit.objects.filter(user=user, status='active', is_deleted=False):
            try:
                max_streak = max(max_streak, habit.streak.current_streak)
            except Streak.DoesNotExist:
                pass
        
        # Check for milestone streaks
        for days, message in InsightService.STREAK_CELEBRATIONS.items():
            if max_streak == days:
                insights.append({
                    'type': 'streak_milestone',
                    'title': 'Streak Milestone!',
                    'message': message,
                    'iconCode': 0xE80E,
                    'colorValue': 0xFFEF4444,
                    'priority': 'high',
                })
                break
        
        return insights
    
    @staticmethod
    def get_comeback_message(user):
        """
        Get encouragement message for returning users
        """
        # Check days since last completion
        last_log = HabitLog.objects.filter(
            habit__user=user,
            status='completed'
        ).order_by('-date').first()
        
        if not last_log:
            return {
                'showComeback': False,
                'message': None,
            }
        
        days_since = (timezone.now().date() - last_log.date).days
        
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
        Get personalized recommendations
        """
        recommendations = []
        
        habits = Habit.objects.filter(
            user=user, 
            status='active', 
            is_deleted=False
        )
        
        # Check habits without reminders
        no_reminder_count = habits.filter(reminder_enabled=False).count()
        if no_reminder_count > 0:
            recommendations.append({
                'type': 'reminder',
                'title': 'Set Reminders',
                'message': f"You have {no_reminder_count} habits without reminders. "
                          f"Setting reminders can improve consistency by up to 40%!",
                'actionType': 'enable_reminders',
            })
        
        # Check low consistency habits
        today = timezone.now().date()
        for habit in habits:
            completed = HabitLog.objects.filter(
                habit=habit,
                date__range=[today - timedelta(days=7), today],
                status='completed'
            ).count()
            
            if completed < 3:  # Less than 50% for the week
                recommendations.append({
                    'type': 'adjust_habit',
                    'title': f"Revise '{habit.title}'",
                    'message': f"Consider making this habit easier or more specific. "
                              f"Start small and build up gradually.",
                    'habitId': habit.id,
                    'actionType': 'edit_habit',
                })
                break  # Show only one
        
        return recommendations
