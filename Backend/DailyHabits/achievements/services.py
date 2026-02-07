"""
Achievement Service
Business logic for achievements, badges, and levels
"""

from django.db.models import Sum
from django.utils import timezone

from .models import Achievement, UserAchievement, UserLevel, Reward, UserReward
from habits.models import Habit, HabitLog, Streak


class AchievementService:
    """
    Service for achievement-related operations
    """
    
    # Achievement definitions - can be seeded to database
    ACHIEVEMENT_DEFINITIONS = [
        # Streak achievements
        {
            'name': 'First Step',
            'description': 'Complete a habit for the first time',
            'type': 'streak',
            'target': 1,
            'rarity': 'common',
            'points': 10,
            'icon': 0xE87D,
            'color': 0xFFCD7F32,  # Bronze
        },
        {
            'name': 'Three Day Streak',
            'description': 'Maintain a 3-day streak',
            'type': 'streak',
            'target': 3,
            'rarity': 'common',
            'points': 25,
            'icon': 0xE80E,
            'color': 0xFFCD7F32,
        },
        {
            'name': 'Week Warrior',
            'description': 'Maintain a 7-day streak',
            'type': 'streak',
            'target': 7,
            'rarity': 'uncommon',
            'points': 50,
            'icon': 0xE838,
            'color': 0xFFC0C0C0,  # Silver
        },
        {
            'name': 'Fortnight Fighter',
            'description': 'Maintain a 14-day streak',
            'type': 'streak',
            'target': 14,
            'rarity': 'uncommon',
            'points': 100,
            'icon': 0xE838,
            'color': 0xFFC0C0C0,
        },
        {
            'name': 'Monthly Master',
            'description': 'Maintain a 30-day streak',
            'type': 'streak',
            'target': 30,
            'rarity': 'rare',
            'points': 200,
            'icon': 0xE838,
            'color': 0xFFFFD700,  # Gold
        },
        {
            'name': 'Quarterly Champion',
            'description': 'Maintain a 90-day streak',
            'type': 'streak',
            'target': 90,
            'rarity': 'epic',
            'points': 500,
            'icon': 0xE838,
            'color': 0xFF9400D3,  # Purple
        },
        {
            'name': 'Habit Legend',
            'description': 'Maintain a 365-day streak',
            'type': 'streak',
            'target': 365,
            'rarity': 'legendary',
            'points': 1000,
            'icon': 0xE838,
            'color': 0xFFFF4500,  # Orange Red
        },
        
        # Completion achievements
        {
            'name': 'Getting Started',
            'description': 'Complete 10 habits total',
            'type': 'completion',
            'target': 10,
            'rarity': 'common',
            'points': 20,
            'icon': 0xE876,
            'color': 0xFFCD7F32,
        },
        {
            'name': 'Habit Builder',
            'description': 'Complete 50 habits total',
            'type': 'completion',
            'target': 50,
            'rarity': 'uncommon',
            'points': 75,
            'icon': 0xE876,
            'color': 0xFFC0C0C0,
        },
        {
            'name': 'Century Club',
            'description': 'Complete 100 habits total',
            'type': 'completion',
            'target': 100,
            'rarity': 'rare',
            'points': 150,
            'icon': 0xE876,
            'color': 0xFFFFD700,
        },
        {
            'name': 'Dedication Master',
            'description': 'Complete 500 habits total',
            'type': 'completion',
            'target': 500,
            'rarity': 'epic',
            'points': 400,
            'icon': 0xE876,
            'color': 0xFF9400D3,
        },
        {
            'name': 'Habit Guru',
            'description': 'Complete 1000 habits total',
            'type': 'completion',
            'target': 1000,
            'rarity': 'legendary',
            'points': 1000,
            'icon': 0xE876,
            'color': 0xFFFF4500,
        },
        
        # Consistency achievements
        {
            'name': 'Consistent Starter',
            'description': 'Achieve 70% consistency for a week',
            'type': 'consistency',
            'target': 70,
            'rarity': 'common',
            'points': 30,
            'icon': 0xE8E5,
            'color': 0xFFCD7F32,
        },
        {
            'name': 'Steady Progress',
            'description': 'Achieve 80% consistency for a month',
            'type': 'consistency',
            'target': 80,
            'rarity': 'uncommon',
            'points': 100,
            'icon': 0xE8E5,
            'color': 0xFFC0C0C0,
        },
        {
            'name': 'Perfectionist',
            'description': 'Achieve 100% consistency for a week',
            'type': 'consistency',
            'target': 100,
            'rarity': 'rare',
            'points': 200,
            'icon': 0xE8E5,
            'color': 0xFFFFD700,
        },
        
        # Special achievements
        {
            'name': 'Early Bird',
            'description': 'Complete a habit before 6 AM',
            'type': 'special',
            'target': 1,
            'rarity': 'uncommon',
            'points': 50,
            'icon': 0xE518,
            'color': 0xFF87CEEB,
        },
        {
            'name': 'Night Owl',
            'description': 'Complete a habit after 10 PM',
            'type': 'special',
            'target': 1,
            'rarity': 'uncommon',
            'points': 50,
            'icon': 0xE51C,
            'color': 0xFF191970,
        },
        {
            'name': 'Weekend Warrior',
            'description': 'Complete all habits on weekend',
            'type': 'special',
            'target': 1,
            'rarity': 'uncommon',
            'points': 75,
            'icon': 0xE916,
            'color': 0xFF32CD32,
        },
        {
            'name': 'Comeback Kid',
            'description': 'Resume after a 3+ day break',
            'type': 'special',
            'target': 1,
            'rarity': 'rare',
            'points': 100,
            'icon': 0xE5D5,
            'color': 0xFFFF6347,
        },
        {
            'name': 'Habit Creator',
            'description': 'Create 5 different habits',
            'type': 'milestone',
            'target': 5,
            'rarity': 'common',
            'points': 40,
            'icon': 0xE145,
            'color': 0xFFCD7F32,
        },
        {
            'name': 'Habit Collector',
            'description': 'Create 10 different habits',
            'type': 'milestone',
            'target': 10,
            'rarity': 'uncommon',
            'points': 100,
            'icon': 0xE145,
            'color': 0xFFC0C0C0,
        },
    ]
    
    @classmethod
    def seed_achievements(cls):
        """
        Seed default achievements to database
        """
        created_count = 0
        for defn in cls.ACHIEVEMENT_DEFINITIONS:
            achievement, created = Achievement.objects.get_or_create(
                name=defn['name'],
                defaults={
                    'description': defn['description'],
                    'achievement_type': defn['type'],
                    'target_value': defn['target'],
                    'rarity': defn['rarity'],
                    'points': defn['points'],
                    'icon_code': defn['icon'],
                    'color_value': defn['color'],
                }
            )
            if created:
                created_count += 1
        
        return created_count
    
    @staticmethod
    def check_and_award_achievements(user, habit=None, trigger_type=None):
        """
        Check and award any earned achievements
        Returns list of newly earned achievements
        """
        newly_earned = []
        
        # Get all active achievements
        achievements = Achievement.objects.filter(is_active=True)
        
        for achievement in achievements:
            # Skip if already earned (for non-habit-specific ones)
            if achievement.achievement_type != 'streak':
                if UserAchievement.objects.filter(
                    user=user, 
                    achievement=achievement
                ).exists():
                    continue
            else:
                # For streak achievements, check per habit
                if habit and UserAchievement.objects.filter(
                    user=user, 
                    achievement=achievement,
                    habit=habit
                ).exists():
                    continue
            
            # Check if earned
            earned = False
            earned_value = 0
            
            if achievement.achievement_type == 'streak' and habit:
                try:
                    streak = habit.streak
                    if streak.current_streak >= achievement.target_value:
                        earned = True
                        earned_value = streak.current_streak
                except Streak.DoesNotExist:
                    pass
            
            elif achievement.achievement_type == 'completion':
                total = HabitLog.objects.filter(
                    habit__user=user, 
                    status='completed'
                ).count()
                if total >= achievement.target_value:
                    earned = True
                    earned_value = total
            
            elif achievement.achievement_type == 'milestone':
                # Habit creation milestones
                habit_count = Habit.objects.filter(
                    user=user, 
                    is_deleted=False
                ).count()
                if habit_count >= achievement.target_value:
                    earned = True
                    earned_value = habit_count
            
            if earned:
                user_achievement = UserAchievement.objects.create(
                    user=user,
                    achievement=achievement,
                    habit=habit if achievement.achievement_type == 'streak' else None,
                    earned_value=earned_value,
                )
                newly_earned.append(user_achievement)
                
                # Add XP
                AchievementService.add_user_xp(user, achievement.points)
        
        return newly_earned
    
    @staticmethod
    def add_user_xp(user, amount):
        """
        Add XP to user and handle level ups
        """
        level, created = UserLevel.objects.get_or_create(user=user)
        leveled_up = level.add_xp(amount)
        return leveled_up
    
    @staticmethod
    def get_user_achievements(user):
        """
        Get user's achievement summary
        """
        earned = UserAchievement.objects.filter(user=user).select_related('achievement')
        all_achievements = Achievement.objects.filter(is_active=True, is_hidden=False)
        
        earned_ids = set(ua.achievement_id for ua in earned)
        
        achievements_data = []
        for achievement in all_achievements:
            is_earned = achievement.id in earned_ids
            user_achievement = next(
                (ua for ua in earned if ua.achievement_id == achievement.id), 
                None
            )
            
            achievements_data.append({
                'id': achievement.id,
                'name': achievement.name,
                'description': achievement.description,
                'type': achievement.achievement_type,
                'rarity': achievement.rarity,
                'points': achievement.points,
                'iconCode': achievement.icon_code,
                'colorValue': achievement.color_value,
                'targetValue': achievement.target_value,
                'isEarned': is_earned,
                'earnedAt': user_achievement.earned_at.isoformat() if user_achievement else None,
                'earnedValue': user_achievement.earned_value if user_achievement else 0,
            })
        
        return achievements_data
    
    @staticmethod
    def get_user_level(user):
        """
        Get user's level information
        """
        level, created = UserLevel.objects.get_or_create(user=user)
        
        return {
            'currentLevel': level.current_level,
            'levelName': level.level_name,
            'currentXp': level.current_xp,
            'totalXp': level.total_xp,
            'xpForNextLevel': level.xp_for_next_level,
            'xpProgressPercentage': round(level.xp_progress_percentage, 1),
            'totalAchievements': level.total_achievements,
        }
    
    @staticmethod
    def get_recent_achievements(user, limit=5):
        """
        Get recently earned achievements
        """
        recent = UserAchievement.objects.filter(
            user=user
        ).select_related('achievement').order_by('-earned_at')[:limit]
        
        return [{
            'id': ua.achievement.id,
            'name': ua.achievement.name,
            'description': ua.achievement.description,
            'rarity': ua.achievement.rarity,
            'points': ua.achievement.points,
            'iconCode': ua.achievement.icon_code,
            'colorValue': ua.achievement.color_value,
            'earnedAt': ua.earned_at.isoformat(),
        } for ua in recent]
