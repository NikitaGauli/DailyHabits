from __future__ import annotations

from datetime import date
from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient, APITestCase

from habits.models import Habit, HabitLog
from notifications.models import Notification


User = get_user_model()


class ApiRootTests(APITestCase):
    client: APIClient

    def test_api_root_is_public_and_has_endpoints(self):
        res: Any = self.client.get(reverse("api-root"))
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data.get("status"), "online")
        self.assertIn("endpoints", res.data)


class HabitsApiTests(APITestCase):
    client: APIClient

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="habit.api@example.com",
            name="Habit Api",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def _habit_payload(self):
        return {
            "title": "Drink Water",
            "description": "8 glasses",
            "frequency": "daily",
            "categoryName": "Health",
            "iconCode": 0xE87C,
            "colorValue": 0xFF6366F1,
            "priority": "medium",
            "visibility": "private",
        }

    def test_habit_crud_create_list_retrieve_update_delete(self):
        list_url = reverse("habits-list")

        # Create
        create: Any = self.client.post(list_url, self._habit_payload(), format="json")
        self.assertEqual(create.status_code, 201)
        self.assertTrue(create.data.get("success"))
        habit_id = create.data["habit"]["id"]

        # List
        listed: Any = self.client.get(list_url)
        self.assertEqual(listed.status_code, 200)
        self.assertGreaterEqual(len(listed.data), 1)

        # Retrieve
        detail_url = reverse("habits-detail", args=[habit_id])
        detail: Any = self.client.get(detail_url)
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.data["id"], habit_id)

        # Update (PATCH)
        patch: Any = self.client.patch(detail_url, {"title": "Drink More Water"}, format="json")
        self.assertEqual(patch.status_code, 200)
        self.assertTrue(patch.data.get("success"))

        # Soft delete
        delete: Any = self.client.delete(detail_url)
        self.assertEqual(delete.status_code, 200)
        self.assertTrue(delete.data.get("success"))
        self.assertTrue(Habit.objects.get(id=habit_id).is_deleted)

    def test_habit_create_validation_error_missing_title(self):
        list_url = reverse("habits-list")
        payload = self._habit_payload()
        payload.pop("title")
        res: Any = self.client.post(list_url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(res.data.get("success"))
        self.assertIn("errors", res.data)

    def test_today_endpoint_returns_summary(self):
        # No habits case should still succeed
        res: Any = self.client.get(reverse("habits-today"))
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertIn("summary", res.data)

    def test_toggle_complete_creates_log_and_toggles(self):
        habit = Habit.objects.create(
            user=self.user,
            title="Read",
            category_name="Learning",
            frequency="daily",
        )
        url = reverse("habits-toggle-complete", args=[habit.id])

        first: Any = self.client.post(url, {}, format="json")
        self.assertEqual(first.status_code, 200)
        self.assertTrue(first.data.get("success"))
        self.assertTrue(HabitLog.objects.filter(habit=habit, date=timezone.now().date()).exists())

        second: Any = self.client.post(url, {}, format="json")
        self.assertEqual(second.status_code, 200)
        self.assertTrue(second.data.get("success"))


class AnalyticsApiTests(APITestCase):
    client: APIClient

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="analytics.api@example.com",
            name="Analytics Api",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_dashboard_weekly_monthly_endpoints(self):
        dashboard: Any = self.client.get(reverse("analytics-dashboard"))
        self.assertEqual(dashboard.status_code, 200)
        self.assertTrue(dashboard.data.get("success"))
        self.assertIn("data", dashboard.data)
        self.assertIn("summary", dashboard.data["data"])
        self.assertIn("weeklyData", dashboard.data["data"])

        weekly: Any = self.client.get(reverse("analytics-weekly"))
        self.assertEqual(weekly.status_code, 200)
        self.assertTrue(weekly.data.get("success"))
        self.assertIsInstance(weekly.data.get("data"), list)

        monthly: Any = self.client.get(reverse("analytics-monthly"), {"year": 2026, "month": 2})
        self.assertEqual(monthly.status_code, 200)
        self.assertTrue(monthly.data.get("success"))
        self.assertIn("heatmap", monthly.data)

    def test_trend_days_is_capped(self):
        trend: Any = self.client.get(reverse("analytics-trend"), {"days": 999})
        self.assertEqual(trend.status_code, 200)
        self.assertEqual(trend.data.get("days"), 90)


class NotificationsApiTests(APITestCase):
    client: APIClient

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="notify.api@example.com",
            name="Notify Api",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_list_unread_mark_read_snooze_delete(self):
        n = Notification.objects.create(
            user=self.user,
            notification_type="system",
            title="Welcome",
            message="Hello",
            status="sent",
        )

        list_res: Any = self.client.get(reverse("notifications-list"))
        self.assertEqual(list_res.status_code, 200)
        self.assertTrue(list_res.data.get("success"))
        self.assertIn("notifications", list_res.data)

        unread: Any = self.client.get(reverse("notifications-unread"))
        self.assertEqual(unread.status_code, 200)
        self.assertTrue(unread.data.get("success"))
        self.assertGreaterEqual(unread.data.get("unreadCount"), 1)

        mark: Any = self.client.post(reverse("notifications-mark-read", args=[n.id]), {}, format="json")
        self.assertEqual(mark.status_code, 200)

        snooze: Any = self.client.post(reverse("notifications-snooze", args=[n.id]), {"minutes": 5}, format="json")
        self.assertEqual(snooze.status_code, 200)

        delete: Any = self.client.delete(reverse("notifications-detail", args=[n.id]))
        self.assertEqual(delete.status_code, 200)

    def test_mark_read_404(self):
        res: Any = self.client.post(reverse("notifications-mark-read", args=[999999]), {}, format="json")
        self.assertEqual(res.status_code, 404)
        self.assertFalse(res.data.get("success"))


class GamificationApiTests(APITestCase):
    client: APIClient

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="game.api@example.com",
            name="Game Api",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_wallet_endpoint_creates_wallet_and_returns_transactions(self):
        res: Any = self.client.get(reverse("gamification-wallet"))
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertIn("wallet", res.data)
        self.assertIn("transactions", res.data)
