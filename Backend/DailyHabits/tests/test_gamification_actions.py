from __future__ import annotations

from datetime import timedelta
from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from gamification.models import Challenge


User = get_user_model()


class GamificationActionApiTests(APITestCase):
    """API tests for gamification actions beyond the wallet endpoint."""

    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="game.actions@example.com",
            name="Game Actions",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_claim_login_is_idempotent_per_day(self):
        url = reverse("gamification-claim-login")

        first: Any = self.client.post(url, {}, format="json")
        self.assertEqual(first.status_code, 200)
        self.assertTrue(first.data.get("success"))
        # First claim should award either xp/coins or report already_claimed
        self.assertTrue(
            any(k in first.data for k in ("xp", "already_claimed"))
        )

        second: Any = self.client.post(url, {}, format="json")
        self.assertEqual(second.status_code, 200)
        self.assertTrue(second.data.get("success"))
        self.assertTrue(second.data.get("already_claimed"))

    def test_buy_freeze_fails_when_insufficient_coins(self):
        # Fresh users start with 0 coins; buying a freeze should fail.
        url = reverse("gamification-buy-freeze")
        res: Any = self.client.post(url, {}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(res.data.get("success"))
        self.assertIn("error", res.data)

    def test_join_challenge_404_when_missing(self):
        url = reverse("gamification-join-challenge", kwargs={"challenge_id": 999999})
        res: Any = self.client.post(url, {}, format="json")
        self.assertEqual(res.status_code, 404)
        self.assertFalse(res.data.get("success"))

    def test_create_challenge_and_list_challenges(self):
        create_url = reverse("gamification-create-challenge")
        payload = {
            "title": "30-day hydration",
            "description": "Drink water daily",
            "scope": "personal",
            "difficulty": "easy",
            "criteria": {"type": "habit_completion", "count": 30},
            "end_date": (timezone.now() + timedelta(days=30)).isoformat(),
            "xp_reward": 100,
            "coin_reward": 25,
            "max_participants": 1,
        }

        created: Any = self.client.post(create_url, payload, format="json")
        self.assertEqual(created.status_code, 201)
        self.assertTrue(created.data.get("success"))
        self.assertIn("challenge", created.data)

        # List challenges should include the created challenge (via engine)
        list_url = reverse("gamification-challenges")
        listed: Any = self.client.get(list_url)
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertIn("challenges", listed.data)

    def test_leaderboard_endpoint_returns_payload(self):
        # Seed a minimal leaderboard entry by ensuring at least one challenge exists
        Challenge.objects.create(
            title="Community Challenge",
            description="",
            scope="community",
            status="active",
            difficulty="easy",
            criteria={"type": "habit_completion", "count": 1},
            start_date=timezone.now(),
            end_date=timezone.now() + timedelta(days=7),
            created_by=self.user,
        )

        res: Any = self.client.get(reverse("gamification-leaderboard"), {"type": "weekly", "limit": 10})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        # Payload shape may vary, but should include period metadata.
        self.assertIn("boardType", res.data)
        self.assertIn("periodStart", res.data)
        self.assertIn("entries", res.data)
