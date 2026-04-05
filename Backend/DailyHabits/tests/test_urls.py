from __future__ import annotations

from django.test import SimpleTestCase
from django.urls import reverse, resolve


class ProjectUrlTests(SimpleTestCase):
    def test_api_root_route_exists(self):
        url = reverse("api-root")
        match = resolve(url)
        self.assertEqual(match.url_name, "api-root")


class AuthUrlTests(SimpleTestCase):
    def test_auth_endpoints_reverse(self):
        self.assertEqual(reverse("authentication:register"), "/api/auth/register/")
        self.assertEqual(reverse("authentication:login"), "/api/auth/login/")
        self.assertEqual(reverse("authentication:logout"), "/api/auth/logout/")
        self.assertEqual(reverse("authentication:profile"), "/api/auth/profile/")
        self.assertEqual(reverse("authentication:change-password"), "/api/auth/change-password/")


class RouterUrlNameTests(SimpleTestCase):
    def test_habits_router_names_exist(self):
        # DefaultRouter names: <basename>-list / <basename>-detail
        reverse("habits-list")
        reverse("habit-logs-list")
        reverse("notifications-list")
        reverse("smart-tips-list")
        reverse("gamification-list")

    def test_analytics_action_routes_exist(self):
        # AnalyticsViewSet is action-only (no standard list route)
        reverse("analytics-dashboard")
        reverse("analytics-weekly")
        reverse("analytics-monthly")
        reverse("analytics-trend")

    def test_habits_custom_action_names_exist(self):
        reverse("habits-today")
        reverse("habits-stats-summary")
