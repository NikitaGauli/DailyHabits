from __future__ import annotations

from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class InsightsEndpointTests(APITestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="insights.user@example.com",
            name="Insights User",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_insights_summary_smoke(self):
        res: Any = self.client.get(reverse("insights-summary"))
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        for key in ("insights", "quote", "bestTime", "topHabits", "decliningHabits", "recommendations", "comeback"):
            self.assertIn(key, res.data)

    def test_seed_quotes_requires_staff(self):
        url = reverse("insights-seed-quotes")

        not_staff: Any = self.client.post(url, {}, format="json")
        self.assertEqual(not_staff.status_code, 403)
        self.assertFalse(not_staff.data.get("success"))

        self.user.is_staff = True
        self.user.save(update_fields=["is_staff"])

        ok: Any = self.client.post(url, {}, format="json")
        self.assertEqual(ok.status_code, 200)
        self.assertTrue(ok.data.get("success"))
        self.assertIn("createdCount", ok.data)
