from __future__ import annotations

from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from admin_panel.models import AdminProfile, AdminRole


User = get_user_model()


class AdminPanelRBACTests(APITestCase):
    def setUp(self):
        self.normal_user = cast(Any, User.objects).create_user(
            email="normal.user@example.com",
            name="Normal User",
            password="StrongPassw0rd!",
        )

        self.admin_full = cast(Any, User.objects).create_user(
            email="admin.full@example.com",
            name="Admin Full",
            password="StrongPassw0rd!",
        )
        self.admin_analytics = cast(Any, User.objects).create_user(
            email="admin.analytics@example.com",
            name="Admin Analytics",
            password="StrongPassw0rd!",
        )

        self.role_full = AdminRole.objects.create(
            name=AdminRole.ADMIN,
            display_name="Admin",
            description="",
            permissions=["users.view", "analytics.view", "analytics.export"],
        )
        self.role_analytics = AdminRole.objects.create(
            name=AdminRole.ANALYTICS,
            display_name="Analytics",
            description="",
            permissions=["analytics.view"],
        )

        AdminProfile.objects.create(user=self.admin_full, role=self.role_full, is_active=True)
        AdminProfile.objects.create(user=self.admin_analytics, role=self.role_analytics, is_active=True)

    def test_admin_me_requires_admin_profile(self):
        self.client.force_authenticate(self.normal_user)
        res: Any = self.client.get(reverse("admin_panel:admin-me"))
        self.assertEqual(res.status_code, 403)

    def test_admin_me_returns_profile_and_permissions(self):
        self.client.force_authenticate(self.admin_full)
        res: Any = self.client.get(reverse("admin_panel:admin-me"))
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data.get("user_email"), self.admin_full.email)
        self.assertIn("permissions", res.data)
        self.assertIn("users.view", res.data["permissions"])

    def test_admin_users_list_requires_users_view_permission(self):
        # Has users.view
        self.client.force_authenticate(self.admin_full)
        ok: Any = self.client.get(reverse("admin_panel:admin-users-list"))
        self.assertEqual(ok.status_code, 200)
        self.assertIn("results", ok.data)

        # Lacks users.view
        self.client.force_authenticate(self.admin_analytics)
        denied: Any = self.client.get(reverse("admin_panel:admin-users-list"))
        self.assertEqual(denied.status_code, 403)

    def test_admin_analytics_overview_and_export_permissions(self):
        overview_url = reverse("admin_panel:admin-analytics-overview")
        export_url = reverse("admin_panel:admin-analytics-export")

        # analytics.view is sufficient for overview
        self.client.force_authenticate(self.admin_analytics)
        overview: Any = self.client.get(overview_url)
        self.assertEqual(overview.status_code, 200)

        # analytics.export required for export
        export_denied: Any = self.client.get(export_url, {"days": 7})
        self.assertEqual(export_denied.status_code, 403)

        self.client.force_authenticate(self.admin_full)
        export_ok: Any = self.client.get(export_url, {"days": 7})
        self.assertEqual(export_ok.status_code, 200)
        self.assertIn("text/csv", export_ok["Content-Type"])
        self.assertIn("Content-Disposition", export_ok)
