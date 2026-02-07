from rest_framework.routers import DefaultRouter
from habits.views import HabitViewSet, HabitLogViewSet
from analytics.views import AnalyticsViewSet
from achievements.views import AchievementViewSet
from insights.views import InsightViewSet
from notifications.views import (
    NotificationViewSet,
    SmartTipViewSet,
    NotificationSettingsViewSet,
    HabitReminderViewSet,
    NotificationIntelligenceViewSet,
)
from social.views import (
    ShareCardViewSet,
    PrivacyViewSet,
    ReferralViewSet,
    GroupHabitViewSet,
    FeedViewSet,
    FriendViewSet,
    JoinedDashboardViewSet,
)

# Create a single router for the entire API
router = DefaultRouter()

# Register ViewSets
router.register(r'habits', HabitViewSet, basename='habits')
router.register(r'habit-logs', HabitLogViewSet, basename='habit-logs')
router.register(r'analytics', AnalyticsViewSet, basename='analytics')
router.register(r'achievements', AchievementViewSet, basename='achievements')
router.register(r'insights', InsightViewSet, basename='insights')
router.register(r'notifications', NotificationViewSet, basename='notifications')
router.register(r'smart-tips', SmartTipViewSet, basename='smart-tips')
router.register(r'notification-settings', NotificationSettingsViewSet, basename='notification-settings')
router.register(r'habit-reminders', HabitReminderViewSet, basename='habit-reminders')
router.register(r'notification-intelligence', NotificationIntelligenceViewSet, basename='notification-intelligence')

# Social sharing
router.register(r'social/share-cards', ShareCardViewSet, basename='share-cards')
router.register(r'social/privacy', PrivacyViewSet, basename='privacy')
router.register(r'social/referrals', ReferralViewSet, basename='referrals')
router.register(r'social/groups', GroupHabitViewSet, basename='groups')
router.register(r'social/feed', FeedViewSet, basename='feed')
router.register(r'social/friends', FriendViewSet, basename='friends')
router.register(r'social/joined', JoinedDashboardViewSet, basename='joined')
