"""
Achievements URL Configuration
================================
Maps URL patterns to the ``AchievementViewSet`` via a DRF router.

The router auto-generates the standard REST endpoints as well as
custom ``@action`` routes defined on the ViewSet (e.g. ``/level/``,
``/recent/``, ``/summary/``, ``/check/``, ``/seed/``).

Included in the project-level URL conf under ``/api/achievements/``.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AchievementViewSet

# =============================================================================
# Router Registration
# =============================================================================

# DefaultRouter provides a browsable API root and handles trailing slashes.
router = DefaultRouter()
router.register(r'', AchievementViewSet, basename='achievements')

# -- URL patterns exposed by this app -----------------------------------------
urlpatterns = [
    path('', include(router.urls)),
]
