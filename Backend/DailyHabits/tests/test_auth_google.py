from __future__ import annotations

from typing import Any, cast
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class GoogleAuthApiTests(APITestCase):
    """Unit/API tests for Google OAuth login (token verification is mocked)."""

    @override_settings(GOOGLE_CLIENT_ID="test-google-client-id")
    @patch("authentication.views.google_id_token.verify_oauth2_token")
    def test_google_auth_creates_new_user(self, verify: Any):
        # Simulate Google's verified token payload
        verify.return_value = {
            "iss": "accounts.google.com",
            "sub": "google-sub-123",
            "email": "new.google.user@example.com",
            "name": "New Google User",
            "picture": "https://example.com/p.png",
        }

        url = reverse("authentication:google-auth")
        res: Any = self.client.post(url, {"id_token": "fake"}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertTrue(res.data.get("is_new_user"))
        self.assertFalse(res.data.get("account_linked"))
        self.assertIn("token", res.data)

        # Ensure user exists and is linked to google_id
        user = cast(Any, User.objects).get(email="new.google.user@example.com")
        self.assertEqual(user.google_id, "google-sub-123")
        self.assertEqual(user.auth_provider, "google")

    @override_settings(GOOGLE_CLIENT_ID="test-google-client-id")
    @patch("authentication.views.google_id_token.verify_oauth2_token")
    def test_google_auth_links_existing_email_user(self, verify: Any):
        # Existing email/password account
        existing = cast(Any, User.objects).create_user(
            email="linked@example.com",
            name="Linked",
            password="StrongPassw0rd!",
        )
        self.assertFalse(bool(existing.google_id))

        verify.return_value = {
            "iss": "https://accounts.google.com",
            "sub": "google-sub-999",
            "email": "linked@example.com",
            "name": "Linked User",
        }

        url = reverse("authentication:google-auth")
        res: Any = self.client.post(url, {"id_token": "fake"}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get("success"))
        self.assertFalse(res.data.get("is_new_user"))
        self.assertTrue(res.data.get("account_linked"))

        existing.refresh_from_db()
        self.assertEqual(existing.google_id, "google-sub-999")

    @override_settings(GOOGLE_CLIENT_ID="test-google-client-id")
    @patch("authentication.views.google_id_token.verify_oauth2_token", side_effect=ValueError("bad"))
    def test_google_auth_rejects_invalid_token(self, _verify: Any):
        url = reverse("authentication:google-auth")
        res: Any = self.client.post(url, {"id_token": "bad"}, format="json")
        self.assertEqual(res.status_code, 401)
        self.assertFalse(res.data.get("success"))

    def test_google_auth_returns_503_when_not_configured(self):
        # With GOOGLE_CLIENT_ID empty (default), endpoint should be unavailable
        url = reverse("authentication:google-auth")
        res: Any = self.client.post(url, {"id_token": "fake"}, format="json")
        self.assertEqual(res.status_code, 503)
        self.assertFalse(res.data.get("success"))
