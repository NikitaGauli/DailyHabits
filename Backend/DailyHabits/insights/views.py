"""
Insights Views — DailyHabits Application
=======================================

REST API endpoints for the smart-insights engine.  All endpoints live
under ``/api/insights/`` and require JWT authentication.

Endpoints provided by ``InsightViewSet``:

+---------------------+--------+-------------------------------------------+
| URL path            | Method | Description                               |
+=====================+========+===========================================+
| ``daily/``          | GET    | Full daily insights feed for the user.    |
| ``quote/``          | GET    | Single motivational quote (opt. category).|
| ``best-time/``      | GET    | Peak performance time-of-day analysis.    |
| ``top-habits/``     | GET    | Most consistent habits (opt. limit).      |
| ``declining-habits/``| GET   | Habits with week-over-week decline.       |
| ``recommendations/``| GET    | Personalised actionable recommendations.  |
| ``summary/``        | GET    | Combined payload of all insight types.    |
| ``seed-quotes/``    | POST   | Seed default quotes (staff only).         |
+---------------------+--------+-------------------------------------------+
"""

# ===========================================================================
# Imports
# ===========================================================================

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .services import InsightService


# ===========================================================================
# ViewSet: InsightViewSet
# ===========================================================================


class InsightViewSet(viewsets.ViewSet):
    """
    DRF ViewSet exposing the smart-insights engine via REST.

    Uses ``ViewSet`` (not ``ModelViewSet``) because the insight data is
    computed on the fly by ``InsightService`` rather than mapped 1-to-1
    to a single model.  Each ``@action`` delegates to the corresponding
    service method and wraps the result in a standard response envelope.

    Authentication:
        All endpoints require a valid JWT token
        (``IsAuthenticated`` permission).
    """
    permission_classes = [IsAuthenticated]
    
    # ------------------------------------------------------------------
    # Aggregated daily insights
    # ------------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def daily(self, request):
        """
        GET /api/insights/daily/

        Return the full personalised daily feed: insight cards,
        motivational quote, and comeback message (when applicable).
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

    # ------------------------------------------------------------------
    # Individual insight endpoints
    # ------------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def quote(self, request):
        """
        GET /api/insights/quote/?category=<cat>

        Return a single motivational quote.  Accepts an optional
        ``category`` query parameter (default ``'general'``).
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

        Return the time-of-day slot in which the authenticated user
        completes the most habits.
        """
        data = InsightService.get_best_performance_time(request.user)
        
        return Response({
            'success': True,
            **data
        })
    
    @action(detail=False, methods=['get'], url_path='top-habits')
    def top_habits(self, request):
        """
        GET /api/insights/top-habits/?limit=<n>

        Return the user's most consistent habits ranked by 30-day
        completion rate.  ``limit`` defaults to 3, capped at 10.
        """
        limit = int(request.query_params.get('limit', 3))
        limit = min(limit, 10)  # Hard cap to prevent unbounded queries

        habits = InsightService.get_most_consistent_habits(request.user, limit)
        
        return Response({
            'success': True,
            'habits': habits
        })
    
    @action(detail=False, methods=['get'], url_path='declining-habits')
    def declining_habits(self, request):
        """
        GET /api/insights/declining-habits/?limit=<n>

        Return habits whose week-over-week completion rate is dropping.
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

        Return personalised, actionable recommendations (e.g. enable
        reminders, simplify low-consistency habits).
        """
        recommendations = InsightService.get_recommendations(request.user)
        
        return Response({
            'success': True,
            'recommendations': recommendations
        })
    
    # ------------------------------------------------------------------
    # Full summary endpoint
    # ------------------------------------------------------------------

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/insights/summary/

        Single-request endpoint that aggregates every insight type into
        one response.  Ideal for the Flutter dashboard's initial load.
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
    
    # ------------------------------------------------------------------
    # Admin-only actions
    # ------------------------------------------------------------------

    @action(detail=False, methods=['post'], url_path='seed-quotes')
    def seed_quotes(self, request):
        """
        POST /api/insights/seed-quotes/

        Populate the ``MotivationalQuote`` table with the default set of
        quotes.  Restricted to staff users; returns 403 otherwise.
        """
        # Guard: only staff/admin users may seed quotes
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
