from __future__ import annotations

from typing import Any

from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from authentication.models import User as AuthUser


class AuthenticationApiTests(APITestCase):
    def setUp(self):
        # Ensure Pylance understands this is DRF's APIClient (Response has .data).
        self.client: APIClient = APIClient()
        self.password = "StrongPassw0rd!"
        # Create the user explicitly to avoid Django manager typing issues in Pylance.
        self.user = AuthUser(email="auth.user@example.com", name="Auth User")
        self.user.set_password(self.password)
        self.user.save()

    def test_register_success(self):
        url = reverse("authentication:register")
        payload = {
            "email": "new.account@example.com",
            "name": "New Account",
            "password": self.password,
            "password2": self.password,
        }
        res: Any = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data.get("success"))
        self.assertIn("token", res.data)
        self.assertIn("refresh", res.data)

    def test_register_rejects_password_mismatch(self):
        url = reverse("authentication:register")
        payload = {
            "email": "bad.account@example.com",
            "name": "Bad Account",
            "password": self.password,
            "password2": "MismatchPassw0rd!",
        }
        res: Any = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(res.data.get("success"))
        self.assertIn("errors", res.data)

    def test_login_success_and_invalid_password(self):
        url = reverse("authentication:login")

        ok: Any = self.client.post(
            url,
            {"email": self.user.email, "password": self.password},
            format="json",
        )
        self.assertEqual(ok.status_code, 200)
        self.assertTrue(ok.data.get("success"))
        self.assertIn("token", ok.data)
        self.assertIn("refresh", ok.data)

        bad: Any = self.client.post(
            url,
            {"email": self.user.email, "password": "WrongPassw0rd!"},
            format="json",
        )
        self.assertEqual(bad.status_code, 401)
        self.assertFalse(bad.data.get("success"))

    def test_profile_requires_auth(self):
        url = reverse("authentication:profile")
        res: Any = self.client.get(url)
        self.assertEqual(res.status_code, 401)

    def test_profile_get_and_put(self):
        self.client.force_authenticate(user=self.user)
        url = reverse("authentication:profile")

        get_res: Any = self.client.get(url)
        self.assertEqual(get_res.status_code, 200)
        self.assertTrue(get_res.data.get("success"))
        self.assertEqual(get_res.data["user"]["email"], self.user.email)

        patch_res: Any = self.client.patch(url, {"name": "Updated Name"}, format="json")
        self.assertEqual(patch_res.status_code, 200)
        self.assertTrue(patch_res.data.get("success"))
        self.user.refresh_from_db()
        self.assertEqual(self.user.name, "Updated Name")

    def test_logout_requires_auth_and_refresh(self):
        url = reverse("authentication:logout")

        # Unauthenticated
        res: Any = self.client.post(url, {"refresh": "x"}, format="json")
        self.assertEqual(res.status_code, 401)

        # Authenticated, refresh is optional in view implementation
        self.client.force_authenticate(user=self.user)
        res2: Any = self.client.post(url, {"refresh": ""}, format="json")
        self.assertEqual(res2.status_code, 200)
        self.assertTrue(res2.data.get("success"))
