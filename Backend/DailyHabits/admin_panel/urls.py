"""
admin_panel/urls.py — Admin API URL Configuration
===================================================
All endpoints are prefixed with ``/api/admin/`` (configured in project urls.py).
"""

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = 'admin_panel'

router = DefaultRouter()

# RBAC
router.register(r'roles', views.AdminRoleViewSet, basename='admin-roles')
router.register(r'profiles', views.AdminProfileViewSet, basename='admin-profiles')

# User Management
router.register(r'users', views.AdminUserViewSet, basename='admin-users')

# Reports & Moderation
router.register(r'reports', views.ReportViewSet, basename='admin-reports')
router.register(r'moderation', views.ContentModerationViewSet, basename='admin-moderation')
router.register(r'warnings', views.UserWarningViewSet, basename='admin-warnings')

# System Settings
router.register(r'settings', views.SystemSettingsViewSet, basename='admin-settings')
router.register(r'feature-flags', views.FeatureFlagViewSet, basename='admin-feature-flags')

# Notification Management
router.register(r'notification-templates', views.NotificationTemplateViewSet, basename='admin-notification-templates')
router.register(r'campaigns', views.NotificationCampaignViewSet, basename='admin-campaigns')

# Gamification
router.register(r'achievements', views.AdminAchievementViewSet, basename='admin-achievements')
router.register(r'challenges', views.AdminChallengeViewSet, basename='admin-challenges')
router.register(r'milestone-rewards', views.AdminMilestoneRewardViewSet, basename='admin-milestone-rewards')
router.register(r'leaderboard', views.AdminLeaderboardViewSet, basename='admin-leaderboard')

# Audit Logs
router.register(r'audit-logs', views.AuditLogViewSet, basename='admin-audit-logs')

# AI Safety
router.register(r'ai-safety', views.AISafetyLogViewSet, basename='admin-ai-safety')
router.register(r'ai-restrictions', views.AIUserRestrictionViewSet, basename='admin-ai-restrictions')

# Analytics Snapshots
router.register(r'analytics/snapshots', views.AnalyticsSnapshotViewSet, basename='admin-analytics-snapshots')

urlpatterns = [
    # Admin profile (self)
    path('me/', views.AdminMeView.as_view(), name='admin-me'),

    # Analytics endpoints (non-CRUD)
    path('analytics/overview/', views.OverviewStatsView.as_view(), name='admin-analytics-overview'),
    path('analytics/growth/', views.GrowthTrendsView.as_view(), name='admin-analytics-growth'),
    path('analytics/engagement/', views.EngagementMetricsView.as_view(), name='admin-analytics-engagement'),
    path('analytics/retention/', views.RetentionMetricsView.as_view(), name='admin-analytics-retention'),
    path('analytics/comprehensive/', views.ComprehensiveAnalyticsView.as_view(), name='admin-analytics-comprehensive'),
    path('analytics/export/', views.AnalyticsExportView.as_view(), name='admin-analytics-export'),

    # Router-registered endpoints
    path('', include(router.urls)),
]
