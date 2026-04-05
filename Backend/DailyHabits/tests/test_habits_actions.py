from __future__ import annotations

from datetime import timedelta
from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from habits.models import Habit, HabitLog, Streak


User = get_user_model()


class HabitActionApiTests(APITestCase):
    """API tests for the non-CRUD habit endpoints (skip/pause/reorder/etc.)."""

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="habit.actions@example.com",
            name="Habit Actions",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def _habit(self, **kwargs: Any) -> Habit:
        # Helper to create a habit with minimal required fields
        return Habit.objects.create(
            user=self.user,
            title=kwargs.get("title", "Test Habit"),
            category_name=kwargs.get("category_name", "General"),
            frequency=kwargs.get("frequency", "daily"),
            status=kwargs.get("status", "active"),
        )

    def test_skip_creates_or_updates_log_as_skipped(self):
        habit = self._habit(title="Skip Me")
        url = reverse("habits-skip", args=[habit.id])

        res: Any = self.client.post(url, {"reason": "Busy"}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertEqual(res.data.get("status"), "skipped")

        log = HabitLog.objects.get(habit=habit, date=timezone.now().date())
        self.assertEqual(log.status, "skipped")
        self.assertEqual(log.notes, "Busy")

    def test_pause_and_resume_updates_status_and_optional_streak_recovery(self):
        habit = self._habit(title="Pause Me")
        pause_url = reverse("habits-pause", args=[habit.id])
        resume_url = reverse("habits-resume", args=[habit.id])

        paused: Any = self.client.post(pause_url, {"reason": "Vacation"}, format="json")
        self.assertEqual(paused.status_code, 200)
        self.assertTrue(paused.data.get("success"))

        habit.refresh_from_db()
        self.assertEqual(habit.status, "paused")
        self.assertEqual(habit.pause_reason, "Vacation")

        # Create a streak record at 0 so recovery can apply
        streak, _ = Streak.objects.get_or_create(habit=habit)
        streak.current_streak = 0
        streak.save(update_fields=["current_streak"])

        resumed: Any = self.client.post(resume_url, {"recoverStreak": True}, format="json")
        self.assertEqual(resumed.status_code, 200)
        self.assertTrue(resumed.data.get("success"))

        habit.refresh_from_db()
        self.assertEqual(habit.status, "active")
        habit.streak.refresh_from_db()
        self.assertGreaterEqual(habit.streak.current_streak, 1)

    def test_reorder_requires_order_list_and_updates_sort_order(self):
        habit1 = self._habit(title="A")
        habit2 = self._habit(title="B")

        url = reverse("habits-reorder")

        # Validation error
        bad: Any = self.client.post(url, {}, format="json")
        self.assertEqual(bad.status_code, 400)
        self.assertFalse(bad.data.get("success"))

        ok: Any = self.client.post(
            url,
            {
                "order": [
                    {"id": habit1.id, "sortOrder": 2},
                    {"id": habit2.id, "sortOrder": 1},
                ]
            },
            format="json",
        )
        self.assertEqual(ok.status_code, 200)
        self.assertTrue(ok.data.get("success"))

        habit1.refresh_from_db()
        habit2.refresh_from_db()
        self.assertEqual(habit1.sort_order, 2)
        self.assertEqual(habit2.sort_order, 1)

    def test_partial_complete_clamps_score_and_does_not_mark_as_completed(self):
        habit = self._habit(title="Partial")
        url = reverse("habits-partial-complete", args=[habit.id])

        res: Any = self.client.post(url, {"score": 999}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertEqual(res.data.get("status"), "partial")
        self.assertEqual(res.data.get("partialScore"), 1.0)

        log = HabitLog.objects.get(habit=habit, date=timezone.now().date())
        self.assertEqual(log.status, "partial")
        self.assertEqual(float(log.partial_score), 1.0)

    def test_history_days_is_capped_at_365(self):
        habit = self._habit(title="History")
        today = timezone.now().date()
        HabitLog.objects.create(habit=habit, date=today, status="completed")
        HabitLog.objects.create(habit=habit, date=today - timedelta(days=400), status="completed")

        url = reverse("habits-history", args=[habit.id])
        res: Any = self.client.get(url, {"days": 999})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))

        # The older log should be outside the 365-day window
        dates = [h["date"] for h in res.data.get("history", [])]
        self.assertIn(today.isoformat(), dates)
        self.assertNotIn((today - timedelta(days=400)).isoformat(), dates)

    def test_stats_and_categories_and_stats_summary_endpoints(self):
        habit = self._habit(title="Stats")

        stats: Any = self.client.get(reverse("habits-stats", args=[habit.id]))
        self.assertEqual(stats.status_code, 200)
        self.assertTrue(stats.data.get("success"))
        self.assertIn("streak", stats.data)
        self.assertIn("consistency", stats.data)
        self.assertIn("successRate", stats.data)

        categories: Any = self.client.get(reverse("habits-categories"))
        self.assertEqual(categories.status_code, 200)
        self.assertTrue(categories.data.get("success"))
        self.assertIn("defaultCategories", categories.data)

        summary: Any = self.client.get(reverse("habits-stats-summary"))
        self.assertEqual(summary.status_code, 200)
        self.assertTrue(summary.data.get("success"))
        self.assertIn("totalHabits", summary.data)
