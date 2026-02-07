"""
Social Sharing Service
Business logic for share cards, referrals, and group habits
"""

import random
import string
from datetime import timedelta
from django.utils import timezone
from django.db.models import Count, Avg

from .models import ShareCard, SharingPrivacy, ReferralLink, Referral, GroupHabit, GroupMember, Friendship
from habits.models import Habit, HabitLog, Streak


class SocialService:
    """
    Core service for social sharing features
    """

    # ── Friend helpers ────────────────────────────────────────────────

    @staticmethod
    def get_friend_ids(user):
        """Return list of user IDs who are confirmed friends."""
        from django.db.models import Q
        friendships = Friendship.objects.filter(
            Q(from_user=user) | Q(to_user=user),
            status='accepted',
        )
        ids = set()
        for f in friendships:
            ids.add(f.to_user_id if f.from_user_id == user.id else f.from_user_id)
        return list(ids)

    @staticmethod
    def get_friends(user):
        """Return list of friend dicts with user info + friendship data."""
        from django.db.models import Q
        friendships = Friendship.objects.filter(
            Q(from_user=user) | Q(to_user=user),
            status='accepted',
        ).select_related('from_user', 'to_user')
        friends = []
        for f in friendships:
            friend = f.to_user if f.from_user_id == user.id else f.from_user
            friends.append({
                'id': friend.id,
                'name': friend.name,
                'email': friend.email,
                'profileImage': friend.profile_image,
                'currentStreak': friend.current_streak,
                'totalHabitsCompleted': friend.total_habits_completed,
                'friendshipId': f.id,
            })
        return friends

    @staticmethod
    def generate_daily_share_card(user):
        """
        Generate a daily summary share card
        """
        today = timezone.now().date()
        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)
        
        # Get sharable habits (respecting privacy)
        private_habit_ids = SharingPrivacy.objects.filter(
            user=user, allow_in_summary=False
        ).values_list('habit_id', flat=True)
        
        sharable_habits = habits.exclude(id__in=private_habit_ids)
        
        total = sharable_habits.count()
        completed = HabitLog.objects.filter(
            habit__in=sharable_habits,
            date=today,
            status='completed'
        ).count()
        
        rate = round((completed / total * 100) if total > 0 else 0, 1)
        
        # Get max streak
        max_streak = 0
        for habit in sharable_habits:
            try:
                max_streak = max(max_streak, habit.streak.current_streak)
            except Streak.DoesNotExist:
                pass
        
        card_data = {
            'completedHabits': completed,
            'totalHabits': total,
            'completionRate': rate,
            'currentStreak': max_streak,
            'date': today.isoformat(),
            'userName': user.name,
        }
        
        card = ShareCard.objects.create(
            user=user,
            share_type='daily',
            title=f'Daily Progress - {today.strftime("%b %d")}',
            subtitle=f'{completed}/{total} habits completed',
            card_data=card_data,
            habits_completed=completed,
            total_habits=total,
            streak_count=max_streak,
            completion_rate=rate,
            period_start=today,
            period_end=today,
        )
        
        return card

    @staticmethod
    def generate_weekly_share_card(user):
        """
        Generate a weekly summary share card
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday())
        
        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)
        private_ids = SharingPrivacy.objects.filter(
            user=user, allow_in_summary=False
        ).values_list('habit_id', flat=True)
        sharable = habits.exclude(id__in=private_ids)
        
        total_possible = sharable.count() * 7
        completed = HabitLog.objects.filter(
            habit__in=sharable,
            date__range=[week_start, today],
            status='completed'
        ).count()
        
        rate = round((completed / total_possible * 100) if total_possible > 0 else 0, 1)
        
        # Daily breakdown
        daily_data = []
        day_names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        for i in range(7):
            d = week_start + timedelta(days=i)
            if d > today:
                break
            day_completed = HabitLog.objects.filter(
                habit__in=sharable, date=d, status='completed'
            ).count()
            daily_data.append({
                'day': day_names[i],
                'completed': day_completed,
                'total': sharable.count(),
            })
        
        max_streak = 0
        for h in sharable:
            try:
                max_streak = max(max_streak, h.streak.current_streak)
            except Streak.DoesNotExist:
                pass
        
        card_data = {
            'weeklyCompleted': completed,
            'weeklyTotal': total_possible,
            'completionRate': rate,
            'currentStreak': max_streak,
            'dailyBreakdown': daily_data,
            'weekStart': week_start.isoformat(),
            'weekEnd': today.isoformat(),
            'userName': user.name,
        }
        
        card = ShareCard.objects.create(
            user=user,
            share_type='weekly',
            title=f'Weekly Summary - Week {today.isocalendar()[1]}',
            subtitle=f'{rate}% completion rate',
            card_data=card_data,
            habits_completed=completed,
            total_habits=total_possible,
            streak_count=max_streak,
            completion_rate=rate,
            period_start=week_start,
            period_end=today,
        )
        
        return card

    @staticmethod
    def generate_streak_share_card(user, habit):
        """
        Generate a streak milestone share card
        """
        privacy = SharingPrivacy.objects.filter(user=user, habit=habit).first()
        if privacy and not privacy.allow_streak_share:
            return None
        
        try:
            streak = habit.streak
        except Streak.DoesNotExist:
            return None
        
        today = timezone.now().date()
        card_data = {
            'habitTitle': habit.title,
            'currentStreak': streak.current_streak,
            'bestStreak': streak.best_streak,
            'totalCompletions': streak.total_completions,
            'userName': user.name,
            'category': habit.category_name,
        }
        
        card = ShareCard.objects.create(
            user=user,
            share_type='streak',
            title=f'🔥 {streak.current_streak} Day Streak!',
            subtitle=f'{habit.title}',
            card_data=card_data,
            streak_count=streak.current_streak,
            period_start=today,
            period_end=today,
        )
        
        return card

    @staticmethod
    def get_user_share_cards(user, share_type=None, limit=20):
        """
        Get user's share cards
        """
        queryset = ShareCard.objects.filter(user=user)
        if share_type:
            queryset = queryset.filter(share_type=share_type)
        return queryset[:limit]

    @staticmethod
    def generate_referral_code():
        """Generate a unique referral code"""
        chars = string.ascii_uppercase + string.digits
        while True:
            code = ''.join(random.choices(chars, k=8))
            if not ReferralLink.objects.filter(code=code).exists():
                return code

    @staticmethod
    def create_referral_link(user):
        """Create a referral link for a user"""
        link, created = ReferralLink.objects.get_or_create(
            referrer=user,
            is_active=True,
            defaults={
                'code': SocialService.generate_referral_code(),
                'expires_at': timezone.now() + timedelta(days=30),
            }
        )
        return link

    @staticmethod
    def use_referral_code(code, new_user):
        """Process a referral signup"""
        try:
            link = ReferralLink.objects.get(code=code, is_active=True)
            if not link.is_valid:
                return False
            
            Referral.objects.create(
                referrer=link.referrer,
                referred_user=new_user,
                referral_link=link,
            )
            link.uses_count += 1
            link.save()
            return True
        except ReferralLink.DoesNotExist:
            return False

    @staticmethod
    def get_privacy_settings(user):
        """Get all privacy settings for a user's habits"""
        habits = Habit.objects.filter(user=user, is_deleted=False)
        settings_map = {}
        
        existing = SharingPrivacy.objects.filter(user=user)
        for p in existing:
            settings_map[p.habit_id] = {
                'habitId': p.habit_id,
                'allowInSummary': p.allow_in_summary,
                'allowStreakShare': p.allow_streak_share,
                'allowInGroup': p.allow_in_group,
                'showDetails': p.show_details,
            }
        
        result = []
        for habit in habits:
            if habit.id in settings_map:
                result.append({
                    'habitTitle': habit.title,
                    **settings_map[habit.id]
                })
            else:
                result.append({
                    'habitId': habit.id,
                    'habitTitle': habit.title,
                    'allowInSummary': True,
                    'allowStreakShare': True,
                    'allowInGroup': True,
                    'showDetails': False,
                })
        
        return result

    @staticmethod
    def update_privacy_setting(user, habit_id, **kwargs):
        """Update privacy settings for a habit"""
        setting, created = SharingPrivacy.objects.get_or_create(
            user=user,
            habit_id=habit_id,
        )
        for key, value in kwargs.items():
            if hasattr(setting, key):
                setattr(setting, key, value)
        setting.save()
        return setting

    @staticmethod
    def generate_invite_code():
        """Generate a unique group invite code"""
        chars = string.ascii_uppercase + string.digits
        while True:
            code = ''.join(random.choices(chars, k=6))
            if not GroupHabit.objects.filter(invite_code=code).exists():
                return code

    @staticmethod
    def create_group_habit(user, name, description='', habit_template=None):
        """Create a group habit"""
        group = GroupHabit.objects.create(
            name=name,
            description=description,
            creator=user,
            invite_code=SocialService.generate_invite_code(),
            habit_template=habit_template or {},
        )
        
        # Creator is automatically an admin member
        GroupMember.objects.create(
            group=group,
            user=user,
            role='admin',
        )
        
        return group

    @staticmethod
    def join_group(user, invite_code):
        """Join a group habit via invite code"""
        try:
            group = GroupHabit.objects.get(invite_code=invite_code, is_active=True)
            
            if group.member_count >= group.max_members:
                return {'success': False, 'message': 'Group is full'}
            
            if GroupMember.objects.filter(group=group, user=user).exists():
                return {'success': False, 'message': 'Already a member'}
            
            member = GroupMember.objects.create(
                group=group,
                user=user,
                role='member',
            )
            
            return {'success': True, 'group': group, 'member': member}
        except GroupHabit.DoesNotExist:
            return {'success': False, 'message': 'Invalid invite code'}

    @staticmethod
    def get_group_leaderboard(group_id):
        """Get group leaderboard based on completions"""
        members = GroupMember.objects.filter(
            group_id=group_id, is_active=True
        ).select_related('user', 'habit')
        
        leaderboard = []
        for member in members:
            if member.habit:
                try:
                    streak = member.habit.streak.current_streak
                except Streak.DoesNotExist:
                    streak = 0
                
                total = HabitLog.objects.filter(
                    habit=member.habit, status='completed'
                ).count()
            else:
                streak = 0
                total = 0
            
            leaderboard.append({
                'userName': member.user.name,
                'currentStreak': streak,
                'totalCompletions': total,
                'role': member.role,
                'joinedAt': member.joined_at.isoformat(),
            })
        
        leaderboard.sort(key=lambda x: x['totalCompletions'], reverse=True)
        return leaderboard
