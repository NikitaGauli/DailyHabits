from __future__ import annotations

from typing import Any, cast
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class SocialFeedApiTests(APITestCase):
    def setUp(self):
        self.author = cast(Any, User.objects).create_user(
            email="feed.author@example.com",
            name="Feed Author",
            password="StrongPassw0rd!",
        )
        self.other = cast(Any, User.objects).create_user(
            email="feed.other@example.com",
            name="Feed Other",
            password="StrongPassw0rd!",
        )

    def test_feed_list_is_paginated_and_empty_initially(self):
        self.client.force_authenticate(self.author)
        res: Any = self.client.get(reverse("feed-list"))
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertIn("results", res.data)

    def test_feed_create_validates_content(self):
        self.client.force_authenticate(self.author)

        bad: Any = self.client.post(reverse("feed-list"), {"content": ""}, format="json")
        self.assertEqual(bad.status_code, 400)
        self.assertFalse(bad.data.get("success"))

        created: Any = self.client.post(reverse("feed-list"), {"content": "Hello world"}, format="json")
        self.assertEqual(created.status_code, 201)
        self.assertTrue(created.data.get("success"))
        self.assertIn("post", created.data)

    @patch("social.views.NotificationCreator.post_liked")
    def test_feed_like_toggles(self, _notify: Any):
        self.client.force_authenticate(self.author)
        created: Any = self.client.post(reverse("feed-list"), {"content": "Like me"}, format="json")
        post_id = created.data["post"]["id"]

        self.client.force_authenticate(self.other)
        like1: Any = self.client.post(reverse("feed-like", args=[post_id]), {}, format="json")
        self.assertEqual(like1.status_code, 200)
        self.assertTrue(like1.data.get("success"))
        self.assertTrue(like1.data.get("liked"))

        like2: Any = self.client.post(reverse("feed-like", args=[post_id]), {}, format="json")
        self.assertEqual(like2.status_code, 200)
        self.assertTrue(like2.data.get("success"))
        self.assertFalse(like2.data.get("liked"))

    @patch("social.views.NotificationCreator.post_commented")
    def test_feed_comments_add_and_list(self, _notify: Any):
        self.client.force_authenticate(self.author)
        created: Any = self.client.post(reverse("feed-list"), {"content": "Discuss"}, format="json")
        post_id = created.data["post"]["id"]

        self.client.force_authenticate(self.other)
        add: Any = self.client.post(
            reverse("feed-comments", args=[post_id]),
            {"content": "Nice"},
            format="json",
        )
        self.assertEqual(add.status_code, 201)
        self.assertTrue(add.data.get("success"))

        listed: Any = self.client.get(reverse("feed-comments", args=[post_id]))
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertIn("comments", listed.data)
