"""
Insights URL Configuration — DailyHabits Application
====================================================

Registers the ``InsightViewSet`` with a DRF ``DefaultRouter`` under an
empty prefix so that all insight endpoints are accessible directly
beneath the ``/api/insights/`` namespace defined in the project’s root
URL configuration (see ``DailyHabits.api_router``).

Generated routes (all require authentication):
    - GET  /api/insights/daily/
    - GET  /api/insights/quote/
    - GET  /api/insights/best-time/
    - GET  /api/insights/top-habits/
    - GET  /api/insights/declining-habits/
    - GET  /api/insights/recommendations/
    - GET  /api/insights/summary/
    - POST /api/insights/seed-quotes/   (staff only)
"""

# ===========================================================================
# Imports
# ===========================================================================

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import InsightViewSet

# ===========================================================================
# Router registration
# ===========================================================================

router = DefaultRouter()
router.register(r'', InsightViewSet, basename='insights')  # Empty prefix—mounts at root

# ===========================================================================
# URL patterns
# ===========================================================================

urlpatterns = [
    path('', include(router.urls)),
]
