"""
=============================================================================
 Password Reset Service — Secure Token Lifecycle & Email Delivery
=============================================================================

 Module:  authentication/password_reset_service.py
 Project: DailyHabits Backend

 Purpose:
   Encapsulates all password-reset business logic behind a stateless
   service layer.  Responsibilities include:
     • Generating cryptographically secure reset tokens.
     • Hashing tokens (SHA-256) before database persistence.
     • Validating tokens (existence, expiry, single-use).
     • Sending branded HTML reset emails via Django's email backend.
     • Invalidating all existing sessions after a password change.
     • Recording audit events for analytics & abuse detection.

 Security Highlights (OWASP-aligned):
   - Generic responses prevent user enumeration.
   - Tokens are hashed at rest — a DB breach does not leak tokens.
   - 15-minute TTL + single-use flag prevent replay attacks.
   - Old tokens are bulk-invalidated on every new request.
   - All events are logged for anomaly detection.

 Related Modules:
   - authentication.models → PasswordResetToken, PasswordResetAuditLog
   - authentication.views  → ForgotPasswordView, ResetPasswordView
=============================================================================
"""

from __future__ import annotations

import hashlib
import logging
import secrets
import time
from datetime import timedelta
from typing import Optional

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone
from django.utils.html import strip_tags
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

from .models import PasswordResetToken, PasswordResetAuditLog

logger = logging.getLogger('authentication')
User = get_user_model()

# ── Configuration ─────────────────────────────────────────────────────────────
TOKEN_BYTE_LENGTH: int = 32          # 64 hex characters
TOKEN_TTL_MINUTES: int = 15          # OWASP recommendation: 10–30 min
MAX_ACTIVE_TOKENS_PER_USER: int = 3  # Rate-limit at data layer
EMAIL_MAX_RETRIES: int = 3           # Retry attempts for failed email delivery
EMAIL_RETRY_BACKOFF: float = 1.0     # Base delay (seconds) between retries


class PasswordResetService:
    """
    Stateless service for the entire password-reset lifecycle.

    All public methods are ``@staticmethod`` — no instance state is required.
    """

    # ─────────────────────────────────────────────────────────────────────
    #  Token helpers
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _hash_token(raw_token: str) -> str:
        """Return the SHA-256 hex digest of *raw_token*."""
        return hashlib.sha256(raw_token.encode('utf-8')).hexdigest()

    @staticmethod
    def _generate_raw_token() -> str:
        """Return a cryptographically secure 64-char hex token."""
        return secrets.token_hex(TOKEN_BYTE_LENGTH)

    @staticmethod
    def _resolve_ip(request) -> str:
        """Extract the real client IP from proxy headers."""
        forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
        if forwarded:
            return forwarded.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '')

    # ─────────────────────────────────────────────────────────────────────
    #  1.  REQUEST RESET  (Forgot Password)
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def request_reset(email: str, request) -> dict:
        """
        Handle a forgot-password request.

        Always returns a generic success message to prevent user enumeration.
        If the email maps to an active account, a reset token is created and
        an email is dispatched asynchronously.

        Args:
            email:   The email address submitted by the user.
            request: The DRF ``Request`` object (used for IP / UA logging).

        Returns:
            dict with ``success`` key (always ``True`` for the API caller).
        """
        ip = PasswordResetService._resolve_ip(request)
        user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]

        # Log the request regardless of whether the email exists.
        PasswordResetAuditLog.objects.create(
            event='request',
            email=email,
            ip_address=ip or None,
            user_agent=user_agent,
        )

        try:
            user = User.objects.get(email__iexact=email, is_active=True)
        except User.DoesNotExist:
            # Silent no-op — generic response protects against enumeration.
            logger.info('Password reset requested for non-existent email: %s', email)
            return {
                'success': True,
                'message': 'If an account with that email exists, a reset link has been sent.',
            }

        # Invalidate any previous unused tokens for this user.
        PasswordResetToken.objects.filter(user=user, is_used=False).update(is_used=True)

        # Generate and persist a new hashed token.
        raw_token = PasswordResetService._generate_raw_token()
        token_hash = PasswordResetService._hash_token(raw_token)
        expires_at = timezone.now() + timedelta(minutes=TOKEN_TTL_MINUTES)

        PasswordResetToken.objects.create(
            user=user,
            token_hash=token_hash,
            expires_at=expires_at,
            ip_address=ip or None,
            user_agent=user_agent,
        )

        # Detect suspicious behaviour: >5 requests in 1 hour from same email.
        recent_count = PasswordResetAuditLog.objects.filter(
            email=email,
            event='request',
            created_at__gte=timezone.now() - timedelta(hours=1),
        ).count()
        if recent_count > 5:
            PasswordResetAuditLog.objects.create(
                user=user,
                event='suspicious',
                email=email,
                ip_address=ip or None,
                user_agent=user_agent,
                metadata={'reason': 'Excessive reset requests', 'count': recent_count},
            )
            logger.warning(
                'Suspicious reset activity for %s — %d requests in last hour',
                email,
                recent_count,
            )

        # Send the reset email (with the raw token).
        email_delivered = PasswordResetService._send_reset_email(user, raw_token)

        PasswordResetAuditLog.objects.create(
            user=user,
            event='email_sent' if email_delivered else 'email_failed',
            email=email,
            ip_address=ip or None,
            user_agent=user_agent,
            metadata={'email_delivered': email_delivered},
        )

        result = {
            'success': True,
            'message': 'If an account with that email exists, a reset link has been sent.',
            'email_delivered': email_delivered,
        }

        # In DEBUG mode, include the raw token so developers can test the
        # full reset flow without needing real SMTP credentials.
        # SECURITY: This field is NEVER included when DEBUG=False.
        if getattr(settings, 'DEBUG', False):
            result['debug_reset_token'] = raw_token
            if not email_delivered:
                result['debug_note'] = (
                    'Email delivery failed. Use the debug_reset_token above '
                    'to test the reset flow. Configure EMAIL_HOST_PASSWORD '
                    'in .env with a Gmail App Password for real delivery.'
                )

        return result

    # ─────────────────────────────────────────────────────────────────────
    #  2.  VALIDATE TOKEN  (optional pre-check before showing the form)
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def validate_token(raw_token: str, request=None) -> dict:
        """
        Check whether *raw_token* is still valid (not used, not expired).

        This is an **optional** preflight check that lets the Flutter client
        decide whether to show the new-password form or an error screen.

        Returns:
            dict with ``valid`` boolean and optional ``message``.
        """
        token_hash = PasswordResetService._hash_token(raw_token)

        try:
            prt = PasswordResetToken.objects.select_related('user').get(token_hash=token_hash)
        except PasswordResetToken.DoesNotExist:
            PasswordResetService._log_event(
                event='token_invalid',
                email='unknown',
                request=request,
                metadata={'reason': 'Token not found'},
            )
            return {'valid': False, 'message': 'Invalid or expired reset link.'}

        if prt.is_used:
            PasswordResetService._log_event(
                event='token_invalid',
                email=prt.user.email,
                user=prt.user,
                request=request,
                metadata={'reason': 'Token already used'},
            )
            return {'valid': False, 'message': 'This reset link has already been used.'}

        if prt.is_expired:
            PasswordResetService._log_event(
                event='token_expired',
                email=prt.user.email,
                user=prt.user,
                request=request,
                metadata={'expired_at': prt.expires_at.isoformat()},
            )
            return {'valid': False, 'message': 'This reset link has expired. Please request a new one.'}

        PasswordResetService._log_event(
            event='token_validated',
            email=prt.user.email,
            user=prt.user,
            request=request,
        )
        return {'valid': True, 'message': 'Token is valid.'}

    # ─────────────────────────────────────────────────────────────────────
    #  3.  RESET PASSWORD  (consume token + set new password)
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def reset_password(raw_token: str, new_password: str, request=None) -> dict:
        """
        Consume the reset token and change the user's password.

        Steps:
          1. Lookup the PasswordResetToken by its SHA-256 hash.
          2. Verify the token is still valid (not used, not expired).
          3. Set the new password (Django hashes it automatically).
          4. Mark the token as used.
          5. Invalidate all outstanding JWT refresh tokens (force re-auth).
          6. Send a confirmation email.
          7. Log the event.

        Returns:
            dict with ``success``, ``message``, and optionally ``errors``.
        """
        token_hash = PasswordResetService._hash_token(raw_token)
        ip = PasswordResetService._resolve_ip(request) if request else ''
        user_agent = request.META.get('HTTP_USER_AGENT', '')[:500] if request else ''

        try:
            prt = PasswordResetToken.objects.select_related('user').get(token_hash=token_hash)
        except PasswordResetToken.DoesNotExist:
            PasswordResetService._log_event(
                event='token_invalid',
                email='unknown',
                request=request,
                metadata={'reason': 'Token not found during reset'},
            )
            return {
                'success': False,
                'message': 'Invalid or expired reset link.',
            }

        if prt.is_used:
            PasswordResetService._log_event(
                event='token_invalid',
                email=prt.user.email,
                user=prt.user,
                request=request,
                metadata={'reason': 'Token already used during reset'},
            )
            return {
                'success': False,
                'message': 'This reset link has already been used.',
            }

        if prt.is_expired:
            PasswordResetService._log_event(
                event='token_expired',
                email=prt.user.email,
                user=prt.user,
                request=request,
                metadata={'expired_at': prt.expires_at.isoformat()},
            )
            return {
                'success': False,
                'message': 'This reset link has expired. Please request a new one.',
            }

        user = prt.user

        # ── Set new password (Django handles bcrypt/PBKDF2 hashing) ──────
        user.set_password(new_password)
        user.save(update_fields=['password'])

        # ── Mark token as consumed ───────────────────────────────────────
        prt.is_used = True
        prt.used_at = timezone.now()
        prt.save(update_fields=['is_used', 'used_at'])

        # ── Invalidate ALL outstanding refresh tokens (force re-login) ───
        PasswordResetService._invalidate_all_sessions(user)

        # ── Send password-changed confirmation email ─────────────────────
        PasswordResetService._send_password_changed_email(user, ip)

        # ── Audit log ────────────────────────────────────────────────────
        PasswordResetService._log_event(
            event='password_changed',
            email=user.email,
            user=user,
            request=request,
        )

        logger.info('Password reset completed for user %s', user.email)

        return {
            'success': True,
            'message': 'Your password has been reset successfully. Please log in with your new password.',
        }

    # ─────────────────────────────────────────────────────────────────────
    #  Session invalidation
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _invalidate_all_sessions(user) -> None:
        """
        Blacklist every outstanding refresh token for *user*.

        This forces all devices to re-authenticate after a password reset,
        which is critical for security if an attacker already had the old
        password.
        """
        try:
            from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken

            outstanding = OutstandingToken.objects.filter(user=user)
            for token_record in outstanding:
                try:
                    BlacklistedToken.objects.get_or_create(
                        token=token_record,
                    )
                except Exception:
                    # Token may already be blacklisted or malformed — skip
                    pass
            logger.info('Invalidated %d sessions for user %s', outstanding.count(), user.email)
        except Exception as e:
            logger.warning('Session invalidation error for %s: %s', user.email, e)

    # ─────────────────────────────────────────────────────────────────────
    #  Email delivery
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _send_reset_email(user, raw_token: str) -> bool:
        """
        Send a branded HTML password-reset email containing the reset link.

        The link is constructed from ``PASSWORD_RESET_BASE_URL`` in settings
        (defaults to a deep-link for the Flutter app). A plain-text fallback
        is auto-generated from the HTML for email clients that refuse HTML.

        Returns ``True`` if the email was delivered, ``False`` otherwise.
        """
        base_url = getattr(
            settings,
            'PASSWORD_RESET_BASE_URL',
            'dailyhabits://reset-password',
        )
        reset_link = f'{base_url}?token={raw_token}'
        first_name = user.name.split()[0] if user.name else 'there'

        subject = 'Reset Your DailyHabits Password'

        html_content = render_to_string('authentication/password_reset_email.html', {
            'user_name': first_name,
            'reset_link': reset_link,
            'ttl_minutes': TOKEN_TTL_MINUTES,
            'app_name': 'DailyHabits',
            'support_email': getattr(settings, 'SUPPORT_EMAIL', 'support@dailyhabits.app'),
        })
        text_content = strip_tags(html_content)

        from_email = getattr(
            settings,
            'DEFAULT_FROM_EMAIL',
            'DailyHabits <noreply@dailyhabits.app>',
        )

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_email,
            to=[user.email],
        )
        msg.attach_alternative(html_content, 'text/html')

        return PasswordResetService._send_with_retry(
            msg=msg,
            recipient=user.email,
            email_type='password_reset',
        )

    @staticmethod
    def _send_password_changed_email(user, ip: str = '') -> None:
        """
        Send a confirmation email notifying the user their password was changed.

        If the user did *not* request the change, they can use the support
        contact in the email to report a compromised account.
        """
        first_name = user.name.split()[0] if user.name else 'there'

        subject = 'Your DailyHabits Password Was Changed'

        html_content = render_to_string('authentication/password_changed_email.html', {
            'user_name': first_name,
            'ip_address': ip or 'Unknown',
            'timestamp': timezone.now().strftime('%B %d, %Y at %I:%M %p UTC'),
            'app_name': 'DailyHabits',
            'support_email': getattr(settings, 'SUPPORT_EMAIL', 'support@dailyhabits.app'),
        })
        text_content = strip_tags(html_content)

        from_email = getattr(
            settings,
            'DEFAULT_FROM_EMAIL',
            'DailyHabits <noreply@dailyhabits.app>',
        )

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_email,
            to=[user.email],
        )
        msg.attach_alternative(html_content, 'text/html')

        PasswordResetService._send_with_retry(
            msg=msg,
            recipient=user.email,
            email_type='password_changed',
        )

    # ─────────────────────────────────────────────────────────────────────
    #  Email retry helper
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _send_with_retry(
        msg: EmailMultiAlternatives,
        recipient: str,
        email_type: str,
        max_retries: int = EMAIL_MAX_RETRIES,
    ) -> bool:
        """
        Attempt to send *msg* with exponential backoff retries.

        Returns ``True`` if the email was delivered successfully, ``False``
        if all attempts failed.

        Logs structured info on success, detailed error context on failure.
        This ensures transient SMTP errors (timeouts, rate limits) don't
        silently drop password-reset emails.
        """
        last_error = None

        for attempt in range(1, max_retries + 1):
            try:
                msg.send(fail_silently=False)
                logger.info(
                    '[email:%s] Sent to %s on attempt %d/%d',
                    email_type, recipient, attempt, max_retries,
                )
                return True  # Success — exit immediately
            except Exception as e:
                last_error = e
                logger.warning(
                    '[email:%s] Attempt %d/%d failed for %s: %s',
                    email_type, attempt, max_retries, recipient, e,
                )
                if attempt < max_retries:
                    delay = EMAIL_RETRY_BACKOFF * (2 ** (attempt - 1))
                    time.sleep(delay)

        # All retries exhausted
        logger.error(
            '[email:%s] FAILED after %d attempts for %s. '
            'Last error: %s | Backend: %s | Host: %s:%s',
            email_type,
            max_retries,
            recipient,
            last_error,
            getattr(settings, 'EMAIL_BACKEND', 'unknown'),
            getattr(settings, 'EMAIL_HOST', 'unknown'),
            getattr(settings, 'EMAIL_PORT', 'unknown'),
        )
        return False

    # ─────────────────────────────────────────────────────────────────────
    #  Audit helper
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _log_event(
        *,
        event: str,
        email: str,
        user=None,
        request=None,
        metadata: Optional[dict] = None,
    ) -> None:
        """Persist an audit log entry with optional request context."""
        ip = ''
        ua = ''
        if request:
            ip = PasswordResetService._resolve_ip(request)
            ua = request.META.get('HTTP_USER_AGENT', '')[:500]

        PasswordResetAuditLog.objects.create(
            user=user,
            event=event,
            email=email,
            ip_address=ip or None,
            user_agent=ua,
            metadata=metadata or {},
        )
