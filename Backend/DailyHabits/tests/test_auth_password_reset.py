from __future__ import annotations

from typing import Any, cast
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from rest_framework.test import APITestCase


User = get_user_model()


class PasswordResetApiTests(APITestCase):
    """Tests for both token-based and OTP-based password reset flows."""

    def setUp(self):
        self.password = "StrongPassw0rd!"
        self.user = cast(Any, User.objects).create_user(
            email="reset.user@example.com",
            name="Reset User",
            password=self.password,
        )

    @override_settings(DEBUG=True)
    @patch("authentication.password_reset_service.PasswordResetService._send_reset_email", return_value=False)
    @patch("authentication.password_reset_service.PasswordResetService._send_password_changed_email")
    def test_forgot_validate_and_reset_password_token_flow(self, _changed_email: Any, _send_email: Any):
        # Request reset token (should not enumerate users and should include debug token in DEBUG)
        forgot_url = reverse("authentication:forgot-password")
        forgot: Any = self.client.post(forgot_url, {"email": "Reset.User@Example.com"}, format="json")
        self.assertEqual(forgot.status_code, 200)
        self.assertTrue(forgot.data.get("success"))
        self.assertIn("debug_reset_token", forgot.data)

        token = forgot.data["debug_reset_token"]

        # Validate token
        validate_url = reverse("authentication:validate-reset-token")
        validated: Any = self.client.post(validate_url, {"token": token}, format="json")
        self.assertEqual(validated.status_code, 200)
        self.assertTrue(validated.data.get("valid"))

        # Reset password
        reset_url = reverse("authentication:reset-password")
        new_password = "NewStrongPassw0rd!"
        reset: Any = self.client.post(
            reset_url,
            {
                "token": token,
                "new_password": new_password,
                "confirm_password": new_password,
            },
            format="json",
        )
        self.assertEqual(reset.status_code, 200)
        self.assertTrue(reset.data.get("success"))

        # Token should be single-use: resetting again should fail
        reset_again: Any = self.client.post(
            reset_url,
            {
                "token": token,
                "new_password": "AnotherPassw0rd!",
                "confirm_password": "AnotherPassw0rd!",
            },
            format="json",
        )
        self.assertEqual(reset_again.status_code, 400)
        self.assertFalse(reset_again.data.get("success"))

        # Ensure the new password works via the login endpoint
        login_url = reverse("authentication:login")
        login: Any = self.client.post(
            login_url,
            {"email": self.user.email, "password": new_password},
            format="json",
        )
        self.assertEqual(login.status_code, 200)
        self.assertTrue(login.data.get("success"))

    @override_settings(DEBUG=True)
    @patch("authentication.otp_service.OTPResetService._send_otp_email", return_value=False)
    @patch("authentication.otp_service.OTPResetService._send_password_changed_email")
    def test_request_and_verify_otp_reset_flow(self, _changed_email: Any, _send_otp: Any):
        # Step 1: request OTP
        request_url = reverse("authentication:request-password-reset")
        res1: Any = self.client.post(request_url, {"email": self.user.email}, format="json")
        self.assertEqual(res1.status_code, 200)
        self.assertTrue(res1.data.get("success"))
        self.assertIn("otp_ttl_seconds", res1.data)
        self.assertIn("debug_otp", res1.data)

        otp = res1.data["debug_otp"]

        # Step 2: verify OTP and reset password
        verify_url = reverse("authentication:verify-otp-reset")
        new_password = "OtpNewStrongPassw0rd!"
        res2: Any = self.client.post(
            verify_url,
            {
                "email": self.user.email,
                "otp": otp,
                "new_password": new_password,
                "confirm_password": new_password,
            },
            format="json",
        )
        self.assertEqual(res2.status_code, 200)
        self.assertTrue(res2.data.get("success"))

        # OTP should be single-use: second attempt should fail
        res3: Any = self.client.post(
            verify_url,
            {
                "email": self.user.email,
                "otp": otp,
                "new_password": "AnotherStrongPassw0rd!",
                "confirm_password": "AnotherStrongPassw0rd!",
            },
            format="json",
        )
        self.assertEqual(res3.status_code, 400)
        self.assertFalse(res3.data.get("success"))

        # Verify login succeeds with the new password
        login_url = reverse("authentication:login")
        login: Any = self.client.post(
            login_url,
            {"email": self.user.email, "password": new_password},
            format="json",
        )
        self.assertEqual(login.status_code, 200)
        self.assertTrue(login.data.get("success"))

    def test_forgot_password_rejects_invalid_email_payload(self):
        # Input validation should reject missing/invalid email
        forgot_url = reverse("authentication:forgot-password")
        res: Any = self.client.post(forgot_url, {"email": "not-an-email"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(res.data.get("success"))
        self.assertIn("errors", res.data)
