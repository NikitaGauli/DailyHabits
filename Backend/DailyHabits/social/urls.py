"""
Social App \u2014 URL Configuration
===============================

Registers all social-feature ``ViewSet`` routes using DRF's
``DefaultRouter``.  The router auto-generates standard list / detail
routes as well as custom ``@action`` routes for each ViewSet.

Included route groups:
    ``share-cards/``   \u2013 Share-card listing and generation.
    ``privacy/``       \u2013 Per-habit sharing privacy CRUD.
    ``referrals/``     \u2013 Referral link and stats.
    ``groups/``        \u2013 Group habits (CRUD, join, leave, leaderboard, discover).

These URLs are mounted under ``/api/social/`` by the project-level
``api_router`` (see ``DailyHabits.api_router``).
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ShareCardViewSet, PrivacyViewSet, ReferralViewSet, GroupHabitViewSet

# \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
# DRF Router \u2014 auto-generates URLs for each registered ViewSet
# \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
router = DefaultRouter()
router.register(r'share-cards', ShareCardViewSet, basename='share-cards')
router.register(r'privacy', PrivacyViewSet, basename='privacy')
router.register(r'referrals', ReferralViewSet, basename='referrals')
router.register(r'groups', GroupHabitViewSet, basename='groups')

urlpatterns = [
    path('', include(router.urls)),  # Mount all router-generated URLs
]
