"""
Achievement Views
API endpoints for achievements, badges, and levels
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .services import AchievementService
from .models import Achievement, UserAchievement


class AchievementViewSet(viewsets.ViewSet):
    """
    ViewSet for achievement endpoints
    """
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        """
        GET /api/achievements/
        List all achievements with user's earned status
        """
        achievements = AchievementService.get_user_achievements(request.user)
        
        # Group by type
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
    
    @action(detail=False, methods=['get'])
    def level(self, request):
        """
        GET /api/achievements/level/
        Get user's current level and XP
        """
        level_info = AchievementService.get_user_level(request.user)
        
        return Response({
            'success': True,
            **level_info
        })
    
    @action(detail=False, methods=['get'])
    def recent(self, request):
        """
        GET /api/achievements/recent/
        Get recently earned achievements
        """
        limit = int(request.query_params.get('limit', 5))
        limit = min(limit, 20)  # Cap at 20
        
        recent = AchievementService.get_recent_achievements(request.user, limit)
        
        return Response({
            'success': True,
            'achievements': recent
        })
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/achievements/summary/
        Get achievement summary with level info
        """
        user = request.user
        
        achievements = AchievementService.get_user_achievements(user)
        level_info = AchievementService.get_user_level(user)
        recent = AchievementService.get_recent_achievements(user, 3)
        
        # Stats by rarity
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
    
    @action(detail=False, methods=['post'])
    def check(self, request):
        """
        POST /api/achievements/check/
        Manually trigger achievement check
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
    
    @action(detail=False, methods=['post'])
    def seed(self, request):
        """
        POST /api/achievements/seed/
        Seed default achievements (admin only)
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
