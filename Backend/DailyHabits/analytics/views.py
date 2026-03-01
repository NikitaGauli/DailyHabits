"""
Analytics Views — analytics/views.py

Defines the REST API endpoints for the Analytics app. All endpoints require
authentication and delegate computation to ``AnalyticsService``, keeping the
view layer thin and focused on request parsing and response formatting.

Endpoints (all under ``/api/analytics/``):
    GET  dashboard/           – Main dashboard summary + weekly chart data.
    GET  weekly/              – Weekly bar-chart payload (supports weeksBack).
    GET  monthly/             – Monthly calendar heatmap (year & month params).
    GET  habit-stats/         – Per-habit statistics table.
    GET  category-breakdown/  – Category-level consistency breakdown.
    GET  trend/               – Daily completion trend line (configurable days).
    GET  summary/             – Full analytics bundle for export / reports.
    GET  weekly-comparison/   – This-week vs last-week comparison.
    GET  difficulty-scores/   – Habit difficulty scoring.
    GET  long-term-trends/    – Monthly consistency over N months.
    GET  category-success/    – Category-wise success ratios.
    GET  productivity-heatmap/– Year-level contribution-style heatmap.
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from datetime import datetime

from .services import AnalyticsService


# =============================================================================
# Analytics ViewSet
# =============================================================================

class AnalyticsViewSet(viewsets.ViewSet):
    """
    ViewSet providing read-only analytics endpoints.

    Uses ``ViewSet`` (not ``ModelViewSet``) because all data is computed
    on-the-fly by ``AnalyticsService`` rather than served from a single
    model's queryset. Every action returns a JSON envelope with a
    ``success`` boolean at the top level.
    """
    permission_classes = [IsAuthenticated]  # All endpoints require login
    
    # =================================================================
    # Core Dashboard Endpoints
    # =================================================================

    @action(detail=False, methods=['get'])
    def dashboard(self, request):
        """
        GET /api/analytics/dashboard/

        Returns the main dashboard payload: high-level summary stats
        (today's completion, streaks, consistency) combined with this
        week's daily breakdown for the bar chart.
        """
        user = request.user

        # Fetch summary stats and weekly chart data in parallel-ready calls
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
        GET /api/analytics/weekly/?weeksBack=0

        Returns a 7-element list of daily completion data for the requested
        week. ``weeksBack=0`` (default) is the current week; ``1`` is last
        week, and so on.
        """
        weeks_back = int(request.query_params.get('weeksBack', 0))  # 0 = this week
        data = AnalyticsService.get_weekly_data(request.user, weeks_back)
        
        return Response({
            'success': True,
            'data': data
        })
    
    @action(detail=False, methods=['get'])
    def monthly(self, request):
        """
        GET /api/analytics/monthly/?year=2026&month=2

        Returns a calendar-heatmap payload with one entry per day of the
        requested month. Defaults to the current year and month when
        query parameters are omitted.
        """
        # Default to the current year/month if not specified
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

        Returns per-habit statistics (streaks, consistency, success rate)
        sorted by 30-day consistency descending.
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

        Groups the user's habits by category and returns the average
        30-day consistency for each group.
        """
        breakdown = AnalyticsService.get_category_breakdown(request.user)
        
        return Response({
            'success': True,
            'categories': breakdown
        })
    
    @action(detail=False, methods=['get'])
    def trend(self, request):
        """
        GET /api/analytics/trend/?days=30

        Returns a daily completion trend array for charting. The ``days``
        parameter controls how many past days to include (capped at 90).
        """
        days = int(request.query_params.get('days', 30))
        days = min(days, 90)  # Cap at 90 days to limit query cost
        
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

        Returns a comprehensive analytics bundle combining dashboard stats,
        per-habit stats, category breakdown, weekly chart data, and a
        30-day trend. Intended for report generation and data export.
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

    # =================================================================
    # Enhanced Analytics Endpoints
    # =================================================================

    @action(detail=False, methods=['get'], url_path='weekly-comparison')
    def weekly_comparison(self, request):
        """
        GET /api/analytics/weekly-comparison/

        Compares this week's performance against last week, returning
        daily averages, percentage change, and a trend label.
        """
        comparison = AnalyticsService.get_weekly_comparison(request.user)
        return Response({'success': True, **comparison})

    @action(detail=False, methods=['get'], url_path='difficulty-scores')
    def difficulty_scores(self, request):
        """
        GET /api/analytics/difficulty-scores/

        Scores each habit's difficulty (1–5) based on recent completion
        rates. A low completion rate indicates a harder habit.
        """
        scores = AnalyticsService.get_difficulty_scores(request.user)
        return Response({'success': True, 'habits': scores})

    @action(detail=False, methods=['get'], url_path='long-term-trends')
    def long_term_trends(self, request):
        """
        GET /api/analytics/long-term-trends/?months=6

        Returns monthly completion rates over the last N months
        (capped at 12) for a long-term trend chart.
        """
        months = min(int(request.query_params.get('months', 6)), 12)  # Cap at 12
        trends = AnalyticsService.get_long_term_trends(request.user, months)
        return Response({'success': True, 'trends': trends})

    @action(detail=False, methods=['get'], url_path='category-success')
    def category_success(self, request):
        """
        GET /api/analytics/category-success/

        Returns the success ratio (completed / total logs) for every
        habit category, sorted highest first.
        """
        ratios = AnalyticsService.get_category_success_ratio(request.user)
        return Response({'success': True, 'categories': ratios})

    @action(detail=False, methods=['get'], url_path='productivity-heatmap')
    def productivity_heatmap(self, request):
        """
        GET /api/analytics/productivity-heatmap/?year=2026

        Generates a GitHub-contribution-style heatmap for the requested
        year, with one intensity value (0.0–1.0) per calendar day.
        """
        from datetime import datetime
        year = int(request.query_params.get('year', datetime.now().year))
        heatmap = AnalyticsService.get_productivity_heatmap(request.user, year)
        return Response({'success': True, 'year': year, 'heatmap': heatmap})
