"""
Achievements Views
===================
Django REST Framework ViewSet exposing the achievements API.

This module provides the HTTP layer for the gamification subsystem,
delegating all business logic to ``AchievementService``.  All endpoints
require authentication and return JSON payloads consumed by the
Flutter front-end.

Endpoints (all under ``/api/achievements/``):
    GET  /                  — List all achievements with earned status.
    GET  /level/            — Current user level and XP details.
    GET  /recent/           — Most recently earned achievements.
    GET  /summary/          — Combined level + stats + recent achievements.
    POST /check/            — Manually trigger an achievement evaluation.
    POST /seed/             — Seed default achievements (staff only).
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .services import AchievementService
from .models import Achievement, UserAchievement


# =============================================================================
# Achievement ViewSet
# =============================================================================


class AchievementViewSet(viewsets.ViewSet):
    """
    ViewSet for achievement-related API endpoints.

    Uses a plain ``ViewSet`` (not ``ModelViewSet``) because responses
    are assembled by the service layer rather than simple CRUD on a
    single model.
    """
    permission_classes = [IsAuthenticated]

    # -----------------------------------------------------------------
    # List all achievements
    # -----------------------------------------------------------------

    def list(self, request):
        """
        GET /api/achievements/

        Return every active achievement annotated with the authenticated
        user’s earned status, grouped by achievement type.
        """
        achievements = AchievementService.get_user_achievements(request.user)

        # Group achievements by type for sectioned UI display
        grouped = {}
        for achievement in achievements:
            type_key = achievement['type']
            if type_key not in grouped:
                grouped[type_key] = []
            grouped[type_key].append(achievement)

        return Response({
            'success': True,
            'achievements': achievements,
            'grouped': grouped,
            'totalCount': len(achievements),
            'earnedCount': sum(1 for a in achievements if a['isEarned']),
        })

    # -----------------------------------------------------------------
    # User level & XP
    # -----------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def level(self, request):
        """
        GET /api/achievements/level/

        Return the authenticated user’s current level, XP balance,
        and progress percentage toward the next level.
        """
        level_info = AchievementService.get_user_level(request.user)
        
        return Response({
            'success': True,
            **level_info
        })

    # -----------------------------------------------------------------
    # Recently earned achievements
    # -----------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def recent(self, request):
        """
        GET /api/achievements/recent/?limit=5

        Return the most recently earned achievements for the user.
        Accepts an optional ``limit`` query parameter (max 20).
        """
        limit = int(request.query_params.get('limit', 5))
        limit = min(limit, 20)  # Cap at 20 to prevent excessive payloads

        recent = AchievementService.get_recent_achievements(request.user, limit)

        return Response({
            'success': True,
            'achievements': recent
        })

    # -----------------------------------------------------------------
    # Achievement summary (dashboard widget)
    # -----------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/achievements/summary/

        Composite endpoint returning level info, aggregate stats broken
        down by rarity tier, and the three most recent achievements.
        Designed for the dashboard summary card.
        """
        user = request.user

        # Fetch all data needed for the summary composite payload
        achievements = AchievementService.get_user_achievements(user)
        level_info = AchievementService.get_user_level(user)
        recent = AchievementService.get_recent_achievements(user, 3)

        # Compute per-rarity earned/total breakdown
        rarity_stats = {}
        for a in achievements:
            rarity = a['rarity']
            if rarity not in rarity_stats:
                rarity_stats[rarity] = {'total': 0, 'earned': 0}
            rarity_stats[rarity]['total'] += 1
            if a['isEarned']:
                rarity_stats[rarity]['earned'] += 1

        return Response({
            'success': True,
            'level': level_info,
            'stats': {
                'total': len(achievements),
                'earned': sum(1 for a in achievements if a['isEarned']),
                'byRarity': rarity_stats,
            },
            'recentAchievements': recent,
        })

    # -----------------------------------------------------------------
    # Manual achievement check
    # -----------------------------------------------------------------

    @action(detail=False, methods=['post'])
    def check(self, request):
        """
        POST /api/achievements/check/

        Manually trigger an achievement evaluation for the authenticated
        user.  Returns any newly earned achievements.  Useful for
        catch-up checks or front-end refresh flows.
        """
        newly_earned = AchievementService.check_and_award_achievements(request.user)
        
        return Response({
            'success': True,
            'newlyEarned': [{
                'id': ua.achievement.id,
                'name': ua.achievement.name,
                'description': ua.achievement.description,
                'rarity': ua.achievement.rarity,
                'points': ua.achievement.points,
                'iconCode': ua.achievement.icon_code,
                'colorValue': ua.achievement.color_value,
            } for ua in newly_earned],
            'count': len(newly_earned),
        })

    # -----------------------------------------------------------------
    # Seed default achievements (admin only)
    # -----------------------------------------------------------------

    @action(detail=False, methods=['post'])
    def seed(self, request):
        """
        POST /api/achievements/seed/

        Populate the ``Achievement`` table with the default set of
        badge definitions.  Restricted to staff users.  Idempotent —
        existing achievements are not duplicated.
        """
        if not request.user.is_staff:
            return Response({
                'success': False,
                'message': 'Admin access required'
            }, status=status.HTTP_403_FORBIDDEN)
        
        count = AchievementService.seed_achievements()
        
        return Response({
            'success': True,
            'message': f'Created {count} new achievements',
            'createdCount': count
        })
