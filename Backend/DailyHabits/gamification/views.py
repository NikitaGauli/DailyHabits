"""
Gamification API Views
======================

DRF ViewSet providing all gamification endpoints. Uses JWT authentication
and server-side validation for all XP / coin mutations.

Endpoint overview:
    GET  /api/gamification/               — Full gamification dashboard
    POST /api/gamification/claim-login/   — Claim daily login bonus
    GET  /api/gamification/wallet/        — Wallet balance & transactions
    GET  /api/gamification/xp-history/    — Paginated XP event history
    POST /api/gamification/buy-freeze/    — Purchase a streak freeze
    GET  /api/gamification/freezes/       — List available streak freezes
    GET  /api/gamification/challenges/    — Active challenges for the user
    POST /api/gamification/challenges/create/ — Create a new challenge
    POST /api/gamification/challenges/{id}/join/ — Join a challenge
    GET  /api/gamification/community-challenges/ — Browse community challenges
    GET  /api/gamification/leaderboard/   — Leaderboard (query: ?type=weekly)
    GET  /api/gamification/milestones/    — Milestone definitions
    POST /api/gamification/check-milestones/ — Evaluate & award milestones
    POST /api/gamification/seed/          — Seed milestone data (staff only)
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from .services import GamificationEngine
from .models import (
    XPEvent, StreakFreeze, Challenge, ChallengeParticipant,
    VirtualCurrency, CurrencyTransaction, DailyBonus, MilestoneReward,
)
from .serializers import (
    XPEventSerializer, WalletSerializer, CurrencyTransactionSerializer,
    StreakFreezeSerializer, ChallengeSerializer, ChallengeCreateSerializer,
    ChallengeParticipantSerializer, LeaderboardEntrySerializer,
    DailyBonusSerializer, MilestoneRewardSerializer,
)


class GamificationViewSet(viewsets.ViewSet):
    """
    Central gamification API endpoint.

    All endpoints require JWT authentication. The dashboard endpoint
    returns a composite payload suitable for rendering the full
    gamification UI in a single request.
    """
    permission_classes = [IsAuthenticated]

    # =================================================================
    # Dashboard — Composite Payload
    # =================================================================

    def list(self, request):
        """
        GET /api/gamification/

        Returns the full gamification dashboard: level, XP, coins,
        streaks, challenges, daily bonus status, and recent activity.
        """
        user = request.user
        data = GamificationEngine.get_gamification_dashboard(user)
        return Response({
            'success': True,
            **data,
        })

    # =================================================================
    # Daily Login Bonus
    # =================================================================

    @action(detail=False, methods=['post'], url_path='claim-login')
    def claim_login(self, request):
        """
        POST /api/gamification/claim-login/

        Claim the daily login bonus. Idempotent — returns already_claimed
        if called more than once per day.
        """
        result = GamificationEngine.claim_daily_login_bonus(request.user)
        return Response({
            'success': True,
            **result,
        })

    # =================================================================
    # Wallet & Transactions
    # =================================================================

    @action(detail=False, methods=['get'], url_path='wallet')
    def wallet(self, request):
        """
        GET /api/gamification/wallet/

        Returns wallet balance and recent coin transactions.
        """
        wallet, _ = VirtualCurrency.objects.get_or_create(user=request.user)
        transactions = CurrencyTransaction.objects.filter(
            user=request.user
        )[:20]

        return Response({
            'success': True,
            'wallet': WalletSerializer(wallet).data,
            'transactions': CurrencyTransactionSerializer(
                transactions, many=True
            ).data,
        })

    # =================================================================
    # XP History
    # =================================================================

    @action(detail=False, methods=['get'], url_path='xp-history')
    def xp_history(self, request):
        """
        GET /api/gamification/xp-history/?limit=20

        Paginated XP event history for the authenticated user.
        """
        limit = min(int(request.query_params.get('limit', 20)), 100)
        events = XPEvent.objects.filter(user=request.user)[:limit]

        return Response({
            'success': True,
            'events': XPEventSerializer(events, many=True).data,
        })

    # =================================================================
    # Streak Freezes
    # =================================================================

    @action(detail=False, methods=['post'], url_path='buy-freeze')
    def buy_freeze(self, request):
        """
        POST /api/gamification/buy-freeze/

        Purchase a streak freeze token using coins.
        """
        result = GamificationEngine.purchase_streak_freeze(request.user)
        success = 'error' not in result
        return Response(
            {'success': success, **result},
            status=status.HTTP_200_OK if success else status.HTTP_400_BAD_REQUEST,
        )

    @action(detail=False, methods=['get'], url_path='freezes')
    def freezes(self, request):
        """
        GET /api/gamification/freezes/

        List available streak freezes for the user.
        """
        data = GamificationEngine.get_user_freezes(request.user)
        return Response({
            'success': True,
            **data,
        })

    # =================================================================
    # Challenges
    # =================================================================

    @action(detail=False, methods=['get'], url_path='challenges')
    def challenges(self, request):
        """
        GET /api/gamification/challenges/

        List all challenges the user is participating in.
        """
        challenges = GamificationEngine.get_active_challenges(request.user)
        return Response({
            'success': True,
            'challenges': challenges,
        })

    @action(detail=False, methods=['post'], url_path='challenges/create')
    def create_challenge(self, request):
        """
        POST /api/gamification/challenges/create/

        Create a new challenge. The creator is automatically joined.
        """
        serializer = ChallengeCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        challenge = GamificationEngine.create_challenge(
            request.user,
            serializer.validated_data,
        )

        return Response({
            'success': True,
            'challenge': ChallengeSerializer(challenge).data,
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path=r'challenges/(?P<challenge_id>\d+)/join')
    def join_challenge(self, request, challenge_id=None):
        """
        POST /api/gamification/challenges/{id}/join/

        Join an existing challenge by ID or invite code.
        """
        try:
            challenge = Challenge.objects.get(id=challenge_id)
        except Challenge.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Challenge not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        result = GamificationEngine.join_challenge(request.user, challenge)
        success = 'error' not in result
        return Response(
            {'success': success, **result},
            status=status.HTTP_200_OK if success else status.HTTP_400_BAD_REQUEST,
        )

    @action(detail=False, methods=['post'], url_path=r'challenges/(?P<challenge_id>\d+)/mark-done')
    def mark_challenge_done(self, request, challenge_id=None):
        """POST /api/gamification/challenges/{id}/mark-done/"""
        habit_id = request.data.get('habitId')
        result = GamificationEngine.mark_challenge_done_today(
            request.user,
            int(challenge_id) if challenge_id is not None else 0,
            int(habit_id) if habit_id else None,
        )
        success = 'error' not in result
        return Response(
            {'success': success, **result},
            status=status.HTTP_200_OK if success else status.HTTP_400_BAD_REQUEST,
        )

    @action(detail=False, methods=['get'], url_path='community-challenges')
    def community_challenges(self, request):
        """
        GET /api/gamification/community-challenges/

        Browse available community challenges the user hasn't joined yet.
        """
        challenges = GamificationEngine.get_community_challenges(request.user)
        return Response({
            'success': True,
            'challenges': challenges,
        })

    # =================================================================
    # Leaderboard
    # =================================================================

    @action(detail=False, methods=['get'], url_path='leaderboard')
    def leaderboard(self, request):
        """
        GET /api/gamification/leaderboard/?type=weekly&limit=50

        Retrieve the leaderboard for a given period type.
        Auto-rebuilds if data is stale (>1 hour old or empty).
        """
        board_type = request.query_params.get('type', 'weekly')
        limit = min(int(request.query_params.get('limit', 50)), 100)

        # Auto-rebuild if leaderboard is empty or stale
        GamificationEngine.ensure_leaderboard_fresh(board_type)

        data = GamificationEngine.get_leaderboard(
            request.user,
            board_type=board_type,
            limit=limit,
        )
        return Response({
            'success': True,
            **data,
        })

    # =================================================================
    # Milestones
    # =================================================================

    @action(detail=False, methods=['get'], url_path='milestones')
    def milestones(self, request):
        """
        GET /api/gamification/milestones/

        List all milestone reward definitions.
        """
        milestones = MilestoneReward.objects.filter(is_active=True)
        return Response({
            'success': True,
            'milestones': MilestoneRewardSerializer(milestones, many=True).data,
        })

    @action(detail=False, methods=['post'], url_path='check-milestones')
    def check_milestones(self, request):
        """
        POST /api/gamification/check-milestones/

        Evaluate and award any earned milestones.
        """
        results = GamificationEngine.check_milestones(request.user)
        return Response({
            'success': True,
            'awarded': results,
            'count': len(results),
        })

    # =================================================================
    # Seeding (Staff Only)
    # =================================================================

    @action(detail=False, methods=['post'], url_path='seed',
            permission_classes=[IsAdminUser])
    def seed(self, request):
        """
        POST /api/gamification/seed/

        Seed milestone definitions. Staff only.
        """
        count = GamificationEngine.seed_milestones()
        return Response({
            'success': True,
            'milestonesCreated': count,
        })
