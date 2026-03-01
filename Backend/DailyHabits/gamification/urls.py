"""
Gamification URL Configuration
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import GamificationViewSet

router = DefaultRouter()
router.register(r'', GamificationViewSet, basename='gamification')

urlpatterns = [
    path('', include(router.urls)),
]
