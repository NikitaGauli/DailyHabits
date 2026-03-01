"""
Analytics URL Configuration — analytics/urls.py

Maps all analytics API routes using a DRF DefaultRouter. The router is
registered with an empty prefix so that the parent ``api_router`` can mount
this module at ``/api/analytics/``.

Generated routes (via ViewSet actions):
    GET  /api/analytics/dashboard/
    GET  /api/analytics/weekly/
    GET  /api/analytics/monthly/
    GET  /api/analytics/habit-stats/
    GET  /api/analytics/category-breakdown/
    GET  /api/analytics/trend/
    GET  /api/analytics/summary/
    GET  /api/analytics/weekly-comparison/
    GET  /api/analytics/difficulty-scores/
    GET  /api/analytics/long-term-trends/
    GET  /api/analytics/category-success/
    GET  /api/analytics/productivity-heatmap/
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AnalyticsViewSet

# =============================================================================
# Router Configuration
# =============================================================================

# DefaultRouter provides automatic URL routing and an API root view.
router = DefaultRouter()
router.register(r'', AnalyticsViewSet, basename='analytics')

# ── URL Patterns ─────────────────────────────────────────────────────────────
urlpatterns = [
    path('', include(router.urls)),  # Delegate all routing to the DRF router
]
