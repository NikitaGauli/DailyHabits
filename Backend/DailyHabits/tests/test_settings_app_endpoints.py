from __future__ import annotations

from datetime import date, timedelta
from typing import Any, cast

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class SettingsAppEndpointTests(APITestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="settings.user@example.com",
            name="Settings User",
            password="StrongPassw0rd!",
        )

    def test_privacy_policy_and_faq_are_public(self):
        policy: Any = self.client.get(reverse("privacy-policy-list"))
        self.assertEqual(policy.status_code, 200)
        self.assertTrue(policy.data.get("success"))
        self.assertIn("policy", policy.data)

        faqs: Any = self.client.get(reverse("faqs-list"))
        self.assertEqual(faqs.status_code, 200)
        self.assertTrue(faqs.data.get("success"))
        self.assertIn("faqs", faqs.data)

    def test_user_settings_list_and_update_color_validation(self):
        self.client.force_authenticate(self.user)

        listed: Any = self.client.get(reverse("user-settings-list"))
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertIn("settings", listed.data)

        invalid: Any = self.client.post(
            reverse("user-settings-update-color"),
            {"color": "not-a-real-color"},
            format="json",
        )
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(invalid.data.get("status"), "error")

        ok: Any = self.client.post(
            reverse("user-settings-update-color"),
            {"color": "green"},
            format="json",
        )
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.data.get("status"), "success")
        self.assertEqual(ok.data.get("preferred_color"), "green")

    def test_privacy_and_security_settings_update(self):
        self.client.force_authenticate(self.user)

        privacy_list: Any = self.client.get(reverse("privacy-settings-list"))
        self.assertEqual(privacy_list.status_code, 200)

        privacy_update: Any = self.client.patch(
            reverse("privacy-settings-update-settings"),
            {"showInLeaderboard": False},
            format="json",
        )
        self.assertEqual(privacy_update.status_code, 200)
        self.assertTrue(privacy_update.data.get("success"))

        security_list: Any = self.client.get(reverse("security-settings-list"))
        self.assertEqual(security_list.status_code, 200)

        bad_pw: Any = self.client.post(
            reverse("security-settings-change-password"),
            {"currentPassword": "wrong", "newPassword": "NewStrongPassw0rd!"},
            format="json",
        )
        self.assertEqual(bad_pw.status_code, 400)
        self.assertFalse(bad_pw.data.get("success"))

    def test_login_sessions_list_and_revoke_missing(self):
        self.client.force_authenticate(self.user)

        listed: Any = self.client.get(reverse("login-sessions-list"))
        self.assertEqual(listed.status_code, 200)
        self.assertTrue(listed.data.get("success"))
        self.assertIn("sessions", listed.data)

        missing: Any = self.client.post(reverse("login-sessions-revoke", args=[999999]), {}, format="json")
        self.assertEqual(missing.status_code, 404)
        self.assertFalse(missing.data.get("success"))

    def test_exports_request_validation(self):
        self.client.force_authenticate(self.user)

        missing: Any = self.client.post(reverse("exports-request-export"), {"format": "json"}, format="json")
        self.assertEqual(missing.status_code, 400)
        self.assertFalse(missing.data.get("success"))

        start = (date.today() - timedelta(days=7)).isoformat()
        end = date.today().isoformat()

        ok: Any = self.client.post(
            reverse("exports-request-export"),
            {"format": "json", "dateFrom": start, "dateTo": end},
            format="json",
        )
        self.assertEqual(ok.status_code, 201)
        self.assertTrue(ok.data.get("success"))
        self.assertIn("exportId", ok.data)

    def test_support_tickets_create_validation(self):
        self.client.force_authenticate(self.user)

        bad: Any = self.client.post(reverse("support-tickets-list"), {"subject": "", "description": ""}, format="json")
        self.assertEqual(bad.status_code, 400)
        self.assertFalse(bad.data.get("success"))

        created: Any = self.client.post(
            reverse("support-tickets-list"),
            {"subject": "Help", "description": "Something broke", "category": "general"},
            format="json",
        )
        self.assertEqual(created.status_code, 201)
        self.assertTrue(created.data.get("success"))
        self.assertIn("ticketId", created.data)
