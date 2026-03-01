"""
Notification URL Configuration
==============================
Registers all notification-related ViewSets with a DRF ``DefaultRouter``
and exposes them under a flat URL namespace.

Route Overview
--------------
=================================  ========================================
Prefix                             ViewSet
=================================  ========================================
``/notifications/``                :class:`~notifications.views.NotificationViewSet`
``/notification-settings/``        :class:`~notifications.views.NotificationSettingsViewSet`
``/habit-reminders/``              :class:`~notifications.views.HabitReminderViewSet`
``/notification-intelligence/``    :class:`~notifications.views.NotificationIntelligenceViewSet`
``/smart-tips/``                   :class:`~notifications.views.SmartTipViewSet`
=================================  ========================================

This module is included by the project-level ``api_router`` under the
``/api/`` prefix, so full paths look like ``/api/notifications/``, etc.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    NotificationViewSet, 
    NotificationSettingsViewSet,
    HabitReminderViewSet,
    NotificationIntelligenceViewSet,
    SmartTipViewSet,
)

# ---------------------------------------------------------------------------
#  Router registration
# ---------------------------------------------------------------------------

router = DefaultRouter()
router.register(r'notifications', NotificationViewSet, basename='notifications')
router.register(r'notification-settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'habit-reminders', HabitReminderViewSet, basename='habit-reminders')
router.register(r'notification-intelligence', NotificationIntelligenceViewSet, basename='notification-intelligence')
router.register(r'smart-tips', SmartTipViewSet, basename='smart-tips')

# ---------------------------------------------------------------------------
#  URL patterns — all routes served under the router-generated prefix
# ---------------------------------------------------------------------------

urlpatterns = [
    path('', include(router.urls)),
]
