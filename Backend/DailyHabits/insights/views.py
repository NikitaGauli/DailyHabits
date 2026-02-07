"""
Insights Views
API endpoints for insights and motivational content
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .services import InsightService


class InsightViewSet(viewsets.ViewSet):
    """
    ViewSet for insight endpoints
    """
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def daily(self, request):
        """
        GET /api/insights/daily/
        Get daily personalized insights
        """
        insights = InsightService.get_daily_insights(request.user)
        quote = InsightService.get_daily_quote(request.user)
        comeback = InsightService.get_comeback_message(request.user)
        
        return Response({
            'success': True,
            'insights': insights,
            'quote': quote,
            'comeback': comeback,
        })
    
    @action(detail=False, methods=['get'])
    def quote(self, request):
        """
        GET /api/insights/quote/
        Get a motivational quote
        """
        category = request.query_params.get('category', 'general')
        quote = InsightService.get_daily_quote(request.user, category)
        
        return Response({
            'success': True,
            **quote
        })
    
    @action(detail=False, methods=['get'], url_path='best-time')
    def best_time(self, request):
        """
        GET /api/insights/best-time/
        Get user's best performance time
        """
        data = InsightService.get_best_performance_time(request.user)
        
        return Response({
            'success': True,
            **data
        })
    
    @action(detail=False, methods=['get'], url_path='top-habits')
    def top_habits(self, request):
        """
        GET /api/insights/top-habits/
        Get most consistent habits
        """
        limit = int(request.query_params.get('limit', 3))
        limit = min(limit, 10)
        
        habits = InsightService.get_most_consistent_habits(request.user, limit)
        
        return Response({
            'success': True,
            'habits': habits
        })
    
    @action(detail=False, methods=['get'], url_path='declining-habits')
    def declining_habits(self, request):
        """
        GET /api/insights/declining-habits/
        Get habits needing attention
        """
        limit = int(request.query_params.get('limit', 3))
        
        habits = InsightService.get_declining_habits(request.user, limit)
        
        return Response({
            'success': True,
            'habits': habits,
            'hasDeclines': len(habits) > 0,
        })
    
    @action(detail=False, methods=['get'])
    def recommendations(self, request):
        """
        GET /api/insights/recommendations/
        Get personalized recommendations
        """
        recommendations = InsightService.get_recommendations(request.user)
        
        return Response({
            'success': True,
            'recommendations': recommendations
        })
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/insights/summary/
        Complete insights summary
        """
        user = request.user
        
        return Response({
            'success': True,
            'insights': InsightService.get_daily_insights(user),
            'quote': InsightService.get_daily_quote(user),
            'bestTime': InsightService.get_best_performance_time(user),
            'topHabits': InsightService.get_most_consistent_habits(user, 3),
            'decliningHabits': InsightService.get_declining_habits(user, 3),
            'recommendations': InsightService.get_recommendations(user),
            'comeback': InsightService.get_comeback_message(user),
        })
    
    @action(detail=False, methods=['post'], url_path='seed-quotes')
    def seed_quotes(self, request):
        """
        POST /api/insights/seed-quotes/
        Seed motivational quotes (admin only)
        """
        if not request.user.is_staff:
            return Response({
                'success': False,
                'message': 'Admin access required'
            }, status=status.HTTP_403_FORBIDDEN)
        
        count = InsightService.seed_quotes()
        
        return Response({
            'success': True,
            'message': f'Created {count} new quotes',
            'createdCount': count
        })
