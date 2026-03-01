"""
Grow Together — Service Layer
==============================

Business logic for the collaborative habit sharing system.
Encapsulates all domain operations:
    - Creating and managing collaborative habits
    - Invitation workflow
    - Progress tracking with streak management
    - Gamification (XP, milestones, leaderboard)
    - Activity feed generation
    - Analytics computations
    - Abuse reporting

All methods are ``@staticmethod`` or ``@classmethod`` to avoid
instantiation overhead and keep the service stateless.
"""

from __future__ import annotations

import logging
from datetime import timedelta, date
from typing import Optional

from django.conf import settings
from django.db import transaction
from django.db.models import Q, Count, Sum, F, Avg, Case, When, Value, IntegerField
from django.utils import timezone

from .models import (
    CollaborativeHabit,
    CollaborativeHabitMember,
    CollaborativeHabitProgress,
    HabitInvite,
    HabitActivityLog,
    ProgressReaction,
    ProgressComment,
    WeeklyLeaderboard,
    GroupMilestone,
    AbuseReport,
    StreakFreeze,
)

logger = logging.getLogger(__name__)


class GrowTogetherService:
    """
    Core service for all Grow Together operations.

    Design principles:
        - All DB writes happen inside ``transaction.atomic()`` blocks.
        - Denormalized counters are updated atomically.
        - N+1 queries are avoided via ``select_related`` / ``prefetch_related``.
        - All user-facing errors raise ``ValueError`` with descriptive messages.
    """

    # ═══════════════════════════════════════════════════════════════════
    #  COLLABORATIVE HABIT CRUD
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def create_collaborative_habit(user, data: dict) -> CollaborativeHabit:
        """
        Create a new collaborative habit and add the owner as the first member.

        Optionally sends invitations to ``data['friendIds']`` if provided.
        If ``data['sourceHabitId']`` is provided, copies config from
        the user's existing personal habit.
        """
        from habits.models import Habit

        # If creating from existing habit, copy its config
        source_habit = None
        source_habit_id = data.get('sourceHabitId')
        if source_habit_id:
            try:
                source_habit = Habit.objects.get(id=source_habit_id, user=user)
            except Habit.DoesNotExist:
                raise ValueError('Source habit not found or not owned by you.')

        habit = CollaborativeHabit.objects.create(
            title=data.get('title', source_habit.title if source_habit else ''),
            description=data.get('description', source_habit.description if source_habit else ''),
            emoji=data.get('emoji', '🎯'),
            owner=user,
            source_habit=source_habit,
            group_id=data.get('groupId'),
            frequency=data.get('frequency', source_habit.frequency if source_habit else 'daily'),
            custom_days=data.get('customDays', source_habit.custom_days if source_habit else []),
            target_count=data.get('targetCount', 1),
            privacy=data.get('privacy', 'friends_only'),
            max_members=data.get('maxMembers', 50),
            icon_code=data.get('iconCode', source_habit.icon_code if source_habit else 0xE87C),
            color_value=data.get('colorValue', source_habit.color_value if source_habit else 0xFF4F46E5),
        )

        # Add owner as first member
        CollaborativeHabitMember.objects.create(
            collaborative_habit=habit,
            user=user,
            linked_habit=source_habit,
            role='owner',
        )

        # Seed default milestones
        GrowTogetherService._seed_milestones(habit)

        # Log creation
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='created',
            description=f'{user.name} created "{habit.title}"',
        )

        # Auto-invite friends if provided
        friend_ids = data.get('friendIds', [])
        if friend_ids:
            GrowTogetherService.send_invites(
                user=user,
                collaborative_habit_id=str(habit.id),
                friend_ids=friend_ids,
                message=f"Join me in tracking '{habit.title}' together!",
            )

        return habit

    @staticmethod
    def get_user_collaborative_habits(user):
        """
        Return all collaborative habits the user is a member of.

        Uses ``select_related`` and ``prefetch_related`` to avoid N+1 queries.
        """
        habit_ids = CollaborativeHabitMember.objects.filter(
            user=user, is_active=True,
        ).values_list('collaborative_habit_id', flat=True)

        return CollaborativeHabit.objects.filter(
            id__in=habit_ids, is_active=True,
        ).select_related('owner').prefetch_related(
            'members__user', 'progress_records',
        ).order_by('-updated_at')

    @staticmethod
    def get_discoverable_habits(user, limit=20):
        """
        Return public collaborative habits the user can join.

        Excludes habits the user is already a member of.
        """
        my_habit_ids = CollaborativeHabitMember.objects.filter(
            user=user,
        ).values_list('collaborative_habit_id', flat=True)

        return CollaborativeHabit.objects.filter(
            privacy='public',
            is_active=True,
            status='active',
        ).exclude(
            id__in=my_habit_ids,
        ).select_related('owner').order_by('-member_count', '-created_at')[:limit]

    # ═══════════════════════════════════════════════════════════════════
    #  INVITATION WORKFLOW
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def send_invites(user, collaborative_habit_id: str, friend_ids: list[int],
                     message: str = '') -> list[HabitInvite]:
        """
        Send invitations to multiple friends for a collaborative habit.

        Validates:
            - User is owner or admin of the habit.
            - Friends are actual accepted friends.
            - Not already members.
            - Not already invited (pending).
            - Habit hasn't reached max capacity.
        """
        from social.models import Friendship

        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        # Permission check
        try:
            membership = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
            if membership.role not in ('owner', 'admin'):
                raise ValueError('Only owners and admins can send invitations.')
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        # Capacity check
        current = habit.members.filter(is_active=True).count()
        if current + len(friend_ids) > habit.max_members:
            raise ValueError(
                f'Cannot invite {len(friend_ids)} people. '
                f'Group capacity is {habit.max_members}, currently {current} members.'
            )

        # Validate friendships
        friend_q = Q(
            from_user=user, to_user_id__in=friend_ids, status='accepted'
        ) | Q(
            to_user=user, from_user_id__in=friend_ids, status='accepted'
        )
        valid_friend_ids = set()
        for f in Friendship.objects.filter(friend_q):
            other = f.to_user_id if f.from_user_id == user.id else f.from_user_id
            valid_friend_ids.add(other)

        # For public habits, allow inviting non-friends too
        if habit.privacy == 'public':
            valid_friend_ids = set(friend_ids)

        if not valid_friend_ids:
            raise ValueError('None of the specified users are your friends.')

        # Exclude existing members
        existing_member_ids = set(
            habit.members.filter(
                user_id__in=valid_friend_ids,
            ).values_list('user_id', flat=True)
        )
        valid_friend_ids -= existing_member_ids

        # Exclude already pending invites
        existing_invite_ids = set(
            HabitInvite.objects.filter(
                collaborative_habit=habit,
                invited_user_id__in=valid_friend_ids,
                status='pending',
            ).values_list('invited_user_id', flat=True)
        )
        valid_friend_ids -= existing_invite_ids

        if not valid_friend_ids:
            raise ValueError('All selected users are already members or have pending invites.')

        # Create invites
        invites = []
        expires = timezone.now() + timedelta(days=7)
        for fid in valid_friend_ids:
            invite = HabitInvite.objects.create(
                collaborative_habit=habit,
                invited_by=user,
                invited_user_id=fid,
                message=message,
                expires_at=expires,
            )
            invites.append(invite)

            # Activity log
            HabitActivityLog.objects.create(
                collaborative_habit=habit,
                actor=user,
                target_user_id=fid,
                action='invited',
                description=f'{user.name} invited a friend to join',
            )

        # Send notifications
        GrowTogetherService._send_invite_notifications(habit, user, valid_friend_ids)

        return invites

    @staticmethod
    @transaction.atomic
    def accept_invite(user, invite_id: str) -> CollaborativeHabitMember:
        """
        Accept a pending invitation and join the collaborative habit.

        Creates a new ``CollaborativeHabitMember`` and updates the
        denormalized ``member_count`` on the habit.
        """
        try:
            invite = HabitInvite.objects.select_related(
                'collaborative_habit',
            ).get(
                id=invite_id, invited_user=user, status='pending',
            )
        except HabitInvite.DoesNotExist:
            raise ValueError('Invitation not found or already responded.')

        if invite.is_expired:
            invite.status = 'expired'
            invite.save(update_fields=['status'])
            raise ValueError('This invitation has expired.')

        habit = invite.collaborative_habit
        if not habit.is_active:
            raise ValueError('This collaborative habit is no longer active.')

        # Capacity check
        current = habit.members.filter(is_active=True).count()
        if current >= habit.max_members:
            raise ValueError('This collaborative habit is full.')

        # Create membership
        member, created = CollaborativeHabitMember.objects.get_or_create(
            collaborative_habit=habit,
            user=user,
            defaults={'role': 'member', 'is_active': True},
        )
        if not created:
            if member.is_active:
                raise ValueError('You are already a member of this habit.')
            member.is_active = True
            member.save(update_fields=['is_active'])

        # Update invite
        invite.status = 'accepted'
        invite.responded_at = timezone.now()
        invite.save(update_fields=['status', 'responded_at'])

        # Update denormalized counter
        habit.member_count = habit.members.filter(is_active=True).count()
        habit.save(update_fields=['member_count'])

        # Activity log
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='joined',
            description=f'{user.name} joined "{habit.title}"',
        )

        # Notification to owner
        GrowTogetherService._send_member_joined_notification(habit, user)

        return member

    @staticmethod
    @transaction.atomic
    def decline_invite(user, invite_id: str):
        """Decline a pending invitation."""
        try:
            invite = HabitInvite.objects.get(
                id=invite_id, invited_user=user, status='pending',
            )
        except HabitInvite.DoesNotExist:
            raise ValueError('Invitation not found or already responded.')

        invite.status = 'declined'
        invite.responded_at = timezone.now()
        invite.save(update_fields=['status', 'responded_at'])

    @staticmethod
    def get_pending_invites(user):
        """Return all pending invitations for the user."""
        return HabitInvite.objects.filter(
            invited_user=user, status='pending',
        ).select_related(
            'collaborative_habit__owner', 'invited_by',
        ).order_by('-created_at')

    # ═══════════════════════════════════════════════════════════════════
    #  PROGRESS TRACKING
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def log_progress(user, collaborative_habit_id: str,
                     note: str = '', completion_count: int = 1,
                     client_timezone: str = '') -> dict:
        """
        Log daily progress for a member in a collaborative habit.

        Returns a rich result dict with:
            - progress: the progress record
            - streak: { current, best, increased }
            - xpBreakdown: { base, multiplier, earned, streakBonus }
            - groupStatus: { completedMembers, totalMembers, percentage, allComplete }
            - milestonesUnlocked: list of newly achieved milestones
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        today = timezone.now().date()

        # Create or update progress
        progress, created = CollaborativeHabitProgress.objects.get_or_create(
            member=member,
            date=today,
            defaults={
                'collaborative_habit': habit,
                'user': user,
                'completed': True,
                'completion_count': completion_count,
                'note': note,
                'completed_at': timezone.now(),
            },
        )

        if not created:
            if progress.completed:
                # Already completed, update count if multi-count
                progress.completion_count = min(
                    progress.completion_count + completion_count,
                    habit.target_count,
                )
                progress.note = note or progress.note
                progress.save(update_fields=['completion_count', 'note', 'updated_at'])

                # Return current state even for duplicate
                active_count = habit.members.filter(is_active=True).count()
                completed_count = habit.progress_records.filter(
                    date=today, completed=True,
                ).values('user').distinct().count()

                return {
                    'progress': progress,
                    'streak': {
                        'current': member.current_streak,
                        'best': member.best_streak,
                        'increased': False,
                    },
                    'xpBreakdown': {
                        'base': 0,
                        'multiplier': 1.0,
                        'earned': 0,
                        'streakBonus': False,
                    },
                    'groupStatus': {
                        'completedMembers': completed_count,
                        'totalMembers': active_count,
                        'percentage': round(completed_count / active_count * 100, 1) if active_count else 0,
                        'allComplete': completed_count >= active_count and active_count > 1,
                    },
                    'milestonesUnlocked': [],
                }
            else:
                progress.completed = True
                progress.completion_count = completion_count
                progress.note = note
                progress.completed_at = timezone.now()
                progress.save(update_fields=[
                    'completed', 'completion_count', 'note',
                    'completed_at', 'updated_at',
                ])

        # ── Streak management ────────────────────────────────────────
        old_streak = member.current_streak
        yesterday = today - timedelta(days=1)
        if member.last_completed_date == yesterday:
            member.current_streak += 1
        elif member.last_completed_date != today:
            member.current_streak = 1

        member.best_streak = max(member.best_streak, member.current_streak)
        member.total_completions += 1
        member.last_completed_date = today

        # ── XP calculation ───────────────────────────────────────────
        base_xp = habit.xp_per_completion
        # Streak multiplier: +10% per streak day, capped at 2.5x
        streak_multiplier = min(2.5, 1.0 + (member.current_streak - 1) * 0.1)
        xp = int(base_xp * streak_multiplier)
        progress.xp_earned = xp
        progress.save(update_fields=['xp_earned'])

        member.total_xp_earned += xp
        member.save(update_fields=[
            'current_streak', 'best_streak', 'total_completions',
            'total_xp_earned', 'last_completed_date', 'updated_at',
        ])

        # ── Update habit counters ────────────────────────────────────
        CollaborativeHabit.objects.filter(id=habit.id).update(
            total_completions=F('total_completions') + 1,
        )

        # ── Award XP in gamification system ──────────────────────────
        GrowTogetherService._award_xp(user, xp, habit.title)

        # ── Activity log ─────────────────────────────────────────────
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='completed',
            description=f'{user.name} completed "{habit.title}"',
            metadata={'streak': member.current_streak, 'xp': xp},
        )

        # ── Check all-members-complete bonus ─────────────────────────
        GrowTogetherService._check_all_complete_bonus(habit, today)

        # ── Milestone evaluation ─────────────────────────────────────
        newly_achieved = GrowTogetherService._evaluate_milestones(habit, member, user)

        # ── Streak milestone notifications ───────────────────────────
        if member.current_streak in (7, 14, 21, 30, 60, 90, 100, 365):
            HabitActivityLog.objects.create(
                collaborative_habit=habit,
                actor=user,
                action='streak_milestone',
                description=f'{user.name} reached a {member.current_streak}-day streak! 🔥',
                metadata={'streak': member.current_streak},
            )
            GrowTogetherService._send_streak_notification(habit, user, member.current_streak)

        # ── Build group status ───────────────────────────────────────
        active_count = habit.members.filter(is_active=True).count()
        completed_count = habit.progress_records.filter(
            date=today, completed=True,
        ).values('user').distinct().count()

        return {
            'progress': progress,
            'streak': {
                'current': member.current_streak,
                'best': member.best_streak,
                'increased': member.current_streak > old_streak,
            },
            'xpBreakdown': {
                'base': base_xp,
                'multiplier': round(streak_multiplier, 2),
                'earned': xp,
                'streakBonus': streak_multiplier > 1.0,
            },
            'groupStatus': {
                'completedMembers': completed_count,
                'totalMembers': active_count,
                'percentage': round(completed_count / active_count * 100, 1) if active_count else 0,
                'allComplete': completed_count >= active_count and active_count > 1,
            },
            'milestonesUnlocked': newly_achieved or [],
        }

    @staticmethod
    def get_daily_progress(collaborative_habit_id: str, target_date: Optional[date] = None):
        """Return all member progress records for a given date."""
        if target_date is None:
            target_date = timezone.now().date()

        return CollaborativeHabitProgress.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
            date=target_date,
        ).select_related('user').prefetch_related(
            'reactions', 'comments__author',
        ).order_by('-completed', '-completed_at')

    @staticmethod
    def get_today_status(user, collaborative_habit_id: str) -> dict:
        """
        Return the requesting user's completion status for today.

        Returns:
            - completed (bool)
            - completedAt (datetime or None)
            - completionCount (int)
            - note (str)
            - xpEarned (int)
            - currentStreak (int)
            - bestStreak (int)
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        today = timezone.now().date()
        progress = CollaborativeHabitProgress.objects.filter(
            member=member, date=today,
        ).first()

        return {
            'completed': progress.completed if progress else False,
            'completedAt': progress.completed_at if progress else None,
            'completionCount': progress.completion_count if progress else 0,
            'note': progress.note if progress else '',
            'xpEarned': progress.xp_earned if progress else 0,
            'currentStreak': member.current_streak,
            'bestStreak': member.best_streak,
        }

    @staticmethod
    def get_group_progress(collaborative_habit_id: str,
                           target_date: Optional[date] = None) -> dict:
        """
        Return group-level progress for a given date including
        per-member completion statuses.

        Returns:
            - date (str)
            - completedMembers (int)
            - totalMembers (int)
            - percentage (float)
            - allComplete (bool)
            - memberStatuses (list of { userId, userName, completed, completedAt })
        """
        if target_date is None:
            target_date = timezone.now().date()

        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        active_members = habit.members.filter(
            is_active=True,
        ).select_related('user')
        active_count = active_members.count()

        # Get progress records for the date
        progress_map = {
            p.user_id: p  # type: ignore  # Django FK auto-generated field
            for p in habit.progress_records.filter(
                date=target_date, completed=True,
            )
        }

        member_statuses = []
        for m in active_members:
            p = progress_map.get(m.user_id)  # type: ignore
            member_statuses.append({
                'userId': m.user_id,
                'userName': m.user.name,
                'completed': p is not None,
                'completedAt': p.completed_at.isoformat() if p and p.completed_at else None,
                'currentStreak': m.current_streak,
            })

        completed_count = len(progress_map)
        percentage = round(completed_count / active_count * 100, 1) if active_count else 0

        return {
            'date': target_date.isoformat(),
            'completedMembers': completed_count,
            'totalMembers': active_count,
            'percentage': percentage,
            'allComplete': completed_count >= active_count and active_count > 1,
            'memberStatuses': member_statuses,
        }

    # ═══════════════════════════════════════════════════════════════════
    #  MEMBER MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_members(collaborative_habit_id: str):
        """Return all active members of a collaborative habit."""
        return CollaborativeHabitMember.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
            is_active=True,
        ).select_related('user').prefetch_related(
            'progress_records',
        ).order_by('-current_streak', '-total_completions')

    @staticmethod
    @transaction.atomic
    def remove_member(user, collaborative_habit_id: str, target_user_id: int):
        """
        Remove a member from a collaborative habit.

        Only owners and admins can remove members.
        Owners cannot be removed.
        """
        try:
            habit = CollaborativeHabit.objects.get(id=collaborative_habit_id)
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        # Check authority
        try:
            actor_membership = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        if actor_membership.role not in ('owner', 'admin'):
            raise ValueError('Only owners and admins can remove members.')

        try:
            target_membership = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user_id=target_user_id, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('Target user is not a member.')

        if target_membership.role == 'owner':
            raise ValueError('The habit owner cannot be removed.')

        # Soft removal
        target_membership.is_active = False
        target_membership.save(update_fields=['is_active', 'updated_at'])

        # Update counter
        habit.member_count = habit.members.filter(is_active=True).count()
        habit.save(update_fields=['member_count'])

        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            target_user_id=target_user_id,
            action='removed',
            description=f'A member was removed from "{habit.title}"',
        )

    @staticmethod
    @transaction.atomic
    def leave_habit(user, collaborative_habit_id: str):
        """
        Leave a collaborative habit voluntarily.

        Owners cannot leave — they must transfer ownership or archive the habit.
        """
        try:
            member = CollaborativeHabitMember.objects.select_related(
                'collaborative_habit',
            ).get(
                collaborative_habit_id=collaborative_habit_id,
                user=user,
                is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        if member.role == 'owner':
            raise ValueError(
                'Owners cannot leave. Transfer ownership or archive the habit.'
            )

        member.is_active = False
        member.save(update_fields=['is_active', 'updated_at'])

        habit = member.collaborative_habit
        habit.member_count = habit.members.filter(is_active=True).count()
        habit.save(update_fields=['member_count'])

        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='left',
            description=f'{user.name} left "{habit.title}"',
        )

    @staticmethod
    @transaction.atomic
    def join_public_habit(user, collaborative_habit_id: str) -> CollaborativeHabitMember:
        """Join a public collaborative habit directly (no invite needed)."""
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        if habit.privacy != 'public':
            raise ValueError('This habit is not public. You need an invitation.')

        current = habit.members.filter(is_active=True).count()
        if current >= habit.max_members:
            raise ValueError('This collaborative habit is full.')

        member, created = CollaborativeHabitMember.objects.get_or_create(
            collaborative_habit=habit,
            user=user,
            defaults={'role': 'member', 'is_active': True},
        )

        if not created:
            if member.is_active:
                raise ValueError('You are already a member of this habit.')
            member.is_active = True
            member.save(update_fields=['is_active'])

        habit.member_count = habit.members.filter(is_active=True).count()
        habit.save(update_fields=['member_count'])

        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='joined',
            description=f'{user.name} joined "{habit.title}"',
        )

        return member

    # ═══════════════════════════════════════════════════════════════════
    #  REACTIONS & COMMENTS
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def toggle_reaction(user, progress_id: str, reaction_type: str) -> dict:
        """Toggle a reaction on a progress entry. Returns action taken."""
        try:
            progress = CollaborativeHabitProgress.objects.select_related(
                'collaborative_habit',
            ).get(id=progress_id)
        except CollaborativeHabitProgress.DoesNotExist:
            raise ValueError('Progress entry not found.')

        # Verify membership
        if not CollaborativeHabitMember.objects.filter(
            collaborative_habit=progress.collaborative_habit,
            user=user,
            is_active=True,
        ).exists():
            raise ValueError('You must be a member to react.')

        existing = ProgressReaction.objects.filter(
            progress=progress, user=user, reaction_type=reaction_type,
        )
        if existing.exists():
            existing.delete()
            return {'action': 'removed', 'reactionType': reaction_type}
        else:
            ProgressReaction.objects.create(
                progress=progress, user=user, reaction_type=reaction_type,
            )
            # Log reaction
            HabitActivityLog.objects.create(
                collaborative_habit=progress.collaborative_habit,
                actor=user,
                target_user=progress.user,
                action='reacted',
                description=f'{user.name} reacted {reaction_type}',
                metadata={'reactionType': reaction_type},
            )
            return {'action': 'added', 'reactionType': reaction_type}

    @staticmethod
    @transaction.atomic
    def add_comment(user, progress_id: str, content: str) -> ProgressComment:
        """Add a comment to a progress entry."""
        try:
            progress = CollaborativeHabitProgress.objects.select_related(
                'collaborative_habit',
            ).get(id=progress_id)
        except CollaborativeHabitProgress.DoesNotExist:
            raise ValueError('Progress entry not found.')

        # Verify membership
        if not CollaborativeHabitMember.objects.filter(
            collaborative_habit=progress.collaborative_habit,
            user=user,
            is_active=True,
        ).exists():
            raise ValueError('You must be a member to comment.')

        comment = ProgressComment.objects.create(
            progress=progress, author=user, content=content,
        )

        HabitActivityLog.objects.create(
            collaborative_habit=progress.collaborative_habit,
            actor=user,
            target_user=progress.user,
            action='commented',
            description=f'{user.name} commented on progress',
        )

        return comment

    @staticmethod
    def get_progress_comments(progress_id: str):
        """Return all comments for a progress entry."""
        return ProgressComment.objects.filter(
            progress_id=progress_id,
        ).select_related('author').order_by('created_at')

    # ═══════════════════════════════════════════════════════════════════
    #  ACTIVITY FEED
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_activity_feed(collaborative_habit_id: str, limit: int = 50,
                          page: int = 1) -> list:
        """Return paginated activity feed for a collaborative habit."""
        offset = (page - 1) * limit
        return list(HabitActivityLog.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
        ).select_related('actor', 'target_user').order_by(
            '-created_at',
        )[offset:offset + limit])

    @staticmethod
    def get_global_feed(user, limit: int = 30, page: int = 1) -> list:
        """
        Return a combined activity feed across all of the user's
        collaborative habits, ordered by recency.
        """
        habit_ids = CollaborativeHabitMember.objects.filter(
            user=user, is_active=True,
        ).values_list('collaborative_habit_id', flat=True)

        offset = (page - 1) * limit
        return list(HabitActivityLog.objects.filter(
            collaborative_habit_id__in=habit_ids,
        ).select_related(
            'actor', 'target_user', 'collaborative_habit',
        ).order_by('-created_at')[offset:offset + limit])

    # ═══════════════════════════════════════════════════════════════════
    #  LEADERBOARD
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_weekly_leaderboard(collaborative_habit_id: str,
                               week_start: Optional[date] = None) -> list:
        """
        Get the weekly leaderboard for a collaborative habit.

        If no cached leaderboard exists for this week, builds one on-demand.
        """
        if week_start is None:
            today = timezone.now().date()
            week_start = today - timedelta(days=today.weekday())

        week_end = week_start + timedelta(days=6)

        cached = WeeklyLeaderboard.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
            week_start=week_start,
        ).select_related('user').order_by('rank')

        if cached.exists():
            return list(cached)

        # Build on-demand
        return GrowTogetherService._build_weekly_leaderboard(
            collaborative_habit_id, week_start, week_end,
        )

    @staticmethod
    @transaction.atomic
    def _build_weekly_leaderboard(collaborative_habit_id: str,
                                   week_start: date,
                                   week_end: date) -> list:
        """Build and cache weekly leaderboard from progress data."""
        # Delete any stale entries for this week
        WeeklyLeaderboard.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
            week_start=week_start,
        ).delete()

        # Aggregate completions per member for the week
        stats = CollaborativeHabitProgress.objects.filter(
            collaborative_habit_id=collaborative_habit_id,
            date__gte=week_start,
            date__lte=week_end,
            completed=True,
        ).values('user_id').annotate(
            completions=Count('id'),
            xp=Sum('xp_earned'),
        ).order_by('-completions', '-xp')

        # Get streak info from member records
        members = {
            m.user_id: m
            for m in CollaborativeHabitMember.objects.filter(
                collaborative_habit_id=collaborative_habit_id,
                is_active=True,
            )
        }

        entries = []
        for rank, row in enumerate(stats, start=1):
            member = members.get(row['user_id'])
            entry = WeeklyLeaderboard.objects.create(
                collaborative_habit_id=collaborative_habit_id,
                user_id=row['user_id'],
                week_start=week_start,
                week_end=week_end,
                rank=rank,
                completions=row['completions'],
                streak_days=member.current_streak if member else 0,
                xp_earned=row['xp'] or 0,
            )
            entries.append(entry)

        return entries

    # ═══════════════════════════════════════════════════════════════════
    #  MILESTONES
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def _seed_milestones(habit: CollaborativeHabit):
        """
        Create default milestones for a newly created collaborative habit.
        """
        milestone_defs = [
            ('group_streak_7', '7-Day Group Streak',
             'All active members complete the habit for 7 consecutive days.', 75, '🔥'),
            ('group_streak_30', '30-Day Group Streak',
             'All active members complete the habit for 30 consecutive days.', 250, '🏆'),
            ('all_complete_day', '100% Team Day',
             'Every member completes the habit on the same day.', 50, '⭐'),
            ('total_completions_100', '100 Completions',
             'The group reaches a combined 100 completions.', 100, '💯'),
            ('total_completions_500', '500 Completions',
             'The group reaches a combined 500 completions.', 300, '🎖️'),
            ('consistency_30', '30-Day Consistency',
             'The group maintains at least 80% daily completion rate for 30 days.', 200, '📈'),
        ]

        for mtype, title, desc, xp, emoji in milestone_defs:
            GroupMilestone.objects.get_or_create(
                collaborative_habit=habit,
                milestone_type=mtype,
                defaults={
                    'title': title,
                    'description': desc,
                    'xp_reward': xp,
                    'badge_emoji': emoji,
                },
            )

    @staticmethod
    @transaction.atomic
    def _evaluate_milestones(habit: CollaborativeHabit,
                              member: CollaborativeHabitMember,
                              user) -> list:
        """
        Check and award any milestones that have been reached.
        Returns list of newly achieved GroupMilestone objects.
        """
        milestones = GroupMilestone.objects.filter(
            collaborative_habit=habit, achieved=False,
        )

        newly_achieved = []
        for milestone in milestones:
            achieved = False

            if milestone.milestone_type == 'all_complete_day':
                today = timezone.now().date()
                active = habit.members.filter(is_active=True).count()
                completed = habit.progress_records.filter(
                    date=today, completed=True,
                ).values('user').distinct().count()
                achieved = active > 1 and completed >= active

            elif milestone.milestone_type == 'total_completions_100':
                habit.refresh_from_db()
                achieved = habit.total_completions >= 100

            elif milestone.milestone_type == 'total_completions_500':
                habit.refresh_from_db()
                achieved = habit.total_completions >= 500

            elif milestone.milestone_type == 'group_streak_7':
                achieved = GrowTogetherService._check_group_streak(habit, 7)

            elif milestone.milestone_type == 'group_streak_30':
                achieved = GrowTogetherService._check_group_streak(habit, 30)

            elif milestone.milestone_type == 'consistency_30':
                achieved = GrowTogetherService._check_consistency(habit, 30, 0.8)

            if achieved:
                milestone.achieved = True
                milestone.achieved_at = timezone.now()
                milestone.achieved_by = user
                milestone.save(update_fields=['achieved', 'achieved_at', 'achieved_by'])

                newly_achieved.append(milestone)

                # Award XP to all active members
                active_members = habit.members.filter(is_active=True)
                for m in active_members:
                    GrowTogetherService._award_xp(
                        m.user, milestone.xp_reward,
                        f'Milestone: {milestone.title}',
                    )

                # Activity log
                HabitActivityLog.objects.create(
                    collaborative_habit=habit,
                    actor=user,
                    action='group_milestone',
                    description=f'{milestone.badge_emoji} {milestone.title} achieved!',
                    metadata={
                        'milestoneType': milestone.milestone_type,
                        'xpReward': milestone.xp_reward,
                    },
                )

                # Notification
                GrowTogetherService._send_milestone_notification(habit, milestone)

        return newly_achieved

    @staticmethod
    def _check_group_streak(habit: CollaborativeHabit, days: int) -> bool:
        """Check if ALL active members have completed for N consecutive days."""
        today = timezone.now().date()
        active_members = habit.members.filter(is_active=True)
        active_count = active_members.count()

        if active_count < 2:
            return False

        for i in range(days):
            check_date = today - timedelta(days=i)
            completed_count = habit.progress_records.filter(
                date=check_date, completed=True,
            ).values('user').distinct().count()
            if completed_count < active_count:
                return False

        return True

    @staticmethod
    def _check_consistency(habit: CollaborativeHabit,
                           days: int, threshold: float) -> bool:
        """Check if the group has ≥ threshold completion rate for N days."""
        today = timezone.now().date()
        active_count = habit.members.filter(is_active=True).count()

        if active_count < 2:
            return False

        for i in range(days):
            check_date = today - timedelta(days=i)
            completed = habit.progress_records.filter(
                date=check_date, completed=True,
            ).values('user').distinct().count()
            rate = completed / active_count
            if rate < threshold:
                return False

        return True

    @staticmethod
    @transaction.atomic
    def _check_all_complete_bonus(habit: CollaborativeHabit, target_date: date):
        """
        Check if all active members completed today.
        If so, award bonus XP to every member.
        """
        active_count = habit.members.filter(is_active=True).count()
        if active_count < 2:
            return

        completed_count = habit.progress_records.filter(
            date=target_date, completed=True,
        ).values('user').distinct().count()

        if completed_count >= active_count:
            # Check if bonus already awarded today
            already = HabitActivityLog.objects.filter(
                collaborative_habit=habit,
                action='all_completed',
                created_at__date=target_date,
            ).exists()

            if not already:
                bonus_xp = habit.bonus_all_complete_xp
                for member in habit.members.filter(is_active=True):
                    member.total_xp_earned += bonus_xp
                    member.save(update_fields=['total_xp_earned'])
                    GrowTogetherService._award_xp(
                        member.user, bonus_xp,
                        f'Team bonus: All completed "{habit.title}"',
                    )

                HabitActivityLog.objects.create(
                    collaborative_habit=habit,
                    actor=habit.owner,
                    action='all_completed',
                    description=f'🎉 All {active_count} members completed "{habit.title}" today!',
                    metadata={
                        'bonusXp': bonus_xp,
                        'memberCount': active_count,
                    },
                )

    # ═══════════════════════════════════════════════════════════════════
    #  ANALYTICS
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_habit_analytics(collaborative_habit_id: str) -> dict:
        """
        Compute engagement analytics for a collaborative habit.

        Returns:
            - Engagement rate (members who completed vs total active)
            - Completion percentage per day (last 7 / 30 days)
            - Drop-off analysis (members who haven't completed in 3+ days)
            - Individual member stats
        """
        try:
            habit = CollaborativeHabit.objects.get(id=collaborative_habit_id)
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        today = timezone.now().date()
        active_members = habit.members.filter(is_active=True)
        active_count = active_members.count()

        # ── Daily completion rates (last 7 days) ────────────────────
        daily_rates = []
        for i in range(7):
            check_date = today - timedelta(days=i)
            completed = habit.progress_records.filter(
                date=check_date, completed=True,
            ).values('user').distinct().count()
            rate = (completed / active_count * 100) if active_count > 0 else 0
            daily_rates.append({
                'date': check_date.isoformat(),
                'completedCount': completed,
                'totalMembers': active_count,
                'rate': round(rate, 1),
            })

        # ── Engagement rate (avg last 7 days) ────────────────────────
        avg_rate = sum(d['rate'] for d in daily_rates) / len(daily_rates) if daily_rates else 0

        # ── Drop-off analysis ────────────────────────────────────────
        three_days_ago = today - timedelta(days=3)
        recently_active_ids = set(
            habit.progress_records.filter(
                date__gte=three_days_ago, completed=True,
            ).values_list('user_id', flat=True).distinct()
        )
        dropout_members = active_members.exclude(
            user_id__in=recently_active_ids,
        ).select_related('user')

        dropoffs = [
            {
                'userId': m.user_id,
                'userName': m.user.name,
                'lastCompleted': m.last_completed_date.isoformat() if m.last_completed_date else None,
                'daysMissed': (today - m.last_completed_date).days if m.last_completed_date else None,
            }
            for m in dropout_members
        ]

        # ── Member ranking ───────────────────────────────────────────
        member_stats = []
        for m in active_members.select_related('user').order_by('-total_completions'):
            member_stats.append({
                'userId': m.user_id,
                'userName': m.user.name,
                'totalCompletions': m.total_completions,
                'currentStreak': m.current_streak,
                'bestStreak': m.best_streak,
                'totalXp': m.total_xp_earned,
            })

        return {
            'engagementRate': round(avg_rate, 1),
            'dailyRates': daily_rates,
            'dropoffs': dropoffs,
            'dropoffCount': len(dropoffs),
            'memberStats': member_stats,
            'totalCompletions': habit.total_completions,
            'memberCount': active_count,
        }

    # ═══════════════════════════════════════════════════════════════════
    #  ABUSE REPORTING
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def report_abuse(user, collaborative_habit_id: str,
                     reported_user_id: int, reason: str,
                     description: str) -> AbuseReport:
        """File an abuse report against a member."""
        try:
            habit = CollaborativeHabit.objects.get(id=collaborative_habit_id)
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        # Verify reporter is a member
        if not habit.members.filter(user=user, is_active=True).exists():
            raise ValueError('You must be a member to report abuse.')

        # Prevent self-reporting
        if user.id == reported_user_id:
            raise ValueError('You cannot report yourself.')

        report = AbuseReport.objects.create(
            reporter=user,
            reported_user_id=reported_user_id,
            collaborative_habit=habit,
            reason=reason,
            description=description,
        )

        logger.warning(
            'Abuse report filed: %s reported %s in habit %s (reason: %s)',
            user.email, reported_user_id, habit.title, reason,
        )

        return report

    # ═══════════════════════════════════════════════════════════════════
    #  DASHBOARD AGGREGATE
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_dashboard(user) -> dict:
        """
        Build the Grow Together dashboard for a user.

        Combines:
            - My collaborative habits
            - Pending invitations
            - Discoverable public habits
            - Recent activity across all habits
            - Summary stats
        """
        my_habits = list(GrowTogetherService.get_user_collaborative_habits(user))
        pending_invites = list(GrowTogetherService.get_pending_invites(user))
        discoverable = list(GrowTogetherService.get_discoverable_habits(user, limit=10))
        recent_activity = list(GrowTogetherService.get_global_feed(user, limit=20))

        today = timezone.now().date()
        my_habit_ids = [h.id for h in my_habits]
        completions_today = CollaborativeHabitProgress.objects.filter(
            collaborative_habit_id__in=my_habit_ids,
            user=user,
            date=today,
            completed=True,
        ).count()

        # Calculate overall group streak (min streak across member records)
        my_memberships = CollaborativeHabitMember.objects.filter(
            user=user, is_active=True,
        )
        min_streak = 0
        if my_memberships.exists():
            min_streak = min(m.current_streak for m in my_memberships)

        return {
            'myCollaborativeHabits': my_habits,
            'pendingInvites': pending_invites,
            'discoverableHabits': discoverable,
            'recentActivity': recent_activity,
            'totalActiveHabits': len(my_habits),
            'totalCompletionsToday': completions_today,
            'overallGroupStreak': min_streak,
        }

    # ═══════════════════════════════════════════════════════════════════
    #  UNMARK PROGRESS (Undo today's completion)
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def unmark_progress(user, collaborative_habit_id: str) -> dict:
        """
        Undo today's progress (mark as not completed).

        Reverses:
            - Marks today's progress record as not completed.
            - Reverts streak (recalculates from history).
            - Deducts the XP that was awarded.
            - Decrements the habit's total completions counter.

        Returns a summary dict with the updated member state.
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        today = timezone.now().date()

        try:
            progress = CollaborativeHabitProgress.objects.get(
                member=member, date=today,
            )
        except CollaborativeHabitProgress.DoesNotExist:
            raise ValueError('No progress record found for today.')

        if not progress.completed:
            raise ValueError('Today is already marked as not completed.')

        # 5-minute undo window
        if progress.completed_at:
            elapsed = timezone.now() - progress.completed_at
            if elapsed.total_seconds() > 300:  # 5 minutes
                raise ValueError(
                    'Undo window expired. You can only undo within 5 minutes '
                    'of marking complete.'
                )

        # Deduct XP
        xp_to_remove = progress.xp_earned
        member.total_xp_earned = max(0, member.total_xp_earned - xp_to_remove)
        member.total_completions = max(0, member.total_completions - 1)

        # Recalculate streak from history
        yesterday = today - timedelta(days=1)
        new_streak = 0
        check_date = yesterday
        while True:
            prev = CollaborativeHabitProgress.objects.filter(
                member=member, date=check_date, completed=True,
            ).exists()
            # Also check if a streak freeze was used on this date
            freeze_used = StreakFreeze.objects.filter(
                member=member, status='used', used_on_date=check_date,
            ).exists()
            if prev or freeze_used:
                new_streak += 1
                check_date -= timedelta(days=1)
            else:
                break

        member.current_streak = new_streak
        member.last_completed_date = yesterday if new_streak > 0 else None
        member.save(update_fields=[
            'current_streak', 'total_completions', 'total_xp_earned',
            'last_completed_date', 'updated_at',
        ])

        # Mark progress as incomplete
        progress.completed = False
        progress.completion_count = 0
        progress.xp_earned = 0
        progress.completed_at = None
        progress.save(update_fields=[
            'completed', 'completion_count', 'xp_earned',
            'completed_at', 'updated_at',
        ])

        # Decrement habit counter
        CollaborativeHabit.objects.filter(id=habit.id).update(
            total_completions=F('total_completions') - 1,
        )

        # Activity log
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='completed',
            description=f'{user.name} unmarked "{habit.title}" for today',
            metadata={'action': 'unmarked', 'xpDeducted': xp_to_remove},
        )

        return {
            'currentStreak': member.current_streak,
            'bestStreak': member.best_streak,
            'totalCompletions': member.total_completions,
            'totalXpEarned': member.total_xp_earned,
            'xpDeducted': xp_to_remove,
        }

    # ═══════════════════════════════════════════════════════════════════
    #  STREAK CALENDAR (30-day visual history)
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def get_streak_calendar(user, collaborative_habit_id: str,
                            days: int = 30) -> dict:
        """
        Return a date-keyed calendar of completion statuses for the
        requesting user within a collaborative habit.

        Each date entry contains:
            - completed (bool)
            - completionCount (int)
            - note (str)
            - xpEarned (int)
            - freezeUsed (bool)  — whether a streak freeze protected this day

        Also returns the member's current streak info.
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        today = timezone.now().date()
        start_date = today - timedelta(days=days - 1)

        # Fetch progress records for the date range
        progress_records = {
            p.date: p
            for p in CollaborativeHabitProgress.objects.filter(
                member=member,
                date__gte=start_date,
                date__lte=today,
            )
        }

        # Fetch freeze records for the date range
        freeze_dates = set(
            StreakFreeze.objects.filter(
                member=member,
                status='used',
                used_on_date__gte=start_date,
                used_on_date__lte=today,
            ).values_list('used_on_date', flat=True)
        )

        # Available freezes count
        available_freezes = StreakFreeze.objects.filter(
            member=member, status='available',
        ).count()

        calendar = []
        for i in range(days):
            d = start_date + timedelta(days=i)
            progress = progress_records.get(d)
            freeze_used = d in freeze_dates
            calendar.append({
                'date': d.isoformat(),
                'completed': progress.completed if progress else False,
                'completionCount': progress.completion_count if progress else 0,
                'note': progress.note if progress else '',
                'xpEarned': progress.xp_earned if progress else 0,
                'freezeUsed': freeze_used,
            })

        return {
            'calendar': calendar,
            'currentStreak': member.current_streak,
            'bestStreak': member.best_streak,
            'totalCompletions': member.total_completions,
            'totalXpEarned': member.total_xp_earned,
            'lastCompletedDate': (
                member.last_completed_date.isoformat()
                if member.last_completed_date else None
            ),
            'availableFreezes': available_freezes,
            'todayCompleted': (
                today in progress_records
                and progress_records[today].completed
            ),
        }

    # ═══════════════════════════════════════════════════════════════════
    #  STREAK FREEZE MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    @transaction.atomic
    def purchase_streak_freeze(user, collaborative_habit_id: str,
                               xp_cost: int = 50) -> StreakFreeze:
        """
        Purchase a streak freeze using XP.

        Validates:
            - User is a member.
            - User has enough XP.
            - Doesn't exceed max freezes (3 available).

        Deducts XP and creates an available freeze token.
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        # Check available freeze limit
        available = StreakFreeze.objects.filter(
            member=member, status='available',
        ).count()
        if available >= 3:
            raise ValueError(
                'You already have 3 streak freezes. Use one before buying more.'
            )

        # Check XP balance
        if member.total_xp_earned < xp_cost:
            raise ValueError(
                f'Not enough XP. You need {xp_cost} XP but have '
                f'{member.total_xp_earned} XP.'
            )

        # Deduct XP
        member.total_xp_earned -= xp_cost
        member.save(update_fields=['total_xp_earned', 'updated_at'])

        # Create freeze
        freeze = StreakFreeze.objects.create(
            member=member,
            collaborative_habit=habit,
            status='available',
            source='purchased',
            expires_at=timezone.now() + timedelta(days=30),
        )

        # Activity log
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='settings_changed',
            description=f'{user.name} purchased a streak freeze ({xp_cost} XP)',
            metadata={'action': 'freeze_purchased', 'xpCost': xp_cost},
        )

        return freeze

    @staticmethod
    @transaction.atomic
    def use_streak_freeze(user, collaborative_habit_id: str,
                          target_date=None) -> StreakFreeze:
        """
        Manually use a streak freeze to protect a missed day.

        If no target_date is provided, uses yesterday (the most recent
        missed day). The freeze prevents the streak from resetting and
        recalculates the streak accordingly.
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        today = timezone.now().date()
        if target_date is None:
            target_date = today - timedelta(days=1)

        # Ensure the target day was actually missed
        already_completed = CollaborativeHabitProgress.objects.filter(
            member=member, date=target_date, completed=True,
        ).exists()
        if already_completed:
            raise ValueError(
                f'You already completed the habit on {target_date}. '
                f'No freeze needed.'
            )

        # Check if freeze already used on this date
        already_frozen = StreakFreeze.objects.filter(
            member=member, status='used', used_on_date=target_date,
        ).exists()
        if already_frozen:
            raise ValueError(f'A streak freeze was already used on {target_date}.')

        # Find an available freeze
        freeze = StreakFreeze.objects.filter(
            member=member, status='available',
        ).order_by('created_at').first()

        if not freeze:
            raise ValueError(
                'No streak freezes available. Earn or purchase one first.'
            )

        # Mark as used
        freeze.status = 'used'
        freeze.used_on_date = target_date
        freeze.save(update_fields=['status', 'used_on_date', 'updated_at'])

        # Recalculate streak from today backwards
        new_streak = 0
        check_date = today
        while True:
            completed = CollaborativeHabitProgress.objects.filter(
                member=member, date=check_date, completed=True,
            ).exists()
            freeze_used = StreakFreeze.objects.filter(
                member=member, status='used', used_on_date=check_date,
            ).exists()

            if completed or freeze_used:
                new_streak += 1
                check_date -= timedelta(days=1)
            else:
                break

        member.current_streak = new_streak
        member.best_streak = max(member.best_streak, new_streak)
        member.save(update_fields=[
            'current_streak', 'best_streak', 'updated_at',
        ])

        # Activity log
        HabitActivityLog.objects.create(
            collaborative_habit=habit,
            actor=user,
            action='settings_changed',
            description=(
                f'{user.name} used a streak freeze for {target_date} '
                f'(streak preserved: {new_streak} days)'
            ),
            metadata={
                'action': 'freeze_used',
                'date': target_date.isoformat(),
                'streak': new_streak,
            },
        )

        return freeze

    @staticmethod
    def get_streak_freezes(user, collaborative_habit_id: str) -> dict:
        """
        Return streak freeze info for a member.

        Includes available, used, and total counts.
        """
        try:
            habit = CollaborativeHabit.objects.get(
                id=collaborative_habit_id, is_active=True,
            )
        except CollaborativeHabit.DoesNotExist:
            raise ValueError('Collaborative habit not found.')

        try:
            member = CollaborativeHabitMember.objects.get(
                collaborative_habit=habit, user=user, is_active=True,
            )
        except CollaborativeHabitMember.DoesNotExist:
            raise ValueError('You are not a member of this habit.')

        available = StreakFreeze.objects.filter(
            member=member, status='available',
        )
        used = StreakFreeze.objects.filter(
            member=member, status='used',
        ).order_by('-used_on_date')

        return {
            'available': list(available),
            'used': list(used),
            'availableCount': available.count(),
            'usedCount': used.count(),
            'maxFreezes': 3,
            'freezeCostXp': 50,
            'memberXp': member.total_xp_earned,
        }

    # ═══════════════════════════════════════════════════════════════════
    #  NOTIFICATION HELPERS (Integration with notifications app)
    # ═══════════════════════════════════════════════════════════════════

    @staticmethod
    def _award_xp(user, amount: int, reason: str):
        """Award XP through the gamification engine (if available)."""
        try:
            from gamification.models import XPEvent
            XPEvent.objects.create(
                user=user,
                event_type='collaborative_habit',
                xp_amount=amount,
                description=reason,
            )
        except Exception as e:
            logger.warning('Failed to award XP: %s', e)

    @staticmethod
    def _send_invite_notifications(habit, sender, user_ids: set):
        """Send push notifications for habit invitations."""
        try:
            from notifications.models import Notification
            for uid in user_ids:
                Notification.objects.create(
                    user_id=uid,
                    notification_type='social',
                    title='Habit Invitation 🤝',
                    message=f'{sender.name} invited you to track "{habit.title}" together!',
                    metadata={
                        'type': 'grow_together_invite',
                        'habitId': str(habit.id),
                        'senderId': sender.id,
                    },
                )
        except Exception as e:
            logger.warning('Failed to send invite notifications: %s', e)

    @staticmethod
    def _send_member_joined_notification(habit, new_member):
        """Notify the habit owner that someone joined."""
        try:
            from notifications.models import Notification
            if habit.owner_id != new_member.id:
                Notification.objects.create(
                    user=habit.owner,
                    notification_type='social',
                    title='New Team Member! 🎉',
                    message=f'{new_member.name} joined "{habit.title}"',
                    metadata={
                        'type': 'grow_together_join',
                        'habitId': str(habit.id),
                        'userId': new_member.id,
                    },
                )
        except Exception as e:
            logger.warning('Failed to send join notification: %s', e)

    @staticmethod
    def _send_streak_notification(habit, user, streak_count: int):
        """Notify all members about a streak milestone."""
        try:
            from notifications.models import Notification
            member_ids = list(
                habit.members.filter(is_active=True).exclude(
                    user=user,
                ).values_list('user_id', flat=True)
            )
            for uid in member_ids:
                Notification.objects.create(
                    user_id=uid,
                    notification_type='social',
                    title=f'🔥 {streak_count}-Day Streak!',
                    message=f'{user.name} hit a {streak_count}-day streak in "{habit.title}"!',
                    metadata={
                        'type': 'grow_together_streak',
                        'habitId': str(habit.id),
                        'streak': streak_count,
                    },
                )
        except Exception as e:
            logger.warning('Failed to send streak notification: %s', e)

    @staticmethod
    def _send_milestone_notification(habit, milestone):
        """Notify all members about a group milestone."""
        try:
            from notifications.models import Notification
            member_ids = list(
                habit.members.filter(is_active=True).values_list('user_id', flat=True)
            )
            for uid in member_ids:
                Notification.objects.create(
                    user_id=uid,
                    notification_type='achievement',
                    title=f'{milestone.badge_emoji} Milestone Achieved!',
                    message=f'"{habit.title}" team unlocked: {milestone.title}',
                    metadata={
                        'type': 'grow_together_milestone',
                        'habitId': str(habit.id),
                        'milestoneType': milestone.milestone_type,
                        'xpReward': milestone.xp_reward,
                    },
                )
        except Exception as e:
            logger.warning('Failed to send milestone notification: %s', e)
