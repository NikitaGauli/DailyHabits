from __future__ import annotations

from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class GrowTogetherSmokeTests(APITestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="gt.user@example.com",
            name="GT User",
            password="StrongPassw0rd!",
        )
        self.client.force_authenticate(self.user)

    def test_list_empty_then_create_and_retrieve(self):
        listed: Any = self.client.get(reverse("grow-together-list"))
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertEqual(listed.data.get("results"), [])

        created: Any = self.client.post(
            reverse("grow-together-create-habit"),
            {"title": "Read together", "privacy": "public"},
            format="json",
        )
        self.assertEqual(created.status_code, 201)
        self.assertTrue(created.data.get("success"))
        habit_id = created.data["habit"]["id"]

        retrieved: Any = self.client.get(reverse("grow-together-detail", args=[habit_id]))
        self.assertEqual(retrieved.status_code, 200)
        self.assertTrue(retrieved.data.get("success"))
        self.assertIn("habit", retrieved.data)
