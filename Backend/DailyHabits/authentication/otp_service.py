"""
=============================================================================
 OTP Password Reset Service — Secure OTP Lifecycle & Email Delivery
=============================================================================

 Module:  authentication/otp_service.py
 Project: DailyHabits Backend

 Purpose:
   Encapsulates all OTP-based password-reset business logic behind a
   stateless service layer.  Responsibilities include:
     • Generating cryptographically secure 6-digit OTPs.
     • Hashing OTPs (SHA-256) before database persistence.
     • Sending branded HTML OTP emails via Django's email backend.
     • Validating OTPs (existence, expiry, single-use, attempt limits).
     • Resetting user passwords after successful OTP validation.
     • Invalidating all existing sessions after a password change.
     • Recording audit events for analytics & abuse detection.

 Security Highlights (OWASP-aligned):
   - Generic responses prevent user enumeration.
   - OTPs are hashed at rest — a DB breach does not leak OTPs.
   - 10-minute TTL + single-use flag prevent replay attacks.
   - Max 5 verification attempts prevent brute-force on 6-digit space.
   - Old OTPs are bulk-invalidated on every new request.
   - All events are logged for anomaly detection.

 Related Modules:
   - authentication.models → PasswordResetOTP, PasswordResetAuditLog
   - authentication.views  → RequestOTPView, VerifyOTPResetView
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

from .models import PasswordResetOTP, PasswordResetAuditLog

logger = logging.getLogger('authentication')
User = get_user_model()

# ── Configuration ─────────────────────────────────────────────────────────────
OTP_LENGTH: int = 6                  # 6-digit numeric OTP
OTP_TTL_MINUTES: int = 10            # OTP valid for 10 minutes
OTP_MAX_ATTEMPTS: int = 5            # Max failed verifications per OTP
EMAIL_MAX_RETRIES: int = 3           # Retry attempts for failed email delivery
EMAIL_RETRY_BACKOFF: float = 1.0     # Base delay (seconds) between retries


class OTPResetService:
    """
    Stateless service for the entire OTP-based password-reset lifecycle.

    All public methods are ``@staticmethod`` — no instance state is required.
    """

    # ─────────────────────────────────────────────────────────────────────
    #  OTP helpers
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _hash_otp(raw_otp: str) -> str:
        """Return the SHA-256 hex digest of *raw_otp*."""
        return hashlib.sha256(raw_otp.encode('utf-8')).hexdigest()

    @staticmethod
    def _generate_otp() -> str:
        """Return a cryptographically secure 6-digit numeric OTP."""
        return str(secrets.randbelow(900000) + 100000)

    @staticmethod
    def _resolve_ip(request) -> str:
        """Extract the real client IP from proxy headers."""
        forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
        if forwarded:
            return forwarded.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '')

    # ─────────────────────────────────────────────────────────────────────
    #  1.  REQUEST OTP  (Forgot Password)
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def request_otp(email: str, request) -> dict:
        """
        Handle a forgot-password OTP request.

        Always returns a generic success message to prevent user enumeration.
        If the email maps to an active account, a 6-digit OTP is created and
        emailed.

        Args:
            email:   The email address submitted by the user.
            request: The DRF ``Request`` object (used for IP / UA logging).

        Returns:
            dict with ``success`` key (always ``True`` for the API caller).
        """
        ip = OTPResetService._resolve_ip(request)
        user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]

        # Log the request regardless of whether the email exists.
        OTPResetService._log_event(
            event='otp_request',
            email=email,
            request=request,
        )

        try:
            user = User.objects.get(email__iexact=email, is_active=True)
        except User.DoesNotExist:
            # Silent no-op — generic response protects against enumeration.
            logger.info('OTP requested for non-existent email: %s', email)
            return {
                'success': True,
                'message': 'If an account with that email exists, you will receive an OTP shortly.',
            }

        # Invalidate any previous unused OTPs for this user.
        PasswordResetOTP.objects.filter(user=user, used=False).update(used=True)

        # Generate and persist a new hashed OTP.
        raw_otp = OTPResetService._generate_otp()
        otp_hash = OTPResetService._hash_otp(raw_otp)
        expires_at = timezone.now() + timedelta(minutes=OTP_TTL_MINUTES)

        PasswordResetOTP.objects.create(
            user=user,
            otp_hash=otp_hash,
            expires_at=expires_at,
            ip_address=ip or None,
            user_agent=user_agent,
        )

        # Detect suspicious behaviour: >5 requests in 1 hour from same email.
        recent_count = PasswordResetAuditLog.objects.filter(
            email=email,
            event='otp_request',
            created_at__gte=timezone.now() - timedelta(hours=1),
        ).count()
        if recent_count > 5:
            OTPResetService._log_event(
                event='suspicious',
                email=email,
                user=user,
                request=request,
                metadata={'reason': 'Excessive OTP requests', 'count': recent_count},
            )
            logger.warning(
                'Suspicious OTP activity for %s — %d requests in last hour',
                email,
                recent_count,
            )

        # Send the OTP email.
        email_delivered = OTPResetService._send_otp_email(user, raw_otp)

        OTPResetService._log_event(
            event='otp_sent' if email_delivered else 'otp_failed',
            email=email,
            user=user,
            request=request,
            metadata={'email_delivered': email_delivered},
        )

        result: dict = {
            'success': True,
            'message': 'If an account with that email exists, you will receive an OTP shortly.',
            'otp_ttl_seconds': OTP_TTL_MINUTES * 60,
        }

        # In DEBUG mode, include the raw OTP for development testing.
        # SECURITY: This field is NEVER included when DEBUG=False.
        if getattr(settings, 'DEBUG', False):
            result['debug_otp'] = raw_otp
            if not email_delivered:
                result['debug_note'] = (
                    'Email delivery failed. Use the debug_otp above '
                    'to test the reset flow.'
                )

        return result

    # ─────────────────────────────────────────────────────────────────────
    #  2.  VERIFY OTP & RESET PASSWORD
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def verify_and_reset(
        email: str,
        raw_otp: str,
        new_password: str,
        request=None,
    ) -> dict:
        """
        Verify the OTP and reset the user's password in one atomic operation.

        Steps:
          1. Look up user by email.
          2. Find the most recent valid OTP for that user.
          3. Verify the OTP hash matches.
          4. Set the new password (Django hashes it automatically).
          5. Mark OTP as used.
          6. Invalidate all outstanding JWT refresh tokens (force re-auth).
          7. Send a password-changed confirmation email.
          8. Log the event.

        Returns:
            dict with ``success``, ``message``, and optionally ``errors``.
        """
        ip = OTPResetService._resolve_ip(request) if request else ''

        # ── Step 1: Look up the user ─────────────────────────────────
        try:
            user = User.objects.get(email__iexact=email, is_active=True)
        except User.DoesNotExist:
            OTPResetService._log_event(
                event='otp_invalid',
                email=email,
                request=request,
                metadata={'reason': 'User not found'},
            )
            return {
                'success': False,
                'message': 'Invalid OTP or email address.',
            }

        # ── Step 2: Find the most recent active OTP for the user ─────
        try:
            otp_record = PasswordResetOTP.objects.filter(
                user=user,
                used=False,
            ).latest('created_at')
        except PasswordResetOTP.DoesNotExist:
            OTPResetService._log_event(
                event='otp_invalid',
                email=email,
                user=user,
                request=request,
                metadata={'reason': 'No active OTP found'},
            )
            return {
                'success': False,
                'message': 'No active OTP found. Please request a new one.',
            }

        # ── Check if expired ─────────────────────────────────────────
        if otp_record.is_expired:
            OTPResetService._log_event(
                event='otp_expired',
                email=email,
                user=user,
                request=request,
                metadata={'expired_at': otp_record.expires_at.isoformat()},
            )
            return {
                'success': False,
                'message': 'OTP has expired. Please request a new one.',
            }

        # ── Check if locked (too many attempts) ─────────────────────
        if otp_record.is_locked:
            OTPResetService._log_event(
                event='otp_locked',
                email=email,
                user=user,
                request=request,
                metadata={'attempts': otp_record.attempts},
            )
            return {
                'success': False,
                'message': 'Too many failed attempts. Please request a new OTP.',
            }

        # ── Step 3: Verify OTP hash ──────────────────────────────────
        submitted_hash = OTPResetService._hash_otp(raw_otp)
        if submitted_hash != otp_record.otp_hash:
            # Increment attempt counter
            otp_record.attempts += 1
            otp_record.save(update_fields=['attempts'])

            remaining = OTP_MAX_ATTEMPTS - otp_record.attempts
            OTPResetService._log_event(
                event='otp_invalid',
                email=email,
                user=user,
                request=request,
                metadata={
                    'reason': 'OTP mismatch',
                    'attempts': otp_record.attempts,
                    'remaining': remaining,
                },
            )

            if remaining <= 0:
                return {
                    'success': False,
                    'message': 'Too many failed attempts. Please request a new OTP.',
                }

            return {
                'success': False,
                'message': f'Invalid OTP. {remaining} attempt{"s" if remaining != 1 else ""} remaining.',
                'attempts_remaining': remaining,
            }

        # ── Step 4: OTP is valid — set new password ──────────────────
        user.set_password(new_password)
        user.save(update_fields=['password'])

        # ── Step 5: Mark OTP as consumed ─────────────────────────────
        otp_record.used = True
        otp_record.used_at = timezone.now()
        otp_record.save(update_fields=['used', 'used_at'])

        # ── Step 6: Invalidate ALL outstanding refresh tokens ────────
        OTPResetService._invalidate_all_sessions(user)

        # ── Step 7: Send password-changed confirmation email ─────────
        OTPResetService._send_password_changed_email(user, ip)

        # ── Step 8: Audit log ────────────────────────────────────────
        OTPResetService._log_event(
            event='password_changed',
            email=user.email,
            user=user,
            request=request,
        )

        logger.info('OTP password reset completed for user %s', user.email)

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

        This forces all devices to re-authenticate after a password reset.
        """
        try:
            from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken

            outstanding = OutstandingToken.objects.filter(user=user)
            for token_record in outstanding:
                try:
                    BlacklistedToken.objects.get_or_create(token=token_record)
                except Exception:
                    pass
            logger.info('Invalidated %d sessions for user %s', outstanding.count(), user.email)
        except Exception as e:
            logger.warning('Session invalidation error for %s: %s', user.email, e)

    # ─────────────────────────────────────────────────────────────────────
    #  Email delivery
    # ─────────────────────────────────────────────────────────────────────

    @staticmethod
    def _send_otp_email(user, raw_otp: str) -> bool:
        """
        Send a branded HTML email containing the 6-digit OTP.

        Returns ``True`` if delivered, ``False`` otherwise.
        """
        first_name = user.name.split()[0] if user.name else 'there'

        subject = 'Your DailyHabits Password Reset Code'

        html_content = render_to_string('authentication/otp_email.html', {
            'user_name': first_name,
            'otp_code': raw_otp,
            'ttl_minutes': OTP_TTL_MINUTES,
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

        return OTPResetService._send_with_retry(
            msg=msg,
            recipient=user.email,
            email_type='otp_reset',
        )

    @staticmethod
    def _send_password_changed_email(user, ip: str = '') -> bool:
        """
        Send a confirmation email notifying the user their password was changed.
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

        return OTPResetService._send_with_retry(
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

        Returns ``True`` if delivered, ``False`` if all attempts failed.
        """
        last_error = None

        for attempt in range(1, max_retries + 1):
            try:
                msg.send(fail_silently=False)
                logger.info(
                    '[email:%s] Sent to %s on attempt %d/%d',
                    email_type, recipient, attempt, max_retries,
                )
                return True
            except Exception as e:
                last_error = e
                logger.warning(
                    '[email:%s] Attempt %d/%d failed for %s: %s',
                    email_type, attempt, max_retries, recipient, e,
                )
                if attempt < max_retries:
                    delay = EMAIL_RETRY_BACKOFF * (2 ** (attempt - 1))
                    time.sleep(delay)

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
            ip = OTPResetService._resolve_ip(request)
            ua = request.META.get('HTTP_USER_AGENT', '')[:500]

        PasswordResetAuditLog.objects.create(
            user=user,
            event=event,
            email=email,
            ip_address=ip or None,
            user_agent=ua,
            metadata=metadata or {},
        )
