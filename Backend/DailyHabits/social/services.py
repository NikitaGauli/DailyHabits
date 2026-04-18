"""
Social Sharing Service
======================

Centralised business-logic layer for all social and community features.
Keeping logic here (rather than in views) ensures consistency across
API endpoints and simplifies unit testing.

Responsibilities:
    - **Friend helpers**: resolve friend lists and IDs from bidirectional
      ``Friendship`` rows.
    - **Share-card generation**: build daily, weekly, and streak summary
      cards while respecting per-habit privacy settings.
    - **Referral system**: code generation, link creation, and sign-up
      processing with usage-cap enforcement.
    - **Privacy settings**: CRUD for per-habit sharing preferences.
    - **Group habits**: creation, join-by-invite-code, and leaderboard
      computation.

All public methods are ``@staticmethod`` so callers never need to
instantiate ``SocialService``.
"""

import random
import string
from datetime import timedelta
from django.utils import timezone
from django.db.models import Count, Avg, Q, Sum

from .models import (
    ShareCard, SharingPrivacy, ReferralLink, Referral,
    GroupHabit, GroupMember, Friendship,
    FeedPost, PostComment,
    SharedHabit, HabitReaction, HabitComment,
    GroupChallenge, Encouragement,
)
from habits.models import Habit, HabitLog, Streak
from gamification.models import ChallengeParticipant


class SocialService:
    """
    Core service encapsulating all social-feature business logic.

    Every method is a ``@staticmethod`` — no instance state is needed.
    The class serves purely as a namespace to group related operations.
    """

    # ═══════════════════════════════════════════════════════════════════
    #  FRIEND HELPERS
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_friend_ids(user):
        """Return a list of user IDs who are confirmed friends.

        Queries both directions of the ``Friendship`` relationship
        (from_user / to_user) and returns the *other* user's ID for
        each accepted friendship.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            list[int]: IDs of all confirmed friends.
        """
        from django.db.models import Q
        friendships = Friendship.objects.filter(
            Q(from_user=user) | Q(to_user=user),
            status='accepted',
        )
        # Collect the *other* user's ID from each accepted friendship
        ids = set()
        for f in friendships:
            ids.add(f.to_user_id if f.from_user_id == user.id else f.from_user_id)  # type: ignore[attr-defined]
        return list(ids)

    @staticmethod
    def get_friends(user):
        """Return a list of friend dicts with user info and friendship data.

        Each dict includes the friend's profile fields and the
        ``friendshipId`` so the caller can reference or remove the
        friendship.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            list[dict]: Friend profile dictionaries.
        """
        from django.db.models import Q
        friendships = Friendship.objects.filter(
            Q(from_user=user) | Q(to_user=user),
            status='accepted',
        ).select_related('from_user', 'to_user')  # Eager-load both sides

        friends = []
        for f in friendships:
            # Determine which side is the *other* user
            friend = f.to_user if f.from_user_id == user.id else f.from_user  # type: ignore[attr-defined]
            friends.append({
                'id': friend.id,
                'name': friend.name,
                'email': friend.email,
                'profileImage': friend.profile_image,
                'currentStreak': friend.current_streak,
                'totalHabitsCompleted': friend.total_habits_completed,
                'friendshipId': f.id,  # type: ignore[attr-defined]
            })
        return friends

    # ═══════════════════════════════════════════════════════════════════
    #  SHARE-CARD GENERATION
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def generate_daily_share_card(user):
        """Generate a daily summary share card for the given user.

        Collects today's habit completion stats (respecting privacy
        settings) and persists a new ``ShareCard`` with type ``'daily'``.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            ShareCard: The newly created daily share card.
        """
        today = timezone.now().date()
        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)

        # Exclude habits the user has opted out of summaries
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

        # Calculate completion percentage (guard against division by zero)
        rate = round((completed / total * 100) if total > 0 else 0, 1)

        # Determine the best current streak across all sharable habits
        max_streak = 0
        for habit in sharable_habits:
            try:
                max_streak = max(max_streak, habit.streak.current_streak)  # type: ignore[attr-defined]
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
        """Generate a weekly summary share card for the given user.

        Aggregates habit completions from Monday of the current week
        through today, builds a daily-breakdown chart payload, and
        persists a new ``ShareCard`` with type ``'weekly'``.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            ShareCard: The newly created weekly share card.
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday())  # Monday

        habits = Habit.objects.filter(user=user, status='active', is_deleted=False)

        # Respect per-habit privacy opt-outs
        private_ids = SharingPrivacy.objects.filter(
            user=user, allow_in_summary=False
        ).values_list('habit_id', flat=True)
        sharable = habits.exclude(id__in=private_ids)

        # Total possible completions = sharable habits × 7 days
        total_possible = sharable.count() * 7
        completed = HabitLog.objects.filter(
            habit__in=sharable,
            date__range=[week_start, today],
            status='completed'
        ).count()

        # Weekly completion rate (guard against zero)
        rate = round((completed / total_possible * 100) if total_possible > 0 else 0, 1)

        # Build per-day breakdown for the bar chart on the share card
        daily_data = []
        day_names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        for i in range(7):
            d = week_start + timedelta(days=i)
            if d > today:  # Don't include future days
                break
            day_completed = HabitLog.objects.filter(
                habit__in=sharable, date=d, status='completed'
            ).count()
            daily_data.append({
                'day': day_names[i],
                'completed': day_completed,
                'total': sharable.count(),
            })

        # Determine best current streak across sharable habits
        max_streak = 0
        for h in sharable:
            try:
                max_streak = max(max_streak, h.streak.current_streak)  # type: ignore[attr-defined]
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
        """Generate a streak milestone share card for a specific habit.

        Checks privacy settings first — if the user has disabled streak
        sharing for this habit, returns ``None``.

        Args:
            user: The authenticated ``User`` instance.
            habit: The ``Habit`` whose streak to celebrate.

        Returns:
            ShareCard | None: The new card, or ``None`` if privacy blocks it.
        """
        privacy = SharingPrivacy.objects.filter(user=user, habit=habit).first()
        if privacy and not privacy.allow_streak_share:
            return None  # User has opted out of streak sharing for this habit
        
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
        """Retrieve recent share cards for a user.

        Args:
            user: The authenticated ``User`` instance.
            share_type (str | None): Optional filter (``'daily'``, ``'weekly'``,
                ``'streak'``, etc.).  ``None`` returns all types.
            limit (int): Maximum number of cards to return (default 20).

        Returns:
            QuerySet[ShareCard]: Ordered newest-first.
        """
        queryset = ShareCard.objects.filter(user=user)
        if share_type:
            queryset = queryset.filter(share_type=share_type)
        return queryset[:limit]

    # ═══════════════════════════════════════════════════════════════════
    #  REFERRAL SYSTEM
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def generate_referral_code():
        """Generate a unique 8-character alphanumeric referral code.

        Loops until a code is found that does not collide with existing
        ``ReferralLink`` rows.

        Returns:
            str: A unique referral code.
        """
        chars = string.ascii_uppercase + string.digits
        while True:
            code = ''.join(random.choices(chars, k=8))
            if not ReferralLink.objects.filter(code=code).exists():
                return code

    @staticmethod
    def create_referral_link(user):
        """Get or create an active referral link for a user.

        If the user already has an active link it is returned; otherwise
        a new one is created with a 30-day expiry.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            ReferralLink: The active (possibly newly created) referral link.
        """
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
        """Process a referral sign-up.

        Validates the referral code, creates a ``Referral`` record
        linking the referrer to the new user, and increments the
        link's usage counter.

        Args:
            code (str): The referral code submitted at sign-up.
            new_user: The newly registered ``User`` instance.

        Returns:
            bool: ``True`` if the referral was successfully recorded;
                  ``False`` if the code is invalid or exhausted.
        """
        try:
            link = ReferralLink.objects.get(code=code, is_active=True)
            if not link.is_valid:  # Check usage cap and expiry
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

    # ═══════════════════════════════════════════════════════════════════
    #  PRIVACY SETTINGS
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_privacy_settings(user):
        """Return privacy settings for every habit owned by the user.

        Habits without an explicit ``SharingPrivacy`` row are returned
        with all-sharing-enabled defaults so the frontend always
        receives a complete list.

        Args:
            user: The authenticated ``User`` instance.

        Returns:
            list[dict]: Per-habit privacy dictionaries.
        """
        habits = Habit.objects.filter(user=user, is_deleted=False)

        # Index existing overrides by habit ID for O(1) lookup
        settings_map = {}
        
        existing = SharingPrivacy.objects.filter(user=user)
        for p in existing:
            settings_map[p.habit_id] = {  # type: ignore[attr-defined]
                'habitId': p.habit_id,  # type: ignore[attr-defined]
                'allowInSummary': p.allow_in_summary,
                'allowStreakShare': p.allow_streak_share,
                'allowInGroup': p.allow_in_group,
                'showDetails': p.show_details,
            }
        
        result = []
        for habit in habits:
            if habit.id in settings_map:
                # Merge the habit title into the existing override
                result.append({
                    'habitTitle': habit.title,
                    **settings_map[habit.id]
                })
            else:
                # No override exists — return permissive defaults
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
        """Create or update privacy settings for a specific habit.

        Uses ``get_or_create`` to ensure idempotency. Only attributes
        that exist on the ``SharingPrivacy`` model are applied.

        Args:
            user: The authenticated ``User`` instance.
            habit_id (int): Primary key of the target ``Habit``.
            **kwargs: Field-name / value pairs to set (e.g.
                ``allow_in_summary=False``).

        Returns:
            SharingPrivacy: The updated (or newly created) instance.
        """
        setting, created = SharingPrivacy.objects.get_or_create(
            user=user,
            habit_id=habit_id,
        )
        for key, value in kwargs.items():
            if hasattr(setting, key):
                setattr(setting, key, value)
        setting.save()
        return setting

    # ═══════════════════════════════════════════════════════════════════
    #  GROUP HABITS
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def generate_invite_code():
        """Generate a unique 6-character alphanumeric group invite code.

        Returns:
            str: A unique invite code.
        """
        chars = string.ascii_uppercase + string.digits
        while True:
            code = ''.join(random.choices(chars, k=6))
            if not GroupHabit.objects.filter(invite_code=code).exists():
                return code

    @staticmethod
    def create_group_habit(user, name, description='', habit_template=None):
        """Create a new group habit and add the creator as admin.

        Args:
            user: The authenticated ``User`` who will be the group admin.
            name (str): Display name for the group.
            description (str): Optional group description.
            habit_template (dict | None): Optional habit template JSON.

        Returns:
            GroupHabit: The newly created group.
        """
        group = GroupHabit.objects.create(
            name=name,
            description=description,
            creator=user,
            invite_code=SocialService.generate_invite_code(),
            habit_template=habit_template or {},
        )

        # The creator is automatically enrolled as an admin member
        GroupMember.objects.create(
            group=group,
            user=user,
            role='admin',
        )
        
        return group

    @staticmethod
    def join_group(user, invite_code):
        """Join a group habit via invite code.

        Validates the code, checks capacity, prevents duplicate
        membership, and creates a new ``GroupMember`` row.

        Args:
            user: The authenticated ``User`` instance.
            invite_code (str): The 6-character invite code.

        Returns:
            dict: ``{'success': True, 'group': ..., 'member': ...}`` on
                success, or ``{'success': False, 'message': ...}`` on failure.
        """
        try:
            group = GroupHabit.objects.get(invite_code=invite_code, is_active=True)

            # Enforce group capacity limit
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
        """Compute a leaderboard for a group based on total completions.

        Each member's linked habit (if any) supplies the streak and
        completion count. Results are sorted descending by total
        completions.

        Args:
            group_id (int): Primary key of the ``GroupHabit``.

        Returns:
            list[dict]: Leaderboard entries sorted by ``totalCompletions``.
        """
        members = GroupMember.objects.filter(
            group_id=group_id, is_active=True
        ).select_related('user', 'habit')  # Eager-load for performance
        
        leaderboard = []
        for member in members:
            if member.habit:
                # Attempt to read the member's streak; default to 0
                try:
                    streak = member.habit.streak.current_streak
                except Streak.DoesNotExist:
                    streak = 0
                
                total = HabitLog.objects.filter(
                    habit=member.habit, status='completed'
                ).count()
            else:
                streak = 0  # No linked habit — no stats available
                total = 0
            
            leaderboard.append({
                'userName': member.user.name,
                'currentStreak': streak,
                'totalCompletions': total,
                'role': member.role,
                'joinedAt': member.joined_at.isoformat(),
            })
        
        # Sort descending by total completions (most active members first)
        leaderboard.sort(key=lambda x: x['totalCompletions'], reverse=True)
        return leaderboard

    # ═══════════════════════════════════════════════════════════════════════
    #  HABIT SHARING
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def share_habit(user, habit_id, friend_ids, can_comment=True, can_react=True):
        """
        Share a habit with one or more friends.

        Validates ownership and friendship before bulk-creating
        ``SharedHabit`` records.  Automatically upgrades the habit's
        visibility from ``private`` → ``friends_only`` so shared
        recipients can discover it.

        Returns:
            dict with ``sharedCount`` (int) and ``message`` (str).

        Raises:
            ValueError: If the habit doesn't belong to the user or
                a target user is not a confirmed friend.
        """
        try:
            habit = Habit.objects.get(pk=habit_id, user=user, is_deleted=False)
        except Habit.DoesNotExist:
            raise ValueError('Habit not found or you are not the owner.')

        confirmed_friend_ids = set(SocialService.get_friend_ids(user))
        requested = set(int(fid) for fid in friend_ids)
        invalid = requested - confirmed_friend_ids
        if invalid:
            raise ValueError(f'Users {invalid} are not your confirmed friends.')

        # Bulk-create share records, skipping duplicates
        from django.contrib.auth import get_user_model
        User = get_user_model()
        created_count = 0
        for fid in requested:
            _, created = SharedHabit.objects.get_or_create(
                habit=habit,
                shared_by=user,
                shared_with_id=fid,
                defaults={
                    'can_comment': can_comment,
                    'can_react': can_react,
                },
            )
            if created:
                created_count += 1

        # Auto-upgrade visibility so friends can see it
        if habit.visibility == 'private':
            habit.visibility = 'friends_only'
            habit.save(update_fields=['visibility'])

        return {
            'sharedCount': created_count,
            'message': f'Shared with {created_count} friend(s).',
        }

    @staticmethod
    def unshare_habit(user, habit_id, friend_id):
        """
        Remove a specific sharing relationship for a habit.

        If no shares remain after deletion, the habit's visibility is
        reverted to ``private``.

        Raises:
            ValueError: If the share record doesn't exist or user
                doesn't own the habit.
        """
        deleted, _ = SharedHabit.objects.filter(
            habit_id=habit_id,
            shared_by=user,
            shared_with_id=friend_id,
        ).delete()

        if not deleted:
            raise ValueError('Share record not found.')

        # Revert visibility if no shares remain
        remaining = SharedHabit.objects.filter(
            habit_id=habit_id, shared_by=user,
        ).count()
        if remaining == 0:
            Habit.objects.filter(
                pk=habit_id, user=user,
            ).update(visibility='private')

    @staticmethod
    def get_shared_feed(user):
        """
        Build the "shared with me" feed for a user.

        Returns a list of dicts, each representing a shared habit with:
            - habit metadata (id, title, category, icon, color, streak)
            - sharer info (id, name)
            - aggregate reaction counts
            - recent comment count
            - sharing permissions
        """
        shares = SharedHabit.objects.filter(
            shared_with=user,
        ).select_related(
            'habit', 'habit__user', 'shared_by',
        ).order_by('-shared_at')

        results = []
        for share in shares:
            habit = share.habit
            if habit.is_deleted:
                continue

            # Streak info
            try:
                streak_val = habit.streak.current_streak
                best_val = habit.streak.best_streak
            except Exception:
                streak_val = 0
                best_val = 0

            # Reactions summary — group by type
            reactions = HabitReaction.objects.filter(
                habit=habit,
            ).values('reaction_type').annotate(
                count=Count('id'),
            )
            reaction_summary = {r['reaction_type']: r['count'] for r in reactions}

            # Comment count
            comment_count = HabitComment.objects.filter(habit=habit).count()

            results.append({
                'id': share.pk,
                'habitId': habit.id,
                'habitTitle': habit.title,
                'habitDescription': habit.description or '',
                'categoryName': habit.category_name or '',
                'iconCode': habit.icon_code,
                'colorValue': habit.color_value,
                'visibility': habit.visibility,
                'currentStreak': streak_val,
                'bestStreak': best_val,
                'sharedBy': {
                    'id': share.shared_by.id,
                    'name': getattr(share.shared_by, 'name', str(share.shared_by)),
                },
                'sharedAt': share.shared_at.isoformat(),
                'canComment': share.can_comment,
                'canReact': share.can_react,
                'reactions': reaction_summary,
                'commentCount': comment_count,
            })

        return results

    # ═══════════════════════════════════════════════════════════════════════
    #  GROUP CHALLENGES
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def create_group_challenge(user, group_id, title, description='',
                               target_type='completions', target_value=50,
                               start_date=None, end_date=None,
                               xp_reward=50, coin_reward=10):
        """Create a group challenge. Only group admins can create."""
        try:
            membership = GroupMember.objects.get(
                group_id=group_id, user=user, is_active=True
            )
        except GroupMember.DoesNotExist:
            raise ValueError('You are not a member of this group.')

        if membership.role != 'admin':
            raise ValueError('Only group admins can create challenges.')

        group = membership.group
        now = timezone.now()

        challenge = GroupChallenge.objects.create(
            group=group,
            created_by=user,
            title=title,
            description=description,
            target_type=target_type,
            target_value=target_value,
            start_date=start_date or now,
            end_date=end_date or (now + timedelta(days=7)),
            xp_reward=xp_reward,
            coin_reward=coin_reward,
        )

        # Notify all group members
        from notifications.services import NotificationCreator
        members = GroupMember.objects.filter(
            group=group, is_active=True,
        ).exclude(user=user).select_related('user')
        for m in members:
            NotificationCreator.group_challenge_created(
                to_user=m.user, creator=user,
                group=group, challenge=challenge,
            )

        return challenge

    @staticmethod
    def get_group_challenges(group_id, user=None):
        """Return all challenges for a group, with progress info."""
        challenges = GroupChallenge.objects.filter(
            group_id=group_id,
        ).order_by('-created_at')

        done_today = False
        if user is not None and getattr(user, 'is_authenticated', False):
            membership = GroupMember.objects.filter(
                group_id=group_id, user=user, is_active=True,
            ).select_related('habit').first()
            if membership and membership.habit:
                done_today = HabitLog.objects.filter(
                    habit=membership.habit,
                    date=timezone.now().date(),
                    status='completed',
                ).exists()

        results = []
        for ch in challenges:
            results.append({
                'id': ch.id,
                'title': ch.title,
                'description': ch.description,
                'targetType': ch.target_type,
                'targetValue': ch.target_value,
                'currentProgress': ch.current_progress,
                'progressPercentage': ch.progress_percentage,
                'status': ch.status,
                'startDate': ch.start_date.isoformat(),
                'endDate': ch.end_date.isoformat(),
                'xpReward': ch.xp_reward,
                'coinReward': ch.coin_reward,
                'iconCode': ch.icon_code,
                'colorValue': ch.color_value,
                'createdBy': ch.created_by.name,
                'isActive': ch.is_active,
                'doneToday': done_today,
                'canMarkToday': ch.is_active and ch.status == 'active' and not done_today,
                'createdAt': ch.created_at.isoformat(),
            })
        return results

    @staticmethod
    def mark_group_challenge_done_today(user, group_id, challenge_id):
        """Mark today's completion for the current user in a group challenge."""
        try:
            challenge = GroupChallenge.objects.select_related('group').get(
                pk=challenge_id, group_id=group_id,
            )
        except GroupChallenge.DoesNotExist:
            raise ValueError('Challenge not found in this group.')

        if challenge.status != 'active' or not challenge.is_active:
            raise ValueError('This challenge is not active today.')

        try:
            membership = GroupMember.objects.select_related('habit').get(
                group_id=group_id, user=user, is_active=True,
            )
        except GroupMember.DoesNotExist:
            raise ValueError('You are not a member of this group.')

        if not membership.habit:
            raise ValueError('No linked group habit found for your profile.')

        today = timezone.now().date()
        now = timezone.now()
        log = HabitLog.objects.filter(habit=membership.habit, date=today).first()
        if log and log.status == 'completed':
            SocialService.update_challenge_progress(group_id)
            challenge.refresh_from_db()
            rating_10 = round(challenge.progress_percentage / 10, 1)
            return {
                'alreadyDoneToday': True,
                'challengeId': challenge.id,
                'currentProgress': challenge.current_progress,
                'progressPercentage': challenge.progress_percentage,
                'rating10': rating_10,
            }

        if log:
            log.status = 'completed'
            log.completed_at = now
            if hasattr(log, 'count') and not log.count:
                log.count = 1
            log.save()
        else:
            HabitLog.objects.create(
                habit=membership.habit,
                date=today,
                status='completed',
                completed_at=now,
                count=1,
            )

        streak, _ = Streak.objects.get_or_create(habit=membership.habit)
        streak.update_streak(today)

        from gamification.services import GamificationEngine
        GamificationEngine.award_habit_completion_xp(user, membership.habit)

        SocialService.update_challenge_progress(group_id)
        challenge.refresh_from_db()
        rating_10 = round(challenge.progress_percentage / 10, 1)

        return {
            'markedDoneToday': True,
            'challengeId': challenge.id,
            'currentProgress': challenge.current_progress,
            'progressPercentage': challenge.progress_percentage,
            'rating10': rating_10,
        }

    @staticmethod
    def update_challenge_progress(group_id):
        """Recalculate progress for all active challenges in a group."""
        active_challenges = GroupChallenge.objects.filter(
            group_id=group_id, status='active',
        )
        members = GroupMember.objects.filter(
            group_id=group_id, is_active=True,
        ).select_related('habit')

        for challenge in active_challenges:
            # Check if expired
            if timezone.now() > challenge.end_date:
                challenge.status = 'expired'
                challenge.save(update_fields=['status'])
                continue

            progress = 0
            for member in members:
                if not member.habit:
                    continue
                if challenge.target_type == 'completions':
                    progress += HabitLog.objects.filter(
                        habit=member.habit,
                        status='completed',
                        date__gte=challenge.start_date.date(),
                        date__lte=timezone.now().date(),
                    ).count()
                elif challenge.target_type == 'streak':
                    try:
                        progress = max(progress, member.habit.streak.current_streak)
                    except Streak.DoesNotExist:
                        pass
                elif challenge.target_type == 'all_done':
                    start = challenge.start_date.date()
                    end = min(timezone.now().date(), challenge.end_date.date())
                    active_habits = [m.habit for m in members if m.habit]
                    if active_habits:
                        check_date = start
                        while check_date <= end:
                            completed = HabitLog.objects.filter(
                                habit__in=active_habits,
                                date=check_date,
                                status='completed',
                            ).values('habit_id').distinct().count()
                            if completed >= len(active_habits):
                                progress += 1
                            check_date += timedelta(days=1)

            challenge.current_progress = progress
            if progress >= challenge.target_value:
                challenge.status = 'completed'
                # Notify all members of completion
                from notifications.services import NotificationCreator
                group = challenge.group
                for member in members:
                    NotificationCreator.group_challenge_completed(
                        to_user=member.user, group=group, challenge=challenge,
                    )
            challenge.save(update_fields=['current_progress', 'status'])

    # ═══════════════════════════════════════════════════════════════════════
    #  ENCOURAGEMENT
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def send_encouragement(from_user, to_user_id, encourage_type='cheer',
                           message='', habit_id=None):
        """Send an encouragement nudge to a friend."""
        # Validate friendship
        confirmed = set(SocialService.get_friend_ids(from_user))
        if int(to_user_id) not in confirmed:
            raise ValueError('You can only encourage confirmed friends.')

        from django.contrib.auth import get_user_model
        User = get_user_model()
        to_user = User.objects.get(pk=to_user_id)

        habit = None
        if habit_id:
            habit = Habit.objects.filter(pk=habit_id, is_deleted=False).first()

        enc = Encouragement.objects.create(
            from_user=from_user,
            to_user=to_user,
            habit=habit,
            encourage_type=encourage_type,
            message=message,
        )

        # Send notification
        from notifications.services import NotificationCreator
        NotificationCreator.encouragement_received(
            to_user=to_user,
            from_user=from_user,
            encourage_type=encourage_type,
            message_text=message,
            habit=habit,
        )

        return enc

    # ═══════════════════════════════════════════════════════════════════════
    #  SHARE HABIT TO GROUP
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def share_habit_to_group(user, habit_id, group_id):
        """Post a habit to a group for all members to see and optionally clone."""
        try:
            habit = Habit.objects.get(pk=habit_id, user=user, is_deleted=False)
        except Habit.DoesNotExist:
            raise ValueError('Habit not found or you are not the owner.')

        try:
            membership = GroupMember.objects.get(
                group_id=group_id, user=user, is_active=True,
            )
        except GroupMember.DoesNotExist:
            raise ValueError('You are not a member of this group.')

        group = membership.group

        # Prevent re-sharing the same habit in the same group by the same user.
        existing = FeedPost.objects.filter(
            author=user,
            post_type='group_update',
            habit=habit,
            group=group,
        ).exists()
        if existing:
            raise ValueError('This habit has already been shared in this group.')

        # Create a feed post about the shared habit
        post = FeedPost.objects.create(
            author=user,
            post_type='group_update',
            content=f'Shared habit "{habit.title}" with the group!',
            habit=habit,
            group=group,
            is_public=False,
        )

        # Auto-upgrade visibility
        if habit.visibility == 'private':
            habit.visibility = 'friends_only'
            habit.save(update_fields=['visibility'])

        return {
            'postId': post.pk,
            'message': f'Habit shared with {group.name}.',
            'shareRating10': 10.0,
            'shareQuality': 'Excellent',
        }

    # ═══════════════════════════════════════════════════════════════════════
    #  ACTIVITY FEED — Friend + Group activity stream
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def get_activity_feed(user, limit=30):
        """Build a unified activity feed combining friend & group events.

        Includes: shared habit completions, encouragements received,
        group challenge updates, and reactions on the user's habits.
        """
        from .models import FeedPost

        friend_ids = SocialService.get_friend_ids(user)
        group_ids = list(GroupMember.objects.filter(
            user=user, is_active=True,
        ).values_list('group_id', flat=True))

        items = []

        # 1. Recent encouragements received
        recent_enc = Encouragement.objects.filter(
            to_user=user,
        ).select_related('from_user', 'habit').order_by('-created_at')[:10]
        for e in recent_enc:
            items.append({
                'type': 'encouragement',
                'fromUser': {'id': e.from_user.id, 'name': e.from_user.name},
                'encourageType': e.encourage_type,
                'message': e.message,
                'habitTitle': e.habit.title if e.habit else None,
                'createdAt': e.created_at.isoformat(),
            })

        # 2. Recent reactions on user's habits
        recent_reactions = HabitReaction.objects.filter(
            habit__user=user,
        ).select_related('user', 'habit').order_by('-created_at')[:10]
        for r in recent_reactions:
            items.append({
                'type': 'reaction',
                'fromUser': {'id': r.user.id, 'name': r.user.name},
                'reactionType': r.reaction_type,
                'habitTitle': r.habit.title,
                'createdAt': r.created_at.isoformat(),
            })

        # 3. Recent comments on user's habits
        recent_comments = HabitComment.objects.filter(
            habit__user=user,
        ).exclude(
            author=user,
        ).select_related('author', 'habit').order_by('-created_at')[:10]
        for c in recent_comments:
            items.append({
                'type': 'comment',
                'fromUser': {'id': c.author.id, 'name': c.author.name},
                'content': c.content[:100],
                'habitTitle': c.habit.title,
                'createdAt': c.created_at.isoformat(),
            })

        # 4. Group challenge updates
        active_challenges = GroupChallenge.objects.filter(
            group_id__in=group_ids,
        ).select_related('group', 'created_by').order_by('-created_at')[:5]
        for ch in active_challenges:
            items.append({
                'type': 'group_challenge',
                'groupName': ch.group.name,
                'challengeTitle': ch.title,
                'progress': ch.progress_percentage,
                'status': ch.status,
                'createdAt': ch.created_at.isoformat(),
            })

        # Sort by createdAt descending
        items.sort(key=lambda x: x['createdAt'], reverse=True)
        return items[:limit]

    # ═══════════════════════════════════════════════════════════════════════
    #  GROUP DETAIL WITH STATS
    # ═══════════════════════════════════════════════════════════════════════

    @staticmethod
    def get_group_detail(group_id, user):
        """Return detailed group info including challenges, leaderboard, and stats."""
        try:
            group = GroupHabit.objects.select_related('creator').get(pk=group_id)
        except GroupHabit.DoesNotExist:
            raise ValueError('Group not found.')

        # Check membership
        try:
            membership = GroupMember.objects.get(
                group=group, user=user, is_active=True,
            )
        except GroupMember.DoesNotExist:
            raise PermissionError('You are not a member of this group.')

        members = GroupMember.objects.filter(
            group=group, is_active=True,
        ).select_related('user', 'habit')

        # Leaderboard
        leaderboard = SocialService.get_group_leaderboard(group_id)

        # Active challenges
        challenges = SocialService.get_group_challenges(group_id, user)

        # Challenge achievement tracking (10-point scale)
        group_challenge_total = len(challenges)
        group_challenge_completed = sum(
            1 for c in challenges if c.get('status') == 'completed'
        )
        group_challenge_rating_10 = (
            round(group_challenge_completed / group_challenge_total * 10, 1)
            if group_challenge_total else 0.0
        )

        individual_participation_qs = ChallengeParticipant.objects.filter(
            user=user,
            challenge__scope='personal',
        )
        individual_challenge_total = individual_participation_qs.count()
        individual_challenge_completed = individual_participation_qs.filter(
            status='completed',
        ).count()
        individual_challenge_rating_10 = (
            round(individual_challenge_completed / individual_challenge_total * 10, 1)
            if individual_challenge_total else 0.0
        )

        # Shared achievements in this group (newest first)
        shared_achievements = list(
            FeedPost.objects.filter(
                group=group,
                post_type='achievement',
            ).select_related('author').order_by('-created_at')[:20]
        )

        # Shared habit posts (group updates) with recent comments.
        shared_group_habits = list(
            FeedPost.objects.filter(
                group=group,
                post_type='group_update',
            ).select_related('author', 'habit').prefetch_related(
                'comments__author',
            ).order_by('-created_at')[:20]
        )

        # Aggregate stats
        total_completions = 0
        total_streaks = 0
        for m in members:
            if m.habit:
                total_completions += HabitLog.objects.filter(
                    habit=m.habit, status='completed',
                ).count()
                try:
                    total_streaks += m.habit.streak.current_streak
                except Streak.DoesNotExist:
                    pass

        return {
            'id': group.id,
            'name': group.name,
            'description': group.description,
            'inviteCode': group.invite_code,
            'memberCount': group.member_count,
            'maxMembers': group.max_members,
            'isActive': group.is_active,
            'creatorName': group.creator.name,
            'myRole': membership.role if membership else None,
            'iconCode': group.icon_code,
            'colorValue': group.color_value,
            'totalCompletions': total_completions,
            'totalStreaks': total_streaks,
            'groupChallengeRating10': group_challenge_rating_10,
            'groupChallengesCompleted': group_challenge_completed,
            'groupChallengesTotal': group_challenge_total,
            'individualChallengeRating10': individual_challenge_rating_10,
            'individualChallengesCompleted': individual_challenge_completed,
            'individualChallengesTotal': individual_challenge_total,
            'leaderboard': leaderboard,
            'challenges': challenges,
            'sharedAchievements': [{
                'id': p.id,
                'authorName': p.author.name,
                'content': p.content,
                'emoji': p.emoji,
                'createdAt': p.created_at.isoformat(),
                'likeCount': p.like_count,
                'commentCount': p.comment_count,
            } for p in shared_achievements],
            'sharedGroupHabits': [{
                'id': p.id,
                'authorName': p.author.name,
                'habitTitle': p.habit.title if p.habit else 'Habit',
                'content': p.content,
                'createdAt': p.created_at.isoformat(),
                'commentCount': p.comment_count,
                'recentComments': [{
                    'id': c.pk,
                    'authorName': c.author.name,
                    'content': c.content,
                    'createdAt': c.created_at.isoformat(),
                } for c in PostComment.objects.filter(post=p).select_related('author').order_by('-created_at')[:3]],
            } for p in shared_group_habits],
            'members': [{
                'id': m.user.id,
                'name': m.user.name,
                'role': m.role,
                'currentStreak': m.user.current_streak,
                'joinedAt': m.joined_at.isoformat(),
            } for m in members],
        }
