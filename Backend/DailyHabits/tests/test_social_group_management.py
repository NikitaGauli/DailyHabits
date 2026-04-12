from __future__ import annotations

from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from social.models import FeedPost, GroupHabit, GroupMember


User = get_user_model()


class SocialGroupManagementApiTests(APITestCase):
    def setUp(self):
        self.admin = cast(Any, User.objects).create_user(
            email="group.admin@example.com",
            name="Group Admin",
            password="StrongPassw0rd!",
        )
        self.member = cast(Any, User.objects).create_user(
            email="group.member@example.com",
            name="Group Member",
            password="StrongPassw0rd!",
        )
        self.other = cast(Any, User.objects).create_user(
            email="group.other@example.com",
            name="Group Other",
            password="StrongPassw0rd!",
        )

        self.group = GroupHabit.objects.create(
            name="Test Group",
            description="For API tests",
            creator=self.admin,
            invite_code="TEST99",
        )
        GroupMember.objects.create(group=self.group, user=self.admin, role="admin", is_active=True)

    def test_add_member_by_admin_with_email(self):
        self.client.force_authenticate(self.admin)
        res: Any = self.client.post(
            reverse("groups-add-member", args=[self.group.id]),
            {"email": self.member.email},
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data.get("success"))
        self.assertEqual(res.data["member"]["id"], self.member.id)
        self.assertTrue(
            GroupMember.objects.filter(group=self.group, user=self.member, is_active=True).exists()
        )

    def test_create_group_with_initial_members(self):
        self.client.force_authenticate(self.admin)

        res: Any = self.client.post(
            reverse("groups-list"),
            {
                "name": "Creator With Members",
                "description": "Bootstrapped group",
                "members": [self.member.email, self.other.id],
            },
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data.get("success"))
        self.assertEqual(res.data.get("membersAddedCount"), 2)

        group_id = res.data["group"]["id"]
        self.assertTrue(
            GroupMember.objects.filter(group_id=group_id, user=self.member, is_active=True).exists()
        )
        self.assertTrue(
            GroupMember.objects.filter(group_id=group_id, user=self.other, is_active=True).exists()
        )

    def test_add_member_forbidden_for_non_admin(self):
        GroupMember.objects.create(group=self.group, user=self.member, role="member", is_active=True)
        self.client.force_authenticate(self.member)

        res: Any = self.client.post(
            reverse("groups-add-member", args=[self.group.id]),
            {"email": self.other.email},
            format="json",
        )

        self.assertEqual(res.status_code, 403)
        self.assertFalse(res.data.get("success"))

    def test_delete_group_soft_deletes_group_and_memberships(self):
        GroupMember.objects.create(group=self.group, user=self.member, role="member", is_active=True)
        self.client.force_authenticate(self.admin)

        res: Any = self.client.delete(reverse("groups-delete-group", args=[self.group.id]))

        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.group.refresh_from_db()
        self.assertFalse(self.group.is_active)
        self.assertFalse(
            GroupMember.objects.filter(group=self.group, user=self.admin, is_active=True).exists()
        )
        self.assertFalse(
            GroupMember.objects.filter(group=self.group, user=self.member, is_active=True).exists()
        )

    def test_members_endpoint_requires_membership(self):
        self.client.force_authenticate(self.other)

        res: Any = self.client.get(reverse("groups-members", args=[self.group.id]))

        self.assertEqual(res.status_code, 403)
        self.assertFalse(res.data.get("success"))

    def test_group_detail_requires_membership(self):
        self.client.force_authenticate(self.other)

        res: Any = self.client.get(reverse("groups-enriched-detail", args=[self.group.id]))

        self.assertEqual(res.status_code, 403)
        self.assertFalse(res.data.get("success"))

    def test_group_detail_includes_shared_achievements_for_member(self):
        GroupMember.objects.create(group=self.group, user=self.member, role="member", is_active=True)
        FeedPost.objects.create(
            author=self.admin,
            post_type="achievement",
            content="Reached a new group milestone!",
            group=self.group,
            is_public=True,
        )

        self.client.force_authenticate(self.member)
        res: Any = self.client.get(reverse("groups-enriched-detail", args=[self.group.id]))

        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        data = res.data.get("data", {})
        self.assertIn("sharedAchievements", data)
        self.assertGreaterEqual(len(data["sharedAchievements"]), 1)
