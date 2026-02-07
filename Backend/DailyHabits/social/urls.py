"""
Social Sharing URL Configuration
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ShareCardViewSet, PrivacyViewSet, ReferralViewSet, GroupHabitViewSet

router = DefaultRouter()
router.register(r'share-cards', ShareCardViewSet, basename='share-cards')
router.register(r'privacy', PrivacyViewSet, basename='privacy')
router.register(r'referrals', ReferralViewSet, basename='referrals')
router.register(r'groups', GroupHabitViewSet, basename='groups')

urlpatterns = [
    path('', include(router.urls)),
]
