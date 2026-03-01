"""
Settings App Models - User Preferences, Privacy, Security, Exports & Support
=============================================================================

Production-grade settings infrastructure for the DailyHabits platform.
Each model maps to a distinct feature area within the Settings module:

- **UserSettings**       - Appearance, daily summary, motivational quotes,
  quiet hours, timezone, font size, language, advanced preferences.
- **PrivacySettings**    - Account visibility, data-sharing controls,
  habit privacy defaults, and friend-request gating.
- **SecuritySettings**   - Two-factor authentication readiness,
  biometric lock, session timeout, and re-auth policies.
- **LoginSession**       - Active device/session registry for
  manage your devices and remote logout.
- **SettingsAuditLog**   - Immutable audit trail for every settings
  mutation (security, privacy, profile changes).
- **ExportRequest**      - User data export lifecycle tracking.
- **PrivacyPolicy**      - Versioned legal documents.
- **FAQ**                - Admin-managed help-centre entries.
- **SupportTicket**      - User support workflow with admin response.

NO Firebase Cloud Messaging is used anywhere.  All notifications and
reminders are delivered via server-side scheduling and the in-app
notification inbox.
"""

from django.db import models
from django.conf import settings
from django.utils import timezone as tz


# =============================================================================
# USER SETTINGS MODEL
# =============================================================================


class UserSettings(models.Model):
    """Per-user application preferences - one row per user account."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='app_settings',
    )

    # -- Appearance --
    theme = models.CharField(max_length=20, default='system')
    accent_color = models.CharField(max_length=20, default='indigo')
    animations_enabled = models.BooleanField(default=True)
    font_size = models.CharField(max_length=10, default='medium')

    # -- Daily Summary --
    daily_summary_enabled = models.BooleanField(default=True)
    daily_summary_time = models.TimeField(null=True, blank=True)

    # -- Motivational Quotes --
    quotes_enabled = models.BooleanField(default=True)
    quote_frequency = models.CharField(max_length=20, default='morning')
    quote_tone = models.CharField(max_length=20, default='calm')

    # -- Quiet Hours (Unified) --
    quiet_hours_enabled = models.BooleanField(default=False)
    quiet_hours_start = models.TimeField(null=True, blank=True)
    quiet_hours_end = models.TimeField(null=True, blank=True)
    quiet_hours_allow_emergency = models.BooleanField(default=True)

    # -- Quiet Hours (Weekday / Weekend split) --
    quiet_hours_separate_weekend = models.BooleanField(default=False)
    quiet_hours_weekday_start = models.TimeField(null=True, blank=True)
    quiet_hours_weekday_end = models.TimeField(null=True, blank=True)
    quiet_hours_weekend_start = models.TimeField(null=True, blank=True)
    quiet_hours_weekend_end = models.TimeField(null=True, blank=True)

    # -- Timezone --
    timezone = models.CharField(max_length=50, default='UTC')

    # -- Advanced Preferences --
    language = models.CharField(max_length=10, default='en')
    week_start_day = models.CharField(max_length=10, default='monday')
    analytics_consent = models.BooleanField(default=True)
    ai_personalization = models.BooleanField(default=True)
    compact_mode = models.BooleanField(default=False)
    haptic_feedback = models.BooleanField(default=True)
    auto_archive_days = models.IntegerField(default=0)
    default_habit_visibility = models.CharField(max_length=20, default='private')

    # -- Timestamps --
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_settings'

    def __str__(self):
        return f'{self.user.email} Settings'


# =============================================================================
# PRIVACY SETTINGS MODEL
# =============================================================================


class PrivacySettings(models.Model):
    """Per-user privacy and data-sharing controls."""

    VISIBILITY_CHOICES = [
        ('public', 'Public'),
        ('friends', 'Friends Only'),
        ('private', 'Private'),
    ]
    FRIEND_REQUEST_CHOICES = [
        ('everyone', 'Everyone'),
        ('friends_of_friends', 'Friends of Friends'),
        ('nobody', 'Nobody'),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='privacy_settings',
    )

    account_visibility = models.CharField(max_length=20, choices=VISIBILITY_CHOICES, default='friends')
    show_profile_in_search = models.BooleanField(default=True)
    show_in_leaderboard = models.BooleanField(default=True)

    who_can_view_habits = models.CharField(max_length=20, choices=VISIBILITY_CHOICES, default='friends')
    who_can_view_streaks = models.CharField(max_length=20, choices=VISIBILITY_CHOICES, default='friends')
    share_progress_with_groups = models.BooleanField(default=True)

    who_can_send_friend_requests = models.CharField(max_length=25, choices=FRIEND_REQUEST_CHOICES, default='everyone')
    allow_group_invites = models.BooleanField(default=True)
    show_online_status = models.BooleanField(default=False)

    share_anonymous_usage_data = models.BooleanField(default=True)
    allow_ai_training = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'privacy_settings'

    def __str__(self):
        return f'{self.user.email} Privacy Settings'


# =============================================================================
# SECURITY SETTINGS MODEL
# =============================================================================


class SecuritySettings(models.Model):
    """Per-user security preferences."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='security_settings',
    )

    two_factor_enabled = models.BooleanField(default=False)
    two_factor_method = models.CharField(max_length=20, default='email')

    biometric_lock_enabled = models.BooleanField(default=False)
    require_auth_for_export = models.BooleanField(default=True)
    require_auth_for_delete = models.BooleanField(default=True)

    session_timeout_minutes = models.IntegerField(default=0)
    login_notification_enabled = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'security_settings'

    def __str__(self):
        return f'{self.user.email} Security Settings'


# =============================================================================
# LOGIN SESSION MODEL
# =============================================================================


class LoginSession(models.Model):
    """Active device/session registry for manage your devices and remote logout."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='login_sessions',
    )
    session_key = models.CharField(max_length=255, unique=True, db_index=True)
    device_name = models.CharField(max_length=255, default='Unknown Device')
    device_type = models.CharField(max_length=50, default='unknown')
    platform = models.CharField(max_length=50, default='unknown')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    location = models.CharField(max_length=255, blank=True, default='')
    is_current = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    last_active_at = models.DateTimeField(auto_now=True)
    logged_in_at = models.DateTimeField(auto_now_add=True)
    logged_out_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'login_sessions'
        ordering = ['-last_active_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['session_key']),
        ]

    def __str__(self):
        active = 'active' if self.is_active else 'inactive'
        return f'{self.device_name} ({self.platform}) - {active}'

    def revoke(self):
        self.is_active = False
        self.logged_out_at = tz.now()
        self.save(update_fields=['is_active', 'logged_out_at'])


# =============================================================================
# SETTINGS AUDIT LOG MODEL
# =============================================================================


class SettingsAuditLog(models.Model):
    """Immutable audit trail for every settings mutation."""

    CATEGORY_CHOICES = [
        ('profile', 'Profile Change'),
        ('appearance', 'Appearance Change'),
        ('notification', 'Notification Change'),
        ('privacy', 'Privacy Change'),
        ('security', 'Security Change'),
        ('export', 'Data Export'),
        ('account', 'Account Action'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='settings_audit_logs',
    )
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    action = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    old_value = models.JSONField(default=dict)
    new_value = models.JSONField(default=dict)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'settings_audit_logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'category']),
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        return f'{self.user.email} - {self.action} ({self.created_at})'

    @classmethod
    def log(cls, user, category, action, description='',
            old_value=None, new_value=None, request=None):
        ip = None
        ua = ''
        if request:
            ip = request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip() or request.META.get('REMOTE_ADDR')
            ua = request.META.get('HTTP_USER_AGENT', '')
        return cls.objects.create(
            user=user, category=category, action=action,
            description=description, old_value=old_value or {},
            new_value=new_value or {}, ip_address=ip, user_agent=ua,
        )


# =============================================================================
# EXPORT REQUEST MODEL
# =============================================================================


class ExportRequest(models.Model):
    """User data export lifecycle tracking."""

    FORMAT_CHOICES = [('pdf', 'PDF'), ('csv', 'CSV'), ('json', 'JSON')]
    STATUS_CHOICES = [
        ('pending', 'Pending'), ('processing', 'Processing'),
        ('completed', 'Completed'), ('failed', 'Failed'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='export_requests')
    export_format = models.CharField(max_length=10, choices=FORMAT_CHOICES)
    date_from = models.DateField()
    date_to = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    file_url = models.TextField(blank=True, default='')
    error_message = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'export_requests'
        ordering = ['-created_at']

    def __str__(self):
        return f"Export {self.export_format} - {self.user.email} ({self.status})"


# =============================================================================
# PRIVACY POLICY MODEL
# =============================================================================


class PrivacyPolicy(models.Model):
    """Versioned legal documents with single-active-version enforcement."""

    version = models.CharField(max_length=20, unique=True)
    title = models.CharField(max_length=255, default='Privacy Policy')
    content = models.TextField()
    effective_date = models.DateField()
    is_current = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'privacy_policies'
        ordering = ['-effective_date']

    def __str__(self):
        return f"Privacy Policy v{self.version}"

    def save(self, *args, **kwargs):
        if self.is_current:
            PrivacyPolicy.objects.exclude(pk=self.pk).update(is_current=False)
        super().save(*args, **kwargs)


# =============================================================================
# FAQ MODEL
# =============================================================================


class FAQ(models.Model):
    """Admin-managed FAQ entries."""

    question = models.TextField()
    answer = models.TextField()
    category = models.CharField(max_length=100, default='General')
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'faqs'
        ordering = ['sort_order', '-created_at']

    def __str__(self):
        return self.question[:80]


# =============================================================================
# SUPPORT TICKET MODEL
# =============================================================================


class SupportTicket(models.Model):
    """User support ticket with admin-response workflow."""

    PRIORITY_CHOICES = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]
    STATUS_CHOICES = [
        ('open', 'Open'), ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'), ('closed', 'Closed'),
    ]
    CATEGORY_CHOICES = [
        ('bug', 'Bug Report'), ('feature', 'Feature Request'),
        ('account', 'Account Issue'), ('billing', 'Billing'), ('general', 'General'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='support_tickets')
    subject = models.CharField(max_length=255)
    description = models.TextField()
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='general')
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='medium')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    screenshot_url = models.TextField(blank=True, default='')
    admin_response = models.TextField(blank=True, default='')
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'support_tickets'
        ordering = ['-created_at']

    def __str__(self):
        return f"#{self.pk} - {self.subject} ({self.status})"
