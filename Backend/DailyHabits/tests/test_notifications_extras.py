from __future__ import annotations

from datetime import time
from typing import Any, cast
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from habits.models import Habit
from notifications.models import HabitReminder, SmartTip


User = get_user_model()


class NotificationExtrasApiTests(APITestCase):
    """Tests for smart tips, notification settings, reminders, and intelligence endpoints."""

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="notify.extras@example.com",
            name="Notify Extras",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)
        self.habit = Habit.objects.create(user=self.user, title="Drink", category_name="Health", frequency="daily")

    @patch("notifications.services.SmartTipService.generate_tips_if_needed")
    def test_smart_tips_list_and_actions(self, _gen: Any):
        # Create a tip so list has deterministic content.
        tip = SmartTip.objects.create(
            user=self.user,
            habit=self.habit,
            tip_type="consistency",
            title="Tip",
            message="Do it",
        )

        list_res: Any = self.client.get(reverse("smart-tips-list"))
        self.assertEqual(list_res.status_code, 200)
        self.assertTrue(list_res.data.get("success"))
        self.assertIn("tips", list_res.data)

        mark: Any = self.client.post(reverse("smart-tips-mark-read", args=[tip.id]), {}, format="json")
        self.assertEqual(mark.status_code, 200)

        like1: Any = self.client.post(reverse("smart-tips-like", args=[tip.id]), {}, format="json")
        self.assertEqual(like1.status_code, 200)
        self.assertTrue(like1.data.get("isLiked"))

        save1: Any = self.client.post(reverse("smart-tips-save-tip", args=[tip.id]), {}, format="json")
        self.assertEqual(save1.status_code, 200)
        self.assertTrue(save1.data.get("isSaved"))

        dismiss: Any = self.client.post(reverse("smart-tips-dismiss", args=[tip.id]), {}, format="json")
        self.assertEqual(dismiss.status_code, 200)
        self.assertTrue(dismiss.data.get("success"))

    def test_notification_settings_get_and_update(self):
        # List lazily creates a settings row
        list_res: Any = self.client.get(reverse("notification-settings-list"))
        self.assertEqual(list_res.status_code, 200)
        self.assertTrue(list_res.data.get("success"))
        self.assertIn("settings", list_res.data)

        # Update a couple settings via camelCase keys
        update_res: Any = self.client.patch(
            reverse("notification-settings-update-settings"),
            {"notificationsEnabled": False, "maxNotificationsPerDay": 3},
            format="json",
        )
        self.assertEqual(update_res.status_code, 200)
        self.assertTrue(update_res.data.get("success"))

        after: Any = self.client.get(reverse("notification-settings-list"))
        self.assertEqual(after.data["settings"]["notificationsEnabled"], False)
        self.assertEqual(after.data["settings"]["maxNotificationsPerDay"], 3)

    def test_habit_reminders_list_toggle_and_404(self):
        reminder = HabitReminder.objects.create(
            habit=self.habit,
            reminder_time=time(hour=8, minute=0),
            repeat_type="daily",
            custom_days=[],
            is_enabled=True,
            message="Ping",
        )

        listed: Any = self.client.get(reverse("habit-reminders-list"))
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertGreaterEqual(len(listed.data.get("reminders", [])), 1)

        toggled: Any = self.client.post(reverse("habit-reminders-toggle", args=[reminder.id]), {}, format="json")
        self.assertEqual(toggled.status_code, 200)
        self.assertTrue(toggled.data.get("success"))

        missing: Any = self.client.post(reverse("habit-reminders-toggle", args=[999999]), {}, format="json")
        self.assertEqual(missing.status_code, 404)
        self.assertFalse(missing.data.get("success"))

    @patch("notifications.services.NotificationIntelligence.get_smart_reminder_suggestions", return_value=[{"habitId": 1}])
    @patch("notifications.services.NotificationIntelligence.get_streak_risk_alerts", return_value=[])
    @patch("notifications.services.NotificationIntelligence.get_weekly_performance_nudges", return_value=[])
    @patch("notifications.services.NotificationIntelligence.should_send_notification", return_value=True)
    @patch("notifications.services.NotificationIntelligence.get_notification_summary", return_value={"dailyCap": 10})
    def test_notification_intelligence_endpoints(self, *_mocks: Any):
        # Each endpoint is a thin wrapper; we mock the service to keep tests deterministic.
        suggestions: Any = self.client.get(reverse("notification-intelligence-smart-suggestions"))
        self.assertEqual(suggestions.status_code, 200)
        self.assertTrue(suggestions.data.get("success"))
        self.assertIn("suggestions", suggestions.data)

        should_send: Any = self.client.post(
            reverse("notification-intelligence-should-send"),
            {"notification_type": "reminder"},
            format="json",
        )
        self.assertEqual(should_send.status_code, 200)
        self.assertTrue(should_send.data.get("shouldSend"))

        summary: Any = self.client.get(reverse("notification-intelligence-intelligence-summary"))
        self.assertEqual(summary.status_code, 200)
        self.assertTrue(summary.data.get("success"))
        self.assertEqual(summary.data.get("dailyCap"), 10)
