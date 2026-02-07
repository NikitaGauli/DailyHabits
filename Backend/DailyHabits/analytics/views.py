"""
Analytics Views
API endpoints for analytics and statistics
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from datetime import datetime

from .services import AnalyticsService


class AnalyticsViewSet(viewsets.ViewSet):
    """
    ViewSet for analytics endpoints
    """
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def dashboard(self, request):
        """
        GET /api/analytics/dashboard/
        Main dashboard analytics with summary stats
        """
        user = request.user
        
        summary = AnalyticsService.get_dashboard_summary(user)
        weekly_data = AnalyticsService.get_weekly_data(user)
        
        return Response({
            'success': True,
            'data': {
                **summary,
                'weeklyData': weekly_data,
            }
        })
    
    @action(detail=False, methods=['get'])
    def weekly(self, request):
        """
        GET /api/analytics/weekly/
        Weekly progress data for charts
        """
        weeks_back = int(request.query_params.get('weeksBack', 0))
        data = AnalyticsService.get_weekly_data(request.user, weeks_back)
        
        return Response({
            'success': True,
            'data': data
        })
    
    @action(detail=False, methods=['get'])
    def monthly(self, request):
        """
        GET /api/analytics/monthly/
        Monthly heatmap data for calendar view
        """
        year = int(request.query_params.get('year', datetime.now().year))
        month = int(request.query_params.get('month', datetime.now().month))
        
        heatmap = AnalyticsService.get_monthly_heatmap(request.user, year, month)
        
        return Response({
            'success': True,
            'year': year,
            'month': month,
            'heatmap': heatmap
        })
    
    @action(detail=False, methods=['get'], url_path='habit-stats')
    def habit_stats(self, request):
        """
        GET /api/analytics/habit-stats/
        Per-habit statistics
        """
        stats = AnalyticsService.get_habit_stats(request.user)
        
        return Response({
            'success': True,
            'habitStats': stats
        })
    
    @action(detail=False, methods=['get'], url_path='category-breakdown')
    def category_breakdown(self, request):
        """
        GET /api/analytics/category-breakdown/
        Breakdown by category
        """
        breakdown = AnalyticsService.get_category_breakdown(request.user)
        
        return Response({
            'success': True,
            'categories': breakdown
        })
    
    @action(detail=False, methods=['get'])
    def trend(self, request):
        """
        GET /api/analytics/trend/
        Completion trend over time
        """
        days = int(request.query_params.get('days', 30))
        days = min(days, 90)  # Limit to 90 days
        
        trend = AnalyticsService.get_completion_trend(request.user, days)
        
        return Response({
            'success': True,
            'days': days,
            'trend': trend
        })
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/analytics/summary/
        Complete analytics summary for reports
        """
        user = request.user
        
        return Response({
            'success': True,
            'dashboard': AnalyticsService.get_dashboard_summary(user),
            'habitStats': AnalyticsService.get_habit_stats(user),
            'categories': AnalyticsService.get_category_breakdown(user),
            'weeklyData': AnalyticsService.get_weekly_data(user),
            'trend': AnalyticsService.get_completion_trend(user, 30),
        })

    # ─── ENHANCED ANALYTICS ENDPOINTS ──────────────────────────────────

    @action(detail=False, methods=['get'], url_path='weekly-comparison')
    def weekly_comparison(self, request):
        """
        GET /api/analytics/weekly-comparison/
        This week vs last week comparison
        """
        comparison = AnalyticsService.get_weekly_comparison(request.user)
        return Response({'success': True, **comparison})

    @action(detail=False, methods=['get'], url_path='difficulty-scores')
    def difficulty_scores(self, request):
        """
        GET /api/analytics/difficulty-scores/
        Habit difficulty scoring based on completion rates
        """
        scores = AnalyticsService.get_difficulty_scores(request.user)
        return Response({'success': True, 'habits': scores})

    @action(detail=False, methods=['get'], url_path='long-term-trends')
    def long_term_trends(self, request):
        """
        GET /api/analytics/long-term-trends/
        Long-term monthly consistency trends
        """
        months = min(int(request.query_params.get('months', 6)), 12)
        trends = AnalyticsService.get_long_term_trends(request.user, months)
        return Response({'success': True, 'trends': trends})

    @action(detail=False, methods=['get'], url_path='category-success')
    def category_success(self, request):
        """
        GET /api/analytics/category-success/
        Category-wise success ratio
        """
        ratios = AnalyticsService.get_category_success_ratio(request.user)
        return Response({'success': True, 'categories': ratios})

    @action(detail=False, methods=['get'], url_path='productivity-heatmap')
    def productivity_heatmap(self, request):
        """
        GET /api/analytics/productivity-heatmap/
        Year-level productivity heatmap
        """
        from datetime import datetime
        year = int(request.query_params.get('year', datetime.now().year))
        heatmap = AnalyticsService.get_productivity_heatmap(request.user, year)
        return Response({'success': True, 'year': year, 'heatmap': heatmap})
