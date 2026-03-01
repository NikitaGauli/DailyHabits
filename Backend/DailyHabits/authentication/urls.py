"""
=============================================================================
 Authentication URL Configuration
=============================================================================

 Module:  authentication/urls.py
 Project: DailyHabits Backend

 Purpose:
   Maps URL paths to authentication views.  Included in the main
   project router under the ``/api/auth/`` prefix via
   ``DailyHabits/urls.py``.

 Endpoint Groups:
   • Core Auth    – register, login, logout
   • Profile      – profile retrieval & update, password change
   • Security     – login history audit trail
   • GDPR / Privacy – data export, data-deletion requests
=============================================================================
"""

from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    GoogleAuthView,
    LogoutView,
    UserProfileView,
    ChangePasswordView,
    LoginHistoryView,
    DataExportView,
    DataDeletionRequestView,
    ForgotPasswordView,
    ValidateResetTokenView,
    ResetPasswordView,
    RequestPasswordResetOTPView,
    VerifyOTPResetPasswordView,
)

# Namespace for reverse URL resolution (e.g. 'authentication:login')
app_name = 'authentication'

urlpatterns = [
    # ── Core Authentication Endpoints ───────────────────────────────
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('google/', GoogleAuthView.as_view(), name='google-auth'),
    path('logout/', LogoutView.as_view(), name='logout'),

    # ── User Profile Endpoints ─────────────────────────────────────
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),

    # ── Password Reset Endpoints (Token-Based — Legacy) ──────────────
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot-password'),
    path('validate-reset-token/', ValidateResetTokenView.as_view(), name='validate-reset-token'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset-password'),

    # ── Password Reset Endpoints (OTP-Based — Primary) ─────────────
    path('request-password-reset/', RequestPasswordResetOTPView.as_view(), name='request-password-reset'),
    path('verify-otp-reset/', VerifyOTPResetPasswordView.as_view(), name='verify-otp-reset'),

    # ── Security & Privacy (GDPR) Endpoints ───────────────────────
    path('login-history/', LoginHistoryView.as_view(), name='login-history'),
    path('data-export/', DataExportView.as_view(), name='data-export'),
    path('request-deletion/', DataDeletionRequestView.as_view(), name='request-deletion'),
]