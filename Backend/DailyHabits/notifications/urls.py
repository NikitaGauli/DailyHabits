"""
Notifications URL Configuration
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationViewSet, 
    NotificationSettingsViewSet,
    HabitReminderViewSet,
    NotificationIntelligenceViewSet,
)

router = DefaultRouter()
router.register(r'notifications', NotificationViewSet, basename='notifications')
router.register(r'notification-settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'habit-reminders', HabitReminderViewSet, basename='habit-reminders')
router.register(r'notification-intelligence', NotificationIntelligenceViewSet, basename='notification-intelligence')

urlpatterns = [
    path('', include(router.urls)),
]
