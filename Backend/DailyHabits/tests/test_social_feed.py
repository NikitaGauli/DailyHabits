from __future__ import annotations

from typing import Any, cast
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from social.models import GroupHabit, GroupMember


User = get_user_model()


class SocialFeedApiTests(APITestCase):
    def setUp(self):
        self.client: APIClient = APIClient()
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

    def test_non_member_cannot_view_group_shared_achievement_post(self):
        intruder = cast(Any, User.objects).create_user(
            email="feed.intruder@example.com",
            name="Feed Intruder",
            password="StrongPassw0rd!",
        )
        group = GroupHabit.objects.create(
            name="Private Group",
            description="Private",
            creator=self.author,
            invite_code="PRIV88",
        )
        GroupMember.objects.create(group=group, user=self.author, role="admin", is_active=True)
        GroupMember.objects.create(group=group, user=self.other, role="member", is_active=True)

        self.client.force_authenticate(self.author)
        created: Any = self.client.post(
            reverse("feed-list"),
            {
                "content": "Shared achievement in group",
                "postType": "achievement",
                "groupId": group.id,
                "isPublic": True,
            },
            format="json",
        )
        self.assertEqual(created.status_code, 201)
        post_id = created.data["post"]["id"]

        self.client.force_authenticate(intruder)
        feed_res: Any = self.client.get(reverse("feed-list"))
        self.assertEqual(feed_res.status_code, 200)
        ids = [p.get("id") for p in feed_res.data.get("results", [])]
        self.assertNotIn(post_id, ids)

        like_res: Any = self.client.post(reverse("feed-like", args=[post_id]), {}, format="json")
        self.assertEqual(like_res.status_code, 403)

        comments_res: Any = self.client.get(reverse("feed-comments", args=[post_id]))
        self.assertEqual(comments_res.status_code, 403)

    def test_non_member_cannot_create_group_achievement_post(self):
        group = GroupHabit.objects.create(
            name="Members Only",
            description="Private",
            creator=self.author,
            invite_code="ONLY11",
        )
        GroupMember.objects.create(group=group, user=self.author, role="admin", is_active=True)

        self.client.force_authenticate(self.other)
        res: Any = self.client.post(
            reverse("feed-list"),
            {
                "content": "I should not be able to post here",
                "postType": "achievement",
                "groupId": group.id,
            },
            format="json",
        )

        self.assertEqual(res.status_code, 403)
        self.assertFalse(res.data.get("success"))

    def test_member_can_create_group_achievement_post(self):
        group = GroupHabit.objects.create(
            name="Members Only 2",
            description="Private",
            creator=self.author,
            invite_code="ONLY22",
        )
        GroupMember.objects.create(group=group, user=self.author, role="admin", is_active=True)
        GroupMember.objects.create(group=group, user=self.other, role="member", is_active=True)

        self.client.force_authenticate(self.other)
        res: Any = self.client.post(
            reverse("feed-list"),
            {
                "content": "I can post because I am a member",
                "postType": "achievement",
                "groupId": group.id,
            },
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data.get("success"))
