"""
Centralised API Router — DailyHabits Project
=============================================

Registers every DRF ``ViewSet`` under a single ``DefaultRouter`` instance that
is then included in the project-level URL configuration (``urls.py``).

Using one router keeps URL generation consistent, enables the DRF browsable
API root, and provides a single place to audit every public API endpoint.

Endpoint groups:
    - **Core**:          habits, habit-logs, analytics, achievements, insights
    - **Notifications**: notifications, smart-tips, reminders, intelligence
    - **Social**:        share-cards, privacy, referrals, groups, feed, friends
    - **Settings**:      user-settings, device-tokens, exports, FAQ, support

See Also:
    - DRF Routers: https://www.django-rest-framework.org/api-guide/routers/
"""

from rest_framework.routers import DefaultRouter

# --- Core domain ViewSets ---
from habits.views import HabitViewSet, HabitLogViewSet
from analytics.views import AnalyticsViewSet
from achievements.views import AchievementViewSet
from insights.views import InsightViewSet

# --- Notification ViewSets ---
from notifications.views import (
    NotificationViewSet,
    SmartTipViewSet,
    NotificationSettingsViewSet,
    HabitReminderViewSet,
    NotificationIntelligenceViewSet,
)

# --- Social feature ViewSets ---
from social.views import (
    ShareCardViewSet,
    PrivacyViewSet,
    ReferralViewSet,
    GroupHabitViewSet,
    FeedViewSet,
    FriendViewSet,
    JoinedDashboardViewSet,
    SharedHabitViewSet,
    EncouragementViewSet,
    ActivityFeedViewSet,
)

# --- Gamification ViewSets ---
from gamification.views import GamificationViewSet

# --- Grow Together ViewSets ---
from grow_together.views import GrowTogetherViewSet

# --- Settings & support ViewSets ---
from settings_app.views import (
    UserSettingsViewSet,
    PrivacySettingsViewSet,
    SecuritySettingsViewSet,
    LoginSessionViewSet,
    SettingsAuditLogViewSet,
    ExportViewSet,
    PrivacyPolicyViewSet,
    FAQViewSet,
    SupportTicketViewSet,
)

# =============================================================================
# ROUTER INITIALISATION
# =============================================================================
# DefaultRouter auto-generates an API root view that lists all registered
# endpoints, which is helpful during development and for API discovery.
router = DefaultRouter()

# =============================================================================
# CORE DOMAIN ENDPOINTS
# =============================================================================
router.register(r'habits', HabitViewSet, basename='habits')             # /api/habits/
router.register(r'habit-logs', HabitLogViewSet, basename='habit-logs')   # /api/habit-logs/
router.register(r'analytics', AnalyticsViewSet, basename='analytics')    # /api/analytics/
router.register(r'achievements', AchievementViewSet, basename='achievements')  # /api/achievements/
router.register(r'insights', InsightViewSet, basename='insights')        # /api/insights/
router.register(r'gamification', GamificationViewSet, basename='gamification')  # /api/gamification/

# =============================================================================
# NOTIFICATION ENDPOINTS
# =============================================================================
router.register(r'notifications', NotificationViewSet, basename='notifications')
router.register(r'smart-tips', SmartTipViewSet, basename='smart-tips')
router.register(r'notification-settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'habit-reminders', HabitReminderViewSet, basename='habit-reminders')
router.register(r'notification-intelligence', NotificationIntelligenceViewSet, basename='notification-intelligence')

# =============================================================================
# SOCIAL FEATURE ENDPOINTS
# =============================================================================
# All social routes are namespaced under ``social/`` for clarity.
router.register(r'social/share-cards', ShareCardViewSet, basename='share-cards')
router.register(r'social/privacy', PrivacyViewSet, basename='privacy')
router.register(r'social/referrals', ReferralViewSet, basename='referrals')
router.register(r'social/groups', GroupHabitViewSet, basename='groups')
router.register(r'social/feed', FeedViewSet, basename='feed')
router.register(r'social/friends', FriendViewSet, basename='friends')
router.register(r'social/joined', JoinedDashboardViewSet, basename='joined')
router.register(r'social/shared-habits', SharedHabitViewSet, basename='shared-habits')
router.register(r'social/encouragements', EncouragementViewSet, basename='encouragements')
router.register(r'social/activity', ActivityFeedViewSet, basename='activity')

# =============================================================================
# SETTINGS, EXPORTS & SUPPORT ENDPOINTS
# =============================================================================
router.register(r'user-settings', UserSettingsViewSet, basename='user-settings')
router.register(r'privacy-settings', PrivacySettingsViewSet, basename='privacy-settings')
router.register(r'security-settings', SecuritySettingsViewSet, basename='security-settings')
router.register(r'login-sessions', LoginSessionViewSet, basename='login-sessions')
router.register(r'settings-audit-logs', SettingsAuditLogViewSet, basename='settings-audit-logs')
router.register(r'exports', ExportViewSet, basename='exports')
router.register(r'privacy-policy', PrivacyPolicyViewSet, basename='privacy-policy')
router.register(r'faqs', FAQViewSet, basename='faqs')
router.register(r'support-tickets', SupportTicketViewSet, basename='support-tickets')

# =============================================================================
# GROW TOGETHER ENDPOINTS
# =============================================================================
router.register(r'grow-together', GrowTogetherViewSet, basename='grow-together')  # /api/grow-together/
