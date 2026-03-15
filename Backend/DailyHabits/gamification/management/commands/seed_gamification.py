"""
Management Command: seed_gamification
======================================

Seeds the gamification system with:
    1. Milestone reward definitions
    2. Sample community challenges
    3. Rebuilds all leaderboards

Usage:
    python manage.py seed_gamification
    python manage.py seed_gamification --challenges-only
    python manage.py seed_gamification --leaderboard-only
"""

from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.contrib.auth import get_user_model

from gamification.services import GamificationEngine
from gamification.models import Challenge, ChallengeParticipant

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed gamification data: milestones, community challenges, and leaderboards.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--challenges-only',
            action='store_true',
            help='Only seed community challenges.',
        )
        parser.add_argument(
            '--leaderboard-only',
            action='store_true',
            help='Only rebuild leaderboards.',
        )

    def handle(self, *args, **options):
        challenges_only = options.get('challenges_only', False)
        leaderboard_only = options.get('leaderboard_only', False)

        if not challenges_only and not leaderboard_only:
            self._seed_milestones()
            self._seed_community_challenges()
            self._rebuild_leaderboards()
        elif challenges_only:
            self._seed_community_challenges()
        elif leaderboard_only:
            self._rebuild_leaderboards()

        self.stdout.write(self.style.SUCCESS('Gamification seeding complete.'))

    def _seed_milestones(self):
        """Seed milestone reward definitions."""
        count = GamificationEngine.seed_milestones()
        self.stdout.write(f'  Milestones created: {count}')

    def _seed_community_challenges(self):
        """Create sample community challenges if none exist."""
        existing = Challenge.objects.filter(scope='community', status='active').count()
        if existing >= 5:
            self.stdout.write(f'  Community challenges already exist ({existing}). Skipping.')
            return

        # Get or create a system user as challenge creator
        admin_user = User.objects.filter(is_staff=True).first()
        if not admin_user:
            admin_user = User.objects.first()
        if not admin_user:
            self.stdout.write(self.style.WARNING('  No users found. Skipping challenge seeding.'))
            return

        now = timezone.now()
        challenges = [
            {
                'title': '7-Day Habit Streak',
                'description': 'Maintain a streak of at least 7 days on any habit. Build consistency and earn bonus rewards!',
                'difficulty': 'easy',
                'criteria': {'type': 'streak', 'target': 7},
                'xp_reward': 150,
                'coin_reward': 50,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=14),
                'icon_code': 0xE80E,
                'color_value': 0xFF22C55E,
            },
            {
                'title': 'Complete 50 Habits',
                'description': 'Complete 50 habit check-ins within 2 weeks. Stay active and crush your goals!',
                'difficulty': 'medium',
                'criteria': {'type': 'completions', 'target': 50},
                'xp_reward': 300,
                'coin_reward': 100,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=14),
                'icon_code': 0xE876,
                'color_value': 0xFF3B82F6,
            },
            {
                'title': 'Perfect Week Challenge',
                'description': 'Complete ALL your habits every day for 5 out of 7 days this week. Show your dedication!',
                'difficulty': 'hard',
                'criteria': {'type': 'all_done_days', 'target': 5, 'period_days': 7},
                'xp_reward': 500,
                'coin_reward': 150,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=7),
                'icon_code': 0xE838,
                'color_value': 0xFFF59E0B,
            },
            {
                'title': '30-Day Consistency Master',
                'description': 'Complete at least 100 habits in 30 days. Prove you are a true habit champion!',
                'difficulty': 'hard',
                'criteria': {'type': 'completions', 'target': 100},
                'xp_reward': 750,
                'coin_reward': 250,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=30),
                'icon_code': 0xE87C,
                'color_value': 0xFF9400D3,
            },
            {
                'title': '14-Day Streak Legend',
                'description': 'Achieve a 14-day streak on any habit. Only the most dedicated will succeed!',
                'difficulty': 'extreme',
                'criteria': {'type': 'streak', 'target': 14},
                'xp_reward': 1000,
                'coin_reward': 500,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=30),
                'icon_code': 0xE838,
                'color_value': 0xFFFF4500,
            },
            {
                'title': 'Early Bird Sprint',
                'description': 'Complete 20 habits in 5 days. A quick sprint to build momentum!',
                'difficulty': 'easy',
                'criteria': {'type': 'completions', 'target': 20},
                'xp_reward': 100,
                'coin_reward': 30,
                'max_participants': 100,
                'start_date': now,
                'end_date': now + timedelta(days=5),
                'icon_code': 0xE518,
                'color_value': 0xFF06B6D4,
            },
        ]

        created = 0
        for c in challenges:
            if Challenge.objects.filter(title=c['title'], scope='community', status='active').exists():
                continue

            challenge = Challenge.objects.create(
                title=c['title'],
                description=c['description'],
                scope='community',
                status='active',
                difficulty=c['difficulty'],
                criteria=c['criteria'],
                start_date=c['start_date'],
                end_date=c['end_date'],
                xp_reward=c['xp_reward'],
                coin_reward=c['coin_reward'],
                created_by=admin_user,
                max_participants=c['max_participants'],
                icon_code=c['icon_code'],
                color_value=c['color_value'],
                is_featured=True,
            )
            # Auto-join the creator
            ChallengeParticipant.objects.get_or_create(
                challenge=challenge,
                user=admin_user,
            )
            created += 1

        self.stdout.write(f'  Community challenges created: {created}')

    def _rebuild_leaderboards(self):
        """Rebuild all leaderboard types."""
        for board_type in ['weekly', 'monthly', 'alltime']:
            GamificationEngine.rebuild_leaderboard(board_type)
            self.stdout.write(f'  Rebuilt {board_type} leaderboard.')
