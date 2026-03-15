"""
Gamification Engine — gamification/services.py
==============================================

Core business logic for the full gamification system. This is the single
source of truth for all XP calculations, coin awards, streak freeze
management, challenge evaluation, milestone tracking, daily bonuses,
and leaderboard compilation.

Design Principles:
    1. **Server-authoritative**: All XP / coin calculations happen here.
       The client never sends XP amounts — only action triggers.
    2. **Anti-cheat**: Every award is validated against actual HabitLog
       records. Duplicate-detection prevents double-claiming.
    3. **Auditable**: Every XP and coin mutation creates an immutable
       XPEvent or CurrencyTransaction record.
    4. **Stateless methods**: All public methods are @staticmethod or
       @classmethod — no per-request state.

XP Formula Reference:
    Habit completion:     10 XP (base)
    Streak multiplier:    1.0 + min(streak_days, 30) * 0.05  (max 2.5x)
    All habits done:      25 XP bonus
    Weekly consistency:   50 XP (if ≥ 80% completion for the week)
    Achievement earned:   achievement.points XP
    Challenge completed:  challenge.xp_reward XP
    Daily login:          5 XP

Coin Formula Reference:
    Habit completion:     2 coins
    Streak milestone:     5–100 coins (varies by tier)
    All habits done:      5 coins
    Challenge completed:  challenge.coin_reward coins
"""

from datetime import timedelta
from django.db.models import Sum, Count, Q
from django.utils import timezone

from .models import (
    XPEvent, StreakFreeze, Challenge, ChallengeParticipant,
    LeaderboardEntry, VirtualCurrency, CurrencyTransaction,
    DailyBonus, MilestoneReward,
)
from achievements.models import UserLevel, UserAchievement
from achievements.services import AchievementService
from habits.models import Habit, HabitLog, Streak


# =============================================================================
# XP Configuration Constants
# =============================================================================

# Base XP awards
BASE_HABIT_XP = 10
ALL_DONE_BONUS_XP = 25
WEEKLY_CONSISTENCY_XP = 50
DAILY_LOGIN_XP = 5
LEVEL_UP_BONUS_XP = 50

# Base coin awards
BASE_HABIT_COINS = 2
ALL_DONE_BONUS_COINS = 5
DAILY_LOGIN_COINS = 3

# Streak multiplier config
STREAK_MULTIPLIER_CAP = 30              # Days at which multiplier maxes out
STREAK_MULTIPLIER_STEP = 0.05           # Per-day bonus (5% per streak day)
MAX_STREAK_MULTIPLIER = 2.5             # Maximum multiplier

# Streak freeze config
STREAK_FREEZE_COST = 50                 # Coins to buy one freeze
MAX_STREAK_FREEZES = 3                  # Maximum freezes a user can hold
STREAK_FREEZE_EXPIRY_DAYS = 30          # Days before an unused freeze expires

# Weekly consistency threshold
WEEKLY_CONSISTENCY_THRESHOLD = 0.80     # 80% completion required


# =============================================================================
# Gamification Engine
# =============================================================================

class GamificationEngine:
    """
    Central gamification service orchestrating XP, coins, challenges,
    streaks, milestones, and leaderboards.
    """

    # =====================================================================
    # XP Calculation & Award
    # =====================================================================

    @staticmethod
    def calculate_streak_multiplier(streak_days):
        """
        Calculate XP multiplier based on current streak length.

        Formula: 1.0 + min(streak_days, 30) * 0.05
        Range: 1.0x (no streak) to 2.5x (30+ day streak)

        Args:
            streak_days: Current consecutive-day streak count.

        Returns:
            float: Multiplier value between 1.0 and 2.5.
        """
        clamped = min(streak_days, STREAK_MULTIPLIER_CAP)
        multiplier = 1.0 + clamped * STREAK_MULTIPLIER_STEP
        return min(multiplier, MAX_STREAK_MULTIPLIER)

    @staticmethod
    def award_habit_completion_xp(user, habit):
        """
        Award XP and coins for completing a single habit.

        Applies the streak multiplier and logs the XP event.
        Also awards coins. This is the primary entry point called
        from the habit toggle-complete view.

        Args:
            user: The User instance.
            habit: The Habit instance that was completed.

        Returns:
            dict: Summary of awards granted.
        """
        today = timezone.now().date()

        # ── Anti-cheat: verify the completion actually exists ──
        if not HabitLog.objects.filter(
            habit=habit, date=today, status='completed'
        ).exists():
            return {'xp': 0, 'coins': 0, 'error': 'No completion found'}

        # ── Duplicate check: prevent double-awarding for same habit+day ──
        event_source_id = f"habit_{habit.id}_{today.isoformat()}"
        if XPEvent.objects.filter(
            user=user,
            source_id=event_source_id,
            source_type='habit_completion',
        ).exists():
            return {'xp': 0, 'coins': 0, 'already_awarded': True}

        # ── Calculate streak multiplier ──
        streak_days = 0
        try:
            streak_days = habit.streak.current_streak
        except Streak.DoesNotExist:
            pass

        multiplier = GamificationEngine.calculate_streak_multiplier(streak_days)
        xp_amount = int(BASE_HABIT_XP * multiplier)

        # ── Record XP event ──
        XPEvent.objects.create(
            user=user,
            amount=xp_amount,
            source_type='habit_completion',
            source_id=event_source_id,
            description=f"Completed '{habit.title}'",
            multiplier=multiplier,
            base_amount=BASE_HABIT_XP,
        )

        # ── Add XP to user level ──
        AchievementService.add_user_xp(user, xp_amount)

        # ── Award coins ──
        wallet = GamificationEngine._get_or_create_wallet(user)
        wallet.credit(
            BASE_HABIT_COINS,
            reason=f"Completed '{habit.title}'",
            source='habit_completion',
        )

        result = {
            'xp': xp_amount,
            'coins': BASE_HABIT_COINS,
            'multiplier': multiplier,
            'streak': streak_days,
        }

        # ── Check if all habits are done today → bonus ──
        all_done_result = GamificationEngine.check_all_habits_done(user)
        if all_done_result.get('awarded'):
            result['all_done_bonus'] = all_done_result

        # ── Update challenge progress ──
        GamificationEngine.update_challenge_progress(user, 'habit_completion')

        return result

    @staticmethod
    def check_all_habits_done(user):
        """
        Check if the user has completed ALL active habits today and
        award the daily-all-done bonus if so.

        Returns:
            dict: Bonus details if awarded, empty dict otherwise.
        """
        today = timezone.now().date()

        # Get all active habits scheduled for today
        active_habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        total = active_habits.count()
        if total == 0:
            return {}

        completed = HabitLog.objects.filter(
            habit__in=active_habits,
            date=today,
            status='completed',
        ).count()

        if completed < total:
            return {}

        # ── Duplicate check ──
        event_source_id = f"all_done_{today.isoformat()}"
        if XPEvent.objects.filter(
            user=user,
            source_id=event_source_id,
            source_type='daily_all_done',
        ).exists():
            return {'already_awarded': True}

        # ── Award XP ──
        XPEvent.objects.create(
            user=user,
            amount=ALL_DONE_BONUS_XP,
            source_type='daily_all_done',
            source_id=event_source_id,
            description='Completed all habits today!',
            base_amount=ALL_DONE_BONUS_XP,
        )
        AchievementService.add_user_xp(user, ALL_DONE_BONUS_XP)

        # ── Award coins ──
        wallet = GamificationEngine._get_or_create_wallet(user)
        wallet.credit(
            ALL_DONE_BONUS_COINS,
            reason='All habits completed today',
            source='daily_all_done',
        )

        # ── Record daily bonus ──
        bonus, _ = DailyBonus.objects.get_or_create(
            user=user, date=today,
        )
        if not bonus.all_done_bonus_claimed:
            bonus.all_done_bonus_claimed = True
            bonus.xp_earned += ALL_DONE_BONUS_XP
            bonus.coins_earned += ALL_DONE_BONUS_COINS
            bonus.save()

        return {
            'awarded': True,
            'xp': ALL_DONE_BONUS_XP,
            'coins': ALL_DONE_BONUS_COINS,
        }

    @staticmethod
    def claim_daily_login_bonus(user):
        """
        Award the daily login bonus (idempotent per day).

        Returns:
            dict: Bonus details or indication it was already claimed.
        """
        today = timezone.now().date()
        bonus, created = DailyBonus.objects.get_or_create(
            user=user, date=today,
        )

        if bonus.login_bonus_claimed:
            return {'already_claimed': True}

        # ── Calculate consecutive login days for bonus multiplier ──
        yesterday = today - timedelta(days=1)
        consecutive_days = 1
        check_date = yesterday
        while DailyBonus.objects.filter(
            user=user, date=check_date, login_bonus_claimed=True
        ).exists():
            consecutive_days += 1
            check_date -= timedelta(days=1)

        # Bonus: extra 1 XP per consecutive day (max +7)
        extra_xp = min(consecutive_days, 7)
        total_xp = DAILY_LOGIN_XP + extra_xp

        # ── Record XP ──
        XPEvent.objects.create(
            user=user,
            amount=total_xp,
            source_type='daily_login',
            source_id=f"login_{today.isoformat()}",
            description=f"Daily login (day {consecutive_days})",
            base_amount=DAILY_LOGIN_XP,
        )
        AchievementService.add_user_xp(user, total_xp)

        # ── Award coins ──
        wallet = GamificationEngine._get_or_create_wallet(user)
        wallet.credit(
            DAILY_LOGIN_COINS,
            reason=f"Daily login bonus (day {consecutive_days})",
            source='daily_login',
        )

        bonus.login_bonus_claimed = True
        bonus.xp_earned += total_xp
        bonus.coins_earned += DAILY_LOGIN_COINS
        bonus.save()

        return {
            'xp': total_xp,
            'coins': DAILY_LOGIN_COINS,
            'consecutive_days': consecutive_days,
        }

    @staticmethod
    def award_weekly_consistency_bonus(user):
        """
        Check and award the weekly consistency bonus (≥80% completion).

        Should be called by a scheduled task every Monday.

        Returns:
            dict: Bonus details or empty if not earned.
        """
        today = timezone.now().date()
        week_start = today - timedelta(days=today.weekday() + 7)  # Previous Monday
        week_end = week_start + timedelta(days=6)                  # Previous Sunday

        active_habits = Habit.objects.filter(
            user=user, status='active', is_deleted=False
        )
        habit_count = active_habits.count()
        if habit_count == 0:
            return {}

        total_possible = habit_count * 7
        completed = HabitLog.objects.filter(
            habit__in=active_habits,
            date__range=[week_start, week_end],
            status='completed',
        ).count()

        rate = completed / total_possible if total_possible > 0 else 0

        if rate < WEEKLY_CONSISTENCY_THRESHOLD:
            return {'rate': round(rate * 100, 1), 'threshold_met': False}

        # ── Duplicate check ──
        source_id = f"weekly_{week_start.isoformat()}"
        if XPEvent.objects.filter(
            user=user,
            source_id=source_id,
            source_type='weekly_bonus',
        ).exists():
            return {'already_awarded': True}

        XPEvent.objects.create(
            user=user,
            amount=WEEKLY_CONSISTENCY_XP,
            source_type='weekly_bonus',
            source_id=source_id,
            description=f"Weekly consistency bonus ({round(rate * 100, 1)}%)",
            base_amount=WEEKLY_CONSISTENCY_XP,
        )
        AchievementService.add_user_xp(user, WEEKLY_CONSISTENCY_XP)

        wallet = GamificationEngine._get_or_create_wallet(user)
        wallet.credit(10, reason='Weekly consistency bonus', source='weekly_bonus')

        return {
            'awarded': True,
            'xp': WEEKLY_CONSISTENCY_XP,
            'coins': 10,
            'rate': round(rate * 100, 1),
        }

    # =====================================================================
    # Streak Freeze Management
    # =====================================================================

    @staticmethod
    def purchase_streak_freeze(user):
        """
        Purchase a streak freeze token using coins.

        Returns:
            dict: Result with freeze details or error.
        """
        # ── Check max freeze limit ──
        available = StreakFreeze.objects.filter(
            user=user, status='available'
        ).count()
        if available >= MAX_STREAK_FREEZES:
            return {'error': f'Maximum {MAX_STREAK_FREEZES} freezes allowed'}

        # ── Debit coins ──
        wallet = GamificationEngine._get_or_create_wallet(user)
        if wallet.balance < STREAK_FREEZE_COST:
            return {'error': 'Insufficient coins', 'cost': STREAK_FREEZE_COST, 'balance': wallet.balance}

        wallet.debit(
            STREAK_FREEZE_COST,
            reason='Purchased streak freeze',
            source='streak_freeze_purchase',
        )

        expires_at = timezone.now() + timedelta(days=STREAK_FREEZE_EXPIRY_DAYS)
        freeze = StreakFreeze.objects.create(
            user=user,
            cost_coins=STREAK_FREEZE_COST,
            expires_at=expires_at,
        )

        return {
            'success': True,
            'freeze_id': freeze.id,
            'available_freezes': available + 1,
            'coins_remaining': wallet.balance,
            'expires_at': expires_at.isoformat(),
        }

    @staticmethod
    def consume_streak_freeze(user, date=None):
        """
        Attempt to consume a streak freeze to protect a streak.

        Called by the nightly streak-check job when a missed day is detected.

        Returns:
            bool: True if a freeze was consumed, False if none available.
        """
        freeze = StreakFreeze.objects.filter(
            user=user,
            status='available',
        ).order_by('purchased_at').first()

        if not freeze:
            return False

        # Check expiry
        if freeze.expires_at and freeze.expires_at < timezone.now():
            freeze.status = 'expired'
            freeze.save()
            return GamificationEngine.consume_streak_freeze(user, date)  # Try next

        freeze.consume(date)
        return True

    @staticmethod
    def get_user_freezes(user):
        """Get count and details of available streak freezes."""
        freezes = StreakFreeze.objects.filter(user=user, status='available')
        return {
            'available': freezes.count(),
            'max': MAX_STREAK_FREEZES,
            'cost': STREAK_FREEZE_COST,
            'freezes': [
                {
                    'id': f.id,
                    'purchased_at': f.purchased_at.isoformat(),
                    'expires_at': f.expires_at.isoformat() if f.expires_at else None,
                }
                for f in freezes
            ],
        }

    # =====================================================================
    # Challenge Management
    # =====================================================================

    @staticmethod
    def create_challenge(user, data):
        """
        Create a new challenge and auto-join the creator.

        Args:
            user: The creating User.
            data: Dict with challenge fields.

        Returns:
            Challenge: The created challenge instance.
        """
        import uuid
        scope = data.get('scope', 'personal')
        max_participants = data.get('max_participants', 1)
        # Community and friend challenges should allow multiple participants
        if scope in ('community', 'friend') and max_participants <= 1:
            max_participants = 50 if scope == 'community' else 10

        challenge = Challenge.objects.create(
            title=data['title'],
            description=data.get('description', ''),
            scope=scope,
            difficulty=data.get('difficulty', 'medium'),
            criteria=data.get('criteria', {}),
            start_date=data.get('start_date', timezone.now()),
            end_date=data['end_date'],
            xp_reward=data.get('xp_reward', 100),
            coin_reward=data.get('coin_reward', 25),
            created_by=user,
            max_participants=max_participants,
            invite_code=uuid.uuid4().hex[:8] if scope != 'personal' else None,
            icon_code=data.get('icon_code', 0xE87C),
            color_value=data.get('color_value', 0xFF4F46E5),
            status='active',
        )

        # Auto-join the creator
        ChallengeParticipant.objects.create(
            challenge=challenge,
            user=user,
        )

        return challenge

    @staticmethod
    def join_challenge(user, challenge):
        """
        Join an existing challenge.

        Returns:
            dict: Result with participation details or error.
        """
        if ChallengeParticipant.objects.filter(
            challenge=challenge, user=user
        ).exists():
            return {'error': 'Already participating'}

        current = challenge.participants.count()
        if current >= challenge.max_participants:
            return {'error': 'Challenge is full'}

        if challenge.status != 'active':
            return {'error': 'Challenge is not active'}

        participant = ChallengeParticipant.objects.create(
            challenge=challenge,
            user=user,
        )

        return {
            'success': True,
            'participant_id': participant.id,
            'participants': current + 1,
            'max': challenge.max_participants,
        }

    @staticmethod
    def update_challenge_progress(user, trigger_type='habit_completion'):
        """
        Evaluate and update progress for all active challenges the user is in.

        Called after relevant events (habit completion, etc.).
        """
        today = timezone.now().date()
        participations = ChallengeParticipant.objects.filter(
            user=user,
            status='active',
            challenge__status='active',
        ).select_related('challenge')

        for p in participations:
            challenge = p.challenge
            criteria = challenge.criteria
            goal_type = criteria.get('type', 'completions')
            target = criteria.get('target', 0)

            if target <= 0:
                continue

            # ── Calculate progress based on criteria type ──
            progress = 0

            if goal_type == 'completions':
                # Count completions within the challenge period
                progress = HabitLog.objects.filter(
                    habit__user=user,
                    habit__status='active',
                    habit__is_deleted=False,
                    date__range=[challenge.start_date.date(), min(today, challenge.end_date.date())],
                    status='completed',
                ).count()

            elif goal_type == 'streak':
                # Best current streak across user's habits
                streaks = Streak.objects.filter(
                    habit__user=user,
                    habit__status='active',
                    habit__is_deleted=False,
                )
                progress = max(
                    (s.current_streak for s in streaks),
                    default=0,
                )

            elif goal_type == 'all_done_days':
                # Count days where ALL habits were completed
                period_days = criteria.get('period_days', 7)
                start = max(
                    challenge.start_date.date(),
                    today - timedelta(days=period_days - 1),
                )
                active_habits = Habit.objects.filter(
                    user=user, status='active', is_deleted=False
                )
                habit_count = active_habits.count()
                if habit_count > 0:
                    check = start
                    while check <= today:
                        day_completed = HabitLog.objects.filter(
                            habit__in=active_habits,
                            date=check,
                            status='completed',
                        ).count()
                        if day_completed >= habit_count:
                            progress += 1
                        check += timedelta(days=1)

            # ── Update participant record ──
            p.progress = min(progress, target)
            p.progress_percentage = round(min(progress / target, 1.0) * 100, 1)

            if progress >= target and p.status == 'active':
                # Challenge completed!
                p.status = 'completed'
                p.completed_at = timezone.now()
                p.save()
                GamificationEngine._award_challenge_completion(user, challenge)
            else:
                p.save()

    @staticmethod
    def _award_challenge_completion(user, challenge):
        """Award XP and coins for completing a challenge."""
        source_id = f"challenge_{challenge.id}"

        if XPEvent.objects.filter(
            user=user, source_id=source_id, source_type='challenge'
        ).exists():
            return

        # XP
        XPEvent.objects.create(
            user=user,
            amount=challenge.xp_reward,
            source_type='challenge',
            source_id=source_id,
            description=f"Completed challenge '{challenge.title}'",
            base_amount=challenge.xp_reward,
        )
        AchievementService.add_user_xp(user, challenge.xp_reward)

        # Coins
        if challenge.coin_reward > 0:
            wallet = GamificationEngine._get_or_create_wallet(user)
            wallet.credit(
                challenge.coin_reward,
                reason=f"Challenge completed: {challenge.title}",
                source='challenge',
            )

    @staticmethod
    def get_active_challenges(user):
        """Get all active challenges the user is participating in."""
        participations = ChallengeParticipant.objects.filter(
            user=user,
            challenge__status='active',
        ).select_related('challenge').order_by('-challenge__created_at')

        return [
            {
                'id': p.challenge.id,
                'title': p.challenge.title,
                'description': p.challenge.description,
                'scope': p.challenge.scope,
                'difficulty': p.challenge.difficulty,
                'criteria': p.challenge.criteria,
                'startDate': p.challenge.start_date.isoformat(),
                'endDate': p.challenge.end_date.isoformat(),
                'xpReward': p.challenge.xp_reward,
                'coinReward': p.challenge.coin_reward,
                'iconCode': p.challenge.icon_code,
                'colorValue': p.challenge.color_value,
                'status': p.status,
                'progress': p.progress,
                'progressPercentage': p.progress_percentage,
                'target': p.challenge.criteria.get('target', 0),
                'completedAt': p.completed_at.isoformat() if p.completed_at else None,
                'participantCount': p.challenge.participants.count(),
                'maxParticipants': p.challenge.max_participants,
                'timeRemaining': str(p.challenge.time_remaining),
            }
            for p in participations
        ]

    @staticmethod
    def get_community_challenges(user=None):
        """Get available community challenges that are active.

        If a user is provided, excludes challenges the user has already joined.
        """
        challenges = Challenge.objects.filter(
            scope='community',
            status='active',
            end_date__gt=timezone.now(),
        )

        if user is not None:
            joined_ids = ChallengeParticipant.objects.filter(
                user=user,
            ).values_list('challenge_id', flat=True)
            challenges = challenges.exclude(id__in=joined_ids)

        challenges = challenges.order_by('-is_featured', '-created_at')[:20]

        return [
            {
                'id': c.id,
                'title': c.title,
                'description': c.description,
                'difficulty': c.difficulty,
                'criteria': c.criteria,
                'startDate': c.start_date.isoformat(),
                'endDate': c.end_date.isoformat(),
                'xpReward': c.xp_reward,
                'coinReward': c.coin_reward,
                'iconCode': c.icon_code,
                'colorValue': c.color_value,
                'participantCount': c.participants.count(),
                'maxParticipants': c.max_participants,
                'isFeatured': c.is_featured,
            }
            for c in challenges
        ]

    # =====================================================================
    # Leaderboard
    # =====================================================================

    @staticmethod
    def ensure_leaderboard_fresh(board_type='weekly'):
        """
        Check if the leaderboard for the given type is fresh (updated within
        the last hour). If stale or empty, trigger a rebuild.
        """
        today = timezone.now().date()

        if board_type == 'weekly':
            period_start = today - timedelta(days=today.weekday())
        elif board_type == 'monthly':
            period_start = today.replace(day=1)
        else:
            period_start = today.replace(year=2020, month=1, day=1)

        latest = LeaderboardEntry.objects.filter(
            board_type=board_type,
            period_start=period_start,
        ).order_by('-updated_at').first()

        one_hour_ago = timezone.now() - timedelta(hours=1)
        if latest is None or latest.updated_at < one_hour_ago:
            GamificationEngine.rebuild_leaderboard(board_type)

    @staticmethod
    def rebuild_leaderboard(board_type='weekly'):
        """
        Rebuild the leaderboard for a given period type.

        Should be called by a scheduled task (e.g. every hour).
        """
        today = timezone.now().date()

        if board_type == 'weekly':
            period_start = today - timedelta(days=today.weekday())
            period_end = period_start + timedelta(days=6)
        elif board_type == 'monthly':
            period_start = today.replace(day=1)
            next_month = (period_start + timedelta(days=32)).replace(day=1)
            period_end = next_month - timedelta(days=1)
        else:  # alltime
            period_start = today.replace(year=2020, month=1, day=1)
            period_end = today

        # ── Aggregate scores for all users with activity ──
        from django.contrib.auth import get_user_model
        User = get_user_model()

        users_with_activity = User.objects.filter(
            is_active=True,
        ).prefetch_related('habits')

        entries = []
        for user in users_with_activity:
            active_habits = Habit.objects.filter(
                user=user, status='active', is_deleted=False
            )
            if not active_habits.exists():
                continue

            completions = HabitLog.objects.filter(
                habit__in=active_habits,
                date__range=[period_start, min(today, period_end)],
                status='completed',
            ).count()

            if completions == 0 and board_type != 'alltime':
                continue

            # XP earned in period
            xp = XPEvent.objects.filter(
                user=user,
                created_at__date__range=[period_start, min(today, period_end)],
            ).aggregate(total=Sum('amount'))['total'] or 0

            # Best streak in period
            best_streak = Streak.objects.filter(
                habit__in=active_habits,
            ).order_by('-current_streak').values_list(
                'current_streak', flat=True
            ).first() or 0

            # Consistency
            habit_count = active_habits.count()
            days_in_period = (min(today, period_end) - period_start).days + 1
            possible = habit_count * days_in_period
            consistency = round((completions / possible * 100) if possible > 0 else 0, 1)

            entries.append({
                'user': user,
                'score': xp,
                'completions': completions,
                'streak_days': best_streak,
                'consistency_pct': consistency,
            })

        # ── Sort by score and assign ranks ──
        entries.sort(key=lambda x: x['score'], reverse=True)

        for rank, entry in enumerate(entries, 1):
            # Get previous rank for change calculation
            prev = LeaderboardEntry.objects.filter(
                user=entry['user'],
                board_type=board_type,
                period_start=period_start,
            ).first()
            prev_rank = prev.rank if prev else rank

            LeaderboardEntry.objects.update_or_create(
                user=entry['user'],
                board_type=board_type,
                period_start=period_start,
                defaults={
                    'period_end': period_end,
                    'score': entry['score'],
                    'completions': entry['completions'],
                    'streak_days': entry['streak_days'],
                    'consistency_pct': entry['consistency_pct'],
                    'rank': rank,
                    'rank_change': prev_rank - rank,
                },
            )

    @staticmethod
    def get_leaderboard(user, board_type='weekly', limit=50):
        """
        Get leaderboard entries for the current period.

        Returns the top N entries plus the requesting user's entry.
        """
        today = timezone.now().date()

        if board_type == 'weekly':
            period_start = today - timedelta(days=today.weekday())
        elif board_type == 'monthly':
            period_start = today.replace(day=1)
        else:
            period_start = today.replace(year=2020, month=1, day=1)

        entries = LeaderboardEntry.objects.filter(
            board_type=board_type,
            period_start=period_start,
        ).select_related('user').order_by('rank')[:limit]

        user_entry = LeaderboardEntry.objects.filter(
            user=user,
            board_type=board_type,
            period_start=period_start,
        ).first()

        return {
            'boardType': board_type,
            'periodStart': period_start.isoformat(),
            'entries': [
                {
                    'rank': e.rank,
                    'rankChange': e.rank_change,
                    'userId': e.user.id,
                    'userName': e.user.name,
                    'profileImage': e.user.profile_image,
                    'score': e.score,
                    'completions': e.completions,
                    'streakDays': e.streak_days,
                    'consistencyPct': e.consistency_pct,
                    'isCurrentUser': e.user.id == user.id,
                }
                for e in entries
            ],
            'userRank': {
                'rank': user_entry.rank if user_entry else None,
                'rankChange': user_entry.rank_change if user_entry else 0,
                'score': user_entry.score if user_entry else 0,
            } if user_entry else None,
        }

    # =====================================================================
    # Milestone Rewards
    # =====================================================================

    @staticmethod
    def check_milestones(user):
        """
        Evaluate all milestone definitions against the user's current stats.

        Returns a list of newly-awarded milestone rewards.
        """
        newly_awarded = []
        milestones = MilestoneReward.objects.filter(is_active=True)

        for milestone in milestones:
            # ── Check if already awarded ──
            source_id = f"milestone_{milestone.milestone_type}_{milestone.threshold}"
            if XPEvent.objects.filter(
                user=user, source_id=source_id
            ).exists():
                continue

            # ── Evaluate ──
            current_value = 0

            if milestone.milestone_type == 'level_up':
                level, _ = UserLevel.objects.get_or_create(user=user)
                current_value = level.current_level

            elif milestone.milestone_type == 'streak':
                best = Streak.objects.filter(
                    habit__user=user,
                    habit__status='active',
                    habit__is_deleted=False,
                ).order_by('-current_streak').values_list(
                    'current_streak', flat=True
                ).first() or 0
                current_value = best

            elif milestone.milestone_type == 'completions':
                current_value = HabitLog.objects.filter(
                    habit__user=user, status='completed'
                ).count()

            elif milestone.milestone_type == 'days_active':
                current_value = DailyBonus.objects.filter(
                    user=user, login_bonus_claimed=True
                ).count()

            if current_value < milestone.threshold:
                continue

            # ── Award ──
            if milestone.xp_reward > 0:
                XPEvent.objects.create(
                    user=user,
                    amount=milestone.xp_reward,
                    source_type='level_up_bonus',
                    source_id=source_id,
                    description=f"Milestone: {milestone.title}",
                    base_amount=milestone.xp_reward,
                )
                AchievementService.add_user_xp(user, milestone.xp_reward)

            wallet = GamificationEngine._get_or_create_wallet(user)

            if milestone.coin_reward > 0:
                wallet.credit(
                    milestone.coin_reward,
                    reason=f"Milestone: {milestone.title}",
                    source='milestone',
                )

            # Award streak freezes
            for _ in range(milestone.streak_freeze_reward):
                StreakFreeze.objects.create(
                    user=user,
                    cost_coins=0,
                    expires_at=timezone.now() + timedelta(days=STREAK_FREEZE_EXPIRY_DAYS),
                )

            newly_awarded.append({
                'title': milestone.title,
                'description': milestone.description,
                'xp': milestone.xp_reward,
                'coins': milestone.coin_reward,
                'freezes': milestone.streak_freeze_reward,
                'iconCode': milestone.icon_code,
                'colorValue': milestone.color_value,
                'celebration': milestone.celebration_type,
            })

        return newly_awarded

    @staticmethod
    def seed_milestones():
        """Seed default milestone reward definitions."""
        defaults = [
            # Streak milestones
            {'type': 'streak', 'threshold': 7, 'title': '7-Day Streak!', 'desc': 'One week of consistency', 'xp': 50, 'coins': 25, 'freezes': 0, 'icon': 0xE80E, 'color': 0xFFC0C0C0, 'celebration': 'confetti'},
            {'type': 'streak', 'threshold': 14, 'title': '14-Day Streak!', 'desc': 'Two weeks strong', 'xp': 100, 'coins': 50, 'freezes': 1, 'icon': 0xE838, 'color': 0xFFFFD700, 'celebration': 'confetti'},
            {'type': 'streak', 'threshold': 30, 'title': '30-Day Streak!', 'desc': 'A full month of dedication', 'xp': 250, 'coins': 100, 'freezes': 1, 'icon': 0xE838, 'color': 0xFFFFD700, 'celebration': 'fireworks'},
            {'type': 'streak', 'threshold': 100, 'title': '100-Day Streak!', 'desc': 'Incredible dedication', 'xp': 500, 'coins': 250, 'freezes': 2, 'icon': 0xE838, 'color': 0xFF9400D3, 'celebration': 'fireworks'},
            {'type': 'streak', 'threshold': 365, 'title': 'Year-Long Streak!', 'desc': 'A full year of habit mastery', 'xp': 2000, 'coins': 1000, 'freezes': 5, 'icon': 0xE838, 'color': 0xFFFF4500, 'celebration': 'fireworks'},

            # Completion milestones
            {'type': 'completions', 'threshold': 50, 'title': '50 Completions', 'desc': 'Building momentum', 'xp': 40, 'coins': 20, 'freezes': 0, 'icon': 0xE876, 'color': 0xFFCD7F32, 'celebration': 'confetti'},
            {'type': 'completions', 'threshold': 100, 'title': '100 Completions', 'desc': 'Triple digits!', 'xp': 100, 'coins': 50, 'freezes': 1, 'icon': 0xE876, 'color': 0xFFC0C0C0, 'celebration': 'confetti'},
            {'type': 'completions', 'threshold': 500, 'title': '500 Completions', 'desc': 'Half a thousand habits done', 'xp': 300, 'coins': 150, 'freezes': 1, 'icon': 0xE876, 'color': 0xFFFFD700, 'celebration': 'fireworks'},
            {'type': 'completions', 'threshold': 1000, 'title': '1000 Completions', 'desc': 'A true habit champion', 'xp': 750, 'coins': 500, 'freezes': 2, 'icon': 0xE876, 'color': 0xFF9400D3, 'celebration': 'fireworks'},

            # Level milestones
            {'type': 'level_up', 'threshold': 3, 'title': 'Apprentice', 'desc': 'Reached Level 3', 'xp': 25, 'coins': 30, 'freezes': 0, 'icon': 0xE838, 'color': 0xFFCD7F32, 'celebration': 'glow'},
            {'type': 'level_up', 'threshold': 5, 'title': 'Advanced', 'desc': 'Reached Level 5', 'xp': 75, 'coins': 75, 'freezes': 1, 'icon': 0xE838, 'color': 0xFFC0C0C0, 'celebration': 'confetti'},
            {'type': 'level_up', 'threshold': 7, 'title': 'Master', 'desc': 'Reached Level 7', 'xp': 150, 'coins': 150, 'freezes': 1, 'icon': 0xE838, 'color': 0xFFFFD700, 'celebration': 'fireworks'},
            {'type': 'level_up', 'threshold': 10, 'title': 'Habit Champion', 'desc': 'Maximum level reached!', 'xp': 500, 'coins': 500, 'freezes': 3, 'icon': 0xE838, 'color': 0xFFFF4500, 'celebration': 'fireworks'},

            # Days active milestones
            {'type': 'days_active', 'threshold': 7, 'title': '7 Days Active', 'desc': 'One week of using DailyHabits', 'xp': 30, 'coins': 15, 'freezes': 0, 'icon': 0xE916, 'color': 0xFFCD7F32, 'celebration': 'confetti'},
            {'type': 'days_active', 'threshold': 30, 'title': '30 Days Active', 'desc': 'A month of commitment', 'xp': 100, 'coins': 50, 'freezes': 1, 'icon': 0xE916, 'color': 0xFFC0C0C0, 'celebration': 'confetti'},
            {'type': 'days_active', 'threshold': 100, 'title': '100 Days Active', 'desc': 'A century of daily engagement', 'xp': 300, 'coins': 200, 'freezes': 1, 'icon': 0xE916, 'color': 0xFFFFD700, 'celebration': 'fireworks'},
        ]

        created = 0
        for d in defaults:
            _, was_created = MilestoneReward.objects.get_or_create(
                milestone_type=d['type'],
                threshold=d['threshold'],
                defaults={
                    'title': d['title'],
                    'description': d['desc'],
                    'xp_reward': d['xp'],
                    'coin_reward': d['coins'],
                    'streak_freeze_reward': d['freezes'],
                    'icon_code': d['icon'],
                    'color_value': d['color'],
                    'celebration_type': d['celebration'],
                },
            )
            if was_created:
                created += 1
        return created

    # =====================================================================
    # Gamification Dashboard — Composite Payload
    # =====================================================================

    @staticmethod
    def get_gamification_dashboard(user):
        """
        Build the complete gamification dashboard payload.

        Aggregates XP, level, coins, streaks, challenges, achievements,
        and daily bonus status into a single response.
        """
        today = timezone.now().date()

        # ── Level & XP ──
        level, _ = UserLevel.objects.get_or_create(user=user)
        level_data = AchievementService.get_user_level(user)

        # ── Wallet ──
        wallet = GamificationEngine._get_or_create_wallet(user)

        # ── Today's XP ──
        today_xp = XPEvent.objects.filter(
            user=user,
            created_at__date=today,
        ).aggregate(total=Sum('amount'))['total'] or 0

        # ── This week's XP ──
        week_start = today - timedelta(days=today.weekday())
        week_xp = XPEvent.objects.filter(
            user=user,
            created_at__date__range=[week_start, today],
        ).aggregate(total=Sum('amount'))['total'] or 0

        # ── Streak freezes ──
        freezes = GamificationEngine.get_user_freezes(user)

        # ── Active challenges ──
        challenges = GamificationEngine.get_active_challenges(user)

        # ── Daily bonus status ──
        daily_bonus = DailyBonus.objects.filter(user=user, date=today).first()

        # ── Recent XP events (last 10) ──
        recent_xp = XPEvent.objects.filter(user=user)[:10]

        # ── Overall stats ──
        total_completions = HabitLog.objects.filter(
            habit__user=user, status='completed'
        ).count()

        best_streak = Streak.objects.filter(
            habit__user=user,
        ).order_by('-best_streak').values_list(
            'best_streak', flat=True
        ).first() or 0

        current_streak = Streak.objects.filter(
            habit__user=user,
            habit__status='active',
        ).order_by('-current_streak').values_list(
            'current_streak', flat=True
        ).first() or 0

        # ── Achievements summary ──
        total_achievements = UserAchievement.objects.filter(user=user).count()
        recent_achievements = AchievementService.get_recent_achievements(user, limit=3)

        return {
            'level': level_data,
            'wallet': {
                'balance': wallet.balance,
                'totalEarned': wallet.total_earned,
                'totalSpent': wallet.total_spent,
            },
            'xp': {
                'todayXp': today_xp,
                'weekXp': week_xp,
                'totalXp': level.total_xp,
                'streakMultiplier': GamificationEngine.calculate_streak_multiplier(current_streak),
            },
            'streaks': {
                'currentStreak': current_streak,
                'bestStreak': best_streak,
                'freezes': freezes,
            },
            'challenges': {
                'active': challenges[:5],
                'totalActive': len(challenges),
            },
            'dailyBonus': {
                'loginClaimed': daily_bonus.login_bonus_claimed if daily_bonus else False,
                'allDoneClaimed': daily_bonus.all_done_bonus_claimed if daily_bonus else False,
            },
            'stats': {
                'totalCompletions': total_completions,
                'totalAchievements': total_achievements,
                'daysActive': DailyBonus.objects.filter(
                    user=user, login_bonus_claimed=True
                ).count(),
            },
            'recentActivity': [
                {
                    'amount': e.amount,
                    'source': e.source_type,
                    'description': e.description,
                    'createdAt': e.created_at.isoformat(),
                }
                for e in recent_xp
            ],
            'recentAchievements': recent_achievements,
        }

    # =====================================================================
    # Utility Helpers
    # =====================================================================

    @staticmethod
    def _get_or_create_wallet(user):
        """Lazily create and return the user's virtual currency wallet."""
        wallet, _ = VirtualCurrency.objects.get_or_create(user=user)
        return wallet
