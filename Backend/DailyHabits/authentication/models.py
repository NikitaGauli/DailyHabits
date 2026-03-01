"""
=============================================================================
 Authentication Models — Custom User, Login Tracking & Data Deletion
=============================================================================

 Module:  authentication/models.py
 Project: DailyHabits Backend

 Purpose:
   Defines the project's custom User model (email-based authentication),
   a LoginActivity audit trail for security monitoring, and a
   DataDeletionRequest workflow for GDPR-compliant account removal.

 Design Decisions:
   - Email is the sole unique identifier (no username field).
   - AbstractBaseUser + PermissionsMixin give full control over auth
     while retaining Django's permission framework.
   - Soft-state tracking fields (current_streak, total_habits_completed)
     are denormalized onto the User for fast dashboard reads.

 Related Modules:
   - authentication.managers  → UserManager (create_user / create_superuser)
   - authentication.views     → Registration, Login, Profile, GDPR endpoints
   - authentication.serializers → DRF serializers for the User model
=============================================================================
"""

from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from .managers import UserManager


# =============================================================================
#  CUSTOM USER MODEL
# =============================================================================

class User(AbstractBaseUser, PermissionsMixin):
    """
    Custom User Model — email-based authentication.

    Replaces Django's default User to use *email* as the unique login
    identifier rather than a username.  Includes denormalized habit-
    tracking counters for performant dashboard rendering.
    """

    # ── Auth Provider Choices ────────────────────────────────────────
    AUTH_PROVIDER_CHOICES = [
        ('email', 'Email'),
        ('google', 'Google'),
    ]

    # ── Identity Fields ──────────────────────────────────────────────
    email = models.EmailField(
        max_length=255,
        unique=True,
        db_index=True,
        verbose_name='Email Address'
    )
    name = models.CharField(
        max_length=255,
        verbose_name='Full Name'
    )

    # ── OAuth Fields ─────────────────────────────────────────────────
    google_id = models.CharField(
        max_length=255,
        unique=True,
        null=True,
        blank=True,
        db_index=True,
        verbose_name='Google Subject ID',
        help_text='Google OAuth `sub` claim — unique, stable identifier.',
    )
    auth_provider = models.CharField(
        max_length=20,
        choices=AUTH_PROVIDER_CHOICES,
        default='email',
        verbose_name='Primary Auth Provider',
        help_text='How the user originally registered.',
    )

    # ── Profile Fields ───────────────────────────────────────────────
    profile_image = models.URLField(
        max_length=500,
        blank=True,
        null=True,
        verbose_name='Profile Image URL'
    )

    # ── Account Status Flags ──────────────────────────────────────────
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)

    # ── Audit Timestamps ─────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_login = models.DateTimeField(null=True, blank=True)

    # ── Denormalized Habit Stats (cached for fast dashboard reads) ────
    current_streak = models.IntegerField(default=0)
    total_habits_completed = models.IntegerField(default=0)

    # ── Manager Configuration ────────────────────────────────────────
    objects = UserManager()

    # email is the login credential; name is required at signup
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['name']
    
    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        ordering = ['-created_at']
    
    def __str__(self):
        """String representation — returns the user's email address."""
        return self.email

    def get_full_name(self):
        """Return the user's full display name."""
        return self.name

    def get_short_name(self):
        """Return only the first name (or email as fallback)."""
        return self.name.split()[0] if self.name else self.email


# =============================================================================
#  LOGIN ACTIVITY — Security Audit Trail
# =============================================================================

class LoginActivity(models.Model):
    """
    Records every login attempt (successful or failed) for security auditing.

    Captured data includes IP address, user-agent string, device type,
    and geographic location (when available).  Used by the
    LoginHistoryView to expose recent activity to end-users.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='login_activities'
    )
    id = models.AutoField(primary_key=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')
    device_type = models.CharField(max_length=50, blank=True, default='unknown')
    location = models.CharField(max_length=255, blank=True, default='')
    login_at = models.DateTimeField(auto_now_add=True)
    was_successful = models.BooleanField(default=True)

    class Meta:
        db_table = 'login_activities'
        ordering = ['-login_at']
        verbose_name_plural = 'Login Activities'

    def __str__(self):
        """Human-readable representation showing email, status and timestamp."""
        status_str = 'success' if self.was_successful else 'failed'
        return f'{self.user.email} - {status_str} - {self.login_at}'


# =============================================================================
#  DATA DELETION REQUEST — GDPR Compliance
# =============================================================================

class DataDeletionRequest(models.Model):
    """
    Tracks GDPR / right-to-erasure data-deletion requests.

    Workflow: pending → processing → completed | cancelled.
    The admin reviews pending requests and processes them within
    the legally required timeframe (typically 30 days).
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='deletion_requests'
    )
    id = models.AutoField(primary_key=True)
    reason = models.TextField(blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'data_deletion_requests'
        ordering = ['-requested_at']

    def __str__(self):
        return f'{self.user.email} - {self.status} - {self.requested_at}'


# =============================================================================
#  PASSWORD RESET OTP — Secure, Single-Use, Time-Limited
# =============================================================================

class PasswordResetOTP(models.Model):
    """
    Stores hashed password-reset OTPs with single-use and TTL semantics.

    Design:
      - A 6-digit numeric OTP is generated, hashed (SHA-256), and stored.
      - Only the hash is persisted — a DB breach does not leak usable OTPs.
      - ``used`` ensures single-use: once consumed, the OTP cannot be replayed.
      - ``expires_at`` enforces a strict time-limited window (default 10 min).
      - ``attempts`` tracks failed verification tries; capped at 5 to prevent
        brute-force attacks on the 6-digit space.
      - Old unused OTPs are bulk-invalidated when a new request is made.

    Security:
      - OTPs are 6-digit strings produced by ``secrets.randbelow(900000)+100000``.
      - SHA-256 hashing prevents reverse-lookup if the database is compromised.
      - Max 5 verification attempts per OTP before auto-invalidation.
    """
    MAX_ATTEMPTS = 5
    TTL_MINUTES = 10

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='password_reset_otps',
    )
    otp_hash = models.CharField(
        max_length=128,
        db_index=True,
        help_text='SHA-256 hash of the 6-digit OTP.',
    )
    used = models.BooleanField(default=False)
    attempts = models.PositiveIntegerField(
        default=0,
        help_text='Number of failed verification attempts.',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')

    class Meta:
        db_table = 'password_reset_otps'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'used'], name='idx_pro_user_used'),
            models.Index(fields=['expires_at'], name='idx_pro_expires'),
        ]

    def __str__(self):
        status = 'used' if self.used else ('expired' if self.is_expired else 'active')
        return f'{self.user.email} — {status} — {self.created_at:%Y-%m-%d %H:%M}'

    @property
    def is_expired(self):
        """Return True if the OTP's TTL has elapsed."""
        from django.utils import timezone
        return timezone.now() >= self.expires_at

    @property
    def is_locked(self):
        """Return True if max verification attempts have been exceeded."""
        return self.attempts >= self.MAX_ATTEMPTS

    @property
    def is_valid(self):
        """Return True only if the OTP is unused, not expired, and not locked."""
        return not self.used and not self.is_expired and not self.is_locked


# =============================================================================
#  PASSWORD RESET TOKEN — Secure, Single-Use, Time-Limited (Legacy)
# =============================================================================

class PasswordResetToken(models.Model):
    """
    Stores hashed password-reset tokens with single-use and TTL semantics.

    Design:
      - The raw token is sent to the user via email; only a SHA-256 hash
        is persisted in the database, preventing token theft from a DB dump.
      - ``is_used`` ensures single-use: once consumed, the token cannot be
        replayed.
      - ``expires_at`` enforces a strict 15-minute TTL.
      - ``ip_address`` / ``user_agent`` enable abuse forensics.

    Security:
      - Tokens are 64-character hex strings produced by ``secrets.token_hex(32)``.
      - Hashing prevents reverse-lookup if the database is compromised.
      - Old unused tokens are invalidated when a new request is made.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='password_reset_tokens',
    )
    token_hash = models.CharField(
        max_length=128,
        unique=True,
        db_index=True,
        help_text='SHA-256 hash of the raw reset token.',
    )
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')

    class Meta:
        db_table = 'password_reset_tokens'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['token_hash'], name='idx_prt_token_hash'),
            models.Index(fields=['user', 'is_used'], name='idx_prt_user_used'),
        ]

    def __str__(self):
        status = 'used' if self.is_used else ('expired' if self.is_expired else 'active')
        return f'{self.user.email} — {status} — {self.created_at:%Y-%m-%d %H:%M}'

    @property
    def is_expired(self):
        """Return True if the token's TTL has elapsed."""
        from django.utils import timezone
        return timezone.now() >= self.expires_at

    @property
    def is_valid(self):
        """Return True only if the token is unused and not expired."""
        return not self.is_used and not self.is_expired


# =============================================================================
#  PASSWORD RESET ANALYTICS — Audit & Anomaly Detection
# =============================================================================

class PasswordResetAuditLog(models.Model):
    """
    Immutable audit log for password-reset events.

    Captures every significant event in the reset lifecycle so that
    suspicious patterns (e.g. rapid-fire requests from different IPs)
    can be detected and investigated.
    """
    EVENT_CHOICES = [
        ('request', 'Reset Requested'),
        ('otp_request', 'OTP Requested'),
        ('otp_sent', 'OTP Email Sent'),
        ('otp_failed', 'OTP Email Failed'),
        ('otp_verified', 'OTP Verified'),
        ('otp_invalid', 'Invalid OTP Attempt'),
        ('otp_expired', 'OTP Expired'),
        ('otp_locked', 'OTP Locked (Max Attempts)'),
        ('email_sent', 'Email Sent'),
        ('email_failed', 'Email Delivery Failed'),
        ('token_validated', 'Token Validated'),
        ('password_changed', 'Password Changed'),
        ('token_expired', 'Token Expired'),
        ('token_invalid', 'Invalid Token Attempt'),
        ('rate_limited', 'Rate Limited'),
        ('suspicious', 'Suspicious Activity'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='password_reset_audit_logs',
    )
    event = models.CharField(max_length=20, choices=EVENT_CHOICES)
    email = models.EmailField(help_text='Email address used in the request.')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')
    metadata = models.JSONField(
        default=dict,
        blank=True,
        help_text='Arbitrary JSON payload with event-specific details.',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'password_reset_audit_logs'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.email} — {self.event} — {self.created_at:%Y-%m-%d %H:%M}'