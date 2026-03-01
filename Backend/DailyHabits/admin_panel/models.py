"""
admin_panel/models.py — Enterprise Admin Dashboard Models
==========================================================
UUID primary keys · timestamps · audit trail · immutable logs.
"""

import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


# ═══════════════════════════════════════════════════════════════════════════════
#  1. ROLE-BASED ACCESS CONTROL (RBAC)
# ═══════════════════════════════════════════════════════════════════════════════

class AdminRole(models.Model):
    """
    Granular admin roles that map to a set of permission keys.

    Default roles (seeded via migration):
        SUPER_ADMIN  — Full platform control, 2FA required
        ADMIN        — User/content/config management
        MODERATOR    — Content moderation, report resolution
        SUPPORT      — User support, ticket management
        ANALYTICS    — Read-only analytics dashboards
    """

    SUPER_ADMIN = 'super_admin'
    ADMIN = 'admin'
    MODERATOR = 'moderator'
    SUPPORT = 'support'
    ANALYTICS = 'analytics'

    ROLE_CHOICES = [
        (SUPER_ADMIN, 'Super Admin'),
        (ADMIN, 'Admin'),
        (MODERATOR, 'Moderator'),
        (SUPPORT, 'Support Staff'),
        (ANALYTICS, 'Analytics Viewer'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=50, unique=True, choices=ROLE_CHOICES)
    display_name = models.CharField(max_length=100)
    description = models.TextField(blank=True, default='')
    permissions = models.JSONField(
        default=list,
        help_text='List of permission keys, e.g. ["users.view", "users.edit"]',
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_roles'
        ordering = ['name']

    def __str__(self):
        return self.display_name

    def has_permission(self, perm_key: str) -> bool:
        """Check if role grants *perm_key* (supports wildcard '*')."""
        if '*' in self.permissions:
            return True
        # Support namespace wildcards like "users.*"
        namespace = perm_key.split('.')[0] + '.*'
        return perm_key in self.permissions or namespace in self.permissions


class AdminProfile(models.Model):
    """
    Extends the core User model with admin-specific metadata.

    Each admin user has exactly one profile linking them to an AdminRole.
    The profile tracks 2FA status, last admin activity, and the IP from
    which admin operations are performed.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='admin_profile',
    )
    role = models.ForeignKey(
        AdminRole,
        on_delete=models.PROTECT,
        related_name='profiles',
    )
    is_active = models.BooleanField(default=True)
    two_factor_enabled = models.BooleanField(default=False)
    two_factor_secret = models.CharField(max_length=64, blank=True, default='')
    last_admin_login = models.DateTimeField(null=True, blank=True)
    last_admin_ip = models.GenericIPAddressField(null=True, blank=True)
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='created_admin_profiles',
    )

    class Meta:
        db_table = 'admin_profiles'

    def __str__(self):
        return f'{self.user.email} — {self.role.display_name}'

    def has_permission(self, perm_key: str) -> bool:
        return self.is_active and self.role.has_permission(perm_key)


# ═══════════════════════════════════════════════════════════════════════════════
#  2. AUDIT LOG (Immutable)
# ═══════════════════════════════════════════════════════════════════════════════

class AuditLog(models.Model):
    """
    Immutable, append-only audit trail for every admin action.

    Entries are never updated or deleted. The ``save()`` override
    prevents modification of existing records.
    """

    ACTION_CHOICES = [
        ('login', 'Admin Login'),
        ('logout', 'Admin Logout'),
        ('login_failed', 'Login Failed'),
        ('user_view', 'Viewed User'),
        ('user_edit', 'Edited User'),
        ('user_suspend', 'Suspended User'),
        ('user_activate', 'Activated User'),
        ('user_delete', 'Deleted User'),
        ('user_password_reset', 'Reset User Password'),
        ('content_approve', 'Approved Content'),
        ('content_reject', 'Rejected Content'),
        ('content_remove', 'Removed Content'),
        ('report_resolve', 'Resolved Report'),
        ('report_escalate', 'Escalated Report'),
        ('role_change', 'Changed Admin Role'),
        ('settings_change', 'Changed System Settings'),
        ('feature_flag_toggle', 'Toggled Feature Flag'),
        ('gamification_change', 'Changed Gamification Rules'),
        ('notification_send', 'Sent Notification Campaign'),
        ('notification_template_edit', 'Edited Notification Template'),
        ('export_data', 'Exported Data'),
        ('system_maintenance', 'System Maintenance'),
        ('suspicious_activity', 'Suspicious Activity'),
        ('two_factor_change', '2FA Configuration Change'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    admin_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='admin_audit_logs',
    )
    action = models.CharField(max_length=50, choices=ACTION_CHOICES)
    resource_type = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Model / resource affected, e.g. "User", "Habit"',
    )
    resource_id = models.CharField(
        max_length=255, blank=True, default='',
        help_text='PK of the affected resource',
    )
    description = models.TextField(blank=True, default='')
    changes = models.JSONField(
        default=dict,
        help_text='Before/after snapshot of changed fields',
    )
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True, default='')
    metadata = models.JSONField(default=dict)
    severity = models.CharField(
        max_length=20,
        choices=[
            ('info', 'Info'),
            ('warning', 'Warning'),
            ('critical', 'Critical'),
        ],
        default='info',
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = 'admin_audit_logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['action', 'created_at'], name='idx_audit_action_ts'),
            models.Index(fields=['admin_user', 'created_at'], name='idx_audit_user_ts'),
            models.Index(fields=['resource_type', 'resource_id'], name='idx_audit_resource'),
        ]

    def __str__(self):
        actor = self.admin_user.email if self.admin_user else 'system'
        return f'[{self.created_at:%Y-%m-%d %H:%M}] {actor} → {self.action}'

    def save(self, *args, **kwargs):
        """Only allow INSERT, never UPDATE — audit logs are immutable."""
        if self.pk and AuditLog.objects.filter(pk=self.pk).exists():
            raise ValueError('Audit logs are immutable and cannot be modified.')
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValueError('Audit logs cannot be deleted.')


# ═══════════════════════════════════════════════════════════════════════════════
#  3. REPORTS & CONTENT MODERATION
# ═══════════════════════════════════════════════════════════════════════════════

class Report(models.Model):
    """
    User-submitted abuse/content reports that enter the moderation queue.
    """

    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('under_review', 'Under Review'),
        ('resolved', 'Resolved'),
        ('dismissed', 'Dismissed'),
        ('escalated', 'Escalated'),
    ]

    CATEGORY_CHOICES = [
        ('spam', 'Spam'),
        ('harassment', 'Harassment'),
        ('inappropriate', 'Inappropriate Content'),
        ('misinformation', 'Misinformation'),
        ('hate_speech', 'Hate Speech'),
        ('impersonation', 'Impersonation'),
        ('privacy', 'Privacy Violation'),
        ('other', 'Other'),
    ]

    CONTENT_TYPE_CHOICES = [
        ('habit', 'Habit'),
        ('comment', 'Comment'),
        ('feed_post', 'Feed Post'),
        ('group', 'Group'),
        ('user_profile', 'User Profile'),
        ('share_card', 'Share Card'),
    ]

    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='reports_filed',
    )
    reported_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='reports_received',
    )
    content_type = models.CharField(max_length=30, choices=CONTENT_TYPE_CHOICES)
    content_id = models.CharField(max_length=255, help_text='PK of the reported object')
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    description = models.TextField(blank=True, default='')
    evidence_urls = models.JSONField(default=list, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='medium')
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='assigned_reports',
    )
    resolution = models.TextField(blank=True, default='')
    resolution_action = models.CharField(
        max_length=50, blank=True, default='',
        help_text='Action taken: warn/suspend/ban/remove_content/dismiss',
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='reports_resolved',
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_reports'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'priority', '-created_at'], name='idx_report_queue'),
            models.Index(fields=['reported_user', 'status'], name='idx_report_user'),
        ]

    def __str__(self):
        return f'Report #{str(self.id)[:8]} — {self.category} ({self.status})'


class ContentModerationQueue(models.Model):
    """
    Queue for shared/community content that requires moderator approval
    (auto-flagged or user-reported).
    """

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('auto_flagged', 'Auto-Flagged'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    content_type = models.CharField(max_length=30)
    content_id = models.CharField(max_length=255)
    content_preview = models.TextField(blank=True, default='')
    content_author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='moderation_items',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    flag_reason = models.TextField(blank=True, default='')
    auto_flag_score = models.FloatField(
        default=0.0,
        help_text='ML confidence score (0-1) if auto-flagged',
    )
    report = models.ForeignKey(
        Report, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='moderation_items',
    )
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='moderation_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewer_notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_moderation_queue'
        ordering = ['-created_at']

    def __str__(self):
        return f'Moderation: {self.content_type}/{self.content_id} ({self.status})'


class UserWarning(models.Model):
    """Track warnings issued to users by moderators."""

    SEVERITY_CHOICES = [
        ('informal', 'Informal Warning'),
        ('formal', 'Formal Warning'),
        ('final', 'Final Warning'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='admin_warnings',
    )
    issued_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='warnings_issued',
    )
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES, default='informal')
    reason = models.TextField()
    related_report = models.ForeignKey(
        Report, on_delete=models.SET_NULL, null=True, blank=True,
    )
    acknowledged = models.BooleanField(default=False)
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'admin_user_warnings'
        ordering = ['-created_at']

    def __str__(self):
        return f'Warning → {self.user.email} ({self.severity})'


# ═══════════════════════════════════════════════════════════════════════════════
#  4. SYSTEM CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

class SystemSettings(models.Model):
    """
    Key-value platform configuration store.

    Supports typed values via ``value_type`` and tracks who changed what.
    Designed for settings like maintenance mode, default XP values,
    announcement text, etc.
    """

    VALUE_TYPE_CHOICES = [
        ('string', 'String'),
        ('integer', 'Integer'),
        ('float', 'Float'),
        ('boolean', 'Boolean'),
        ('json', 'JSON'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key = models.CharField(max_length=255, unique=True, db_index=True)
    value = models.TextField(default='')
    value_type = models.CharField(max_length=20, choices=VALUE_TYPE_CHOICES, default='string')
    description = models.TextField(blank=True, default='')
    category = models.CharField(
        max_length=50, default='general',
        help_text='Grouping: general, security, gamification, notification, etc.',
    )
    is_public = models.BooleanField(
        default=False,
        help_text='If True, value is accessible from unauthenticated endpoints.',
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_system_settings'
        verbose_name_plural = 'system settings'

    def __str__(self):
        return f'{self.key} = {self.value[:50]}'

    def get_typed_value(self):
        """Return value cast to its declared type."""
        import json
        if self.value_type == 'integer':
            return int(self.value)
        elif self.value_type == 'float':
            return float(self.value)
        elif self.value_type == 'boolean':
            return self.value.lower() in ('true', '1', 'yes')
        elif self.value_type == 'json':
            return json.loads(self.value)
        return self.value


class FeatureFlag(models.Model):
    """
    Feature toggles for gradual rollouts and kill-switches.
    """

    ROLLOUT_CHOICES = [
        ('off', 'Off'),
        ('staff_only', 'Staff Only'),
        ('percentage', 'Percentage Rollout'),
        ('on', 'On (Everyone)'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key = models.CharField(max_length=255, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    is_enabled = models.BooleanField(default=False)
    rollout_strategy = models.CharField(
        max_length=30, choices=ROLLOUT_CHOICES, default='off',
    )
    rollout_percentage = models.IntegerField(
        default=0,
        help_text='0-100 — used when strategy is "percentage".',
    )
    metadata = models.JSONField(default=dict, blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_feature_flags'
        ordering = ['key']

    def __str__(self):
        status = 'ON' if self.is_enabled else 'OFF'
        return f'{self.key} [{status}]'

    def is_enabled_for_user(self, user) -> bool:
        """Evaluate whether the flag is active for a specific user."""
        if not self.is_enabled:
            return False
        if self.rollout_strategy == 'on':
            return True
        if self.rollout_strategy == 'staff_only':
            return getattr(user, 'is_staff', False)
        if self.rollout_strategy == 'percentage':
            # Deterministic hash so the same user always gets the same result
            return (user.pk.int if hasattr(user.pk, 'int') else hash(user.pk)) % 100 < self.rollout_percentage
        return False


# ═══════════════════════════════════════════════════════════════════════════════
#  5. NOTIFICATION TEMPLATES & CAMPAIGNS
# ═══════════════════════════════════════════════════════════════════════════════

class NotificationTemplate(models.Model):
    """
    Reusable notification/email templates for admin-initiated campaigns.
    """

    CHANNEL_CHOICES = [
        ('push', 'Push Notification'),
        ('email', 'Email'),
        ('in_app', 'In-App'),
        ('sms', 'SMS'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, unique=True)
    channel = models.CharField(max_length=20, choices=CHANNEL_CHOICES, default='push')
    subject = models.CharField(max_length=255, blank=True, default='')
    title = models.CharField(max_length=255)
    body = models.TextField(help_text='Supports {{user_name}}, {{habit_name}} placeholders.')
    metadata = models.JSONField(default=dict, blank=True)
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='created_templates',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_notification_templates'
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.channel})'


class NotificationCampaign(models.Model):
    """
    Scheduled or immediate push-notification broadcasts.
    """

    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('scheduled', 'Scheduled'),
        ('sending', 'Sending'),
        ('sent', 'Sent'),
        ('cancelled', 'Cancelled'),
        ('failed', 'Failed'),
    ]

    TARGET_CHOICES = [
        ('all', 'All Users'),
        ('active', 'Active Users (last 7 days)'),
        ('inactive', 'Inactive Users (>30 days)'),
        ('new', 'New Users (<7 days)'),
        ('segment', 'Custom Segment'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    template = models.ForeignKey(
        NotificationTemplate,
        on_delete=models.SET_NULL, null=True, blank=True,
        related_name='campaigns',
    )
    title = models.CharField(max_length=255)
    body = models.TextField()
    target_audience = models.CharField(max_length=30, choices=TARGET_CHOICES, default='all')
    target_filters = models.JSONField(
        default=dict, blank=True,
        help_text='Custom filter criteria for segment targeting.',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    scheduled_at = models.DateTimeField(null=True, blank=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    total_recipients = models.IntegerField(default=0)
    delivered_count = models.IntegerField(default=0)
    failed_count = models.IntegerField(default=0)
    opened_count = models.IntegerField(default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='created_campaigns',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_notification_campaigns'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.name} ({self.status})'

    @property
    def delivery_rate(self):
        if self.total_recipients == 0:
            return 0.0
        return round(self.delivered_count / self.total_recipients * 100, 1)

    @property
    def open_rate(self):
        if self.delivered_count == 0:
            return 0.0
        return round(self.opened_count / self.delivered_count * 100, 1)


# ═══════════════════════════════════════════════════════════════════════════════
#  6. PLATFORM ANALYTICS SNAPSHOTS
# ═══════════════════════════════════════════════════════════════════════════════

class PlatformAnalyticsSnapshot(models.Model):
    """
    Daily platform-wide metrics pre-aggregated by a scheduled task.
    Powers the admin overview dashboard with fast reads.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    date = models.DateField(unique=True, db_index=True)

    # ── User metrics ──
    total_users = models.IntegerField(default=0)
    new_users = models.IntegerField(default=0)
    daily_active_users = models.IntegerField(default=0)
    weekly_active_users = models.IntegerField(default=0)
    monthly_active_users = models.IntegerField(default=0)

    # ── Engagement metrics ──
    total_habits = models.IntegerField(default=0)
    habits_completed_today = models.IntegerField(default=0)
    average_completion_rate = models.FloatField(default=0.0)
    total_streaks_active = models.IntegerField(default=0)
    average_streak_length = models.FloatField(default=0.0)

    # ── Social metrics ──
    total_shared_habits = models.IntegerField(default=0)
    total_groups = models.IntegerField(default=0)
    total_feed_posts = models.IntegerField(default=0)
    social_engagement_rate = models.FloatField(default=0.0)

    # ── Gamification metrics ──
    total_xp_earned = models.IntegerField(default=0)
    total_achievements_unlocked = models.IntegerField(default=0)
    total_challenges_active = models.IntegerField(default=0)

    # ── Retention metrics ──
    day_1_retention = models.FloatField(default=0.0)
    day_7_retention = models.FloatField(default=0.0)
    day_30_retention = models.FloatField(default=0.0)
    churn_rate = models.FloatField(default=0.0)

    # ── System health ──
    total_reports_pending = models.IntegerField(default=0)
    total_support_tickets_open = models.IntegerField(default=0)
    api_error_rate = models.FloatField(default=0.0)

    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'admin_analytics_snapshots'
        ordering = ['-date']

    def __str__(self):
        return f'Snapshot {self.date} — {self.daily_active_users} DAU'


# ═══════════════════════════════════════════════════════════════════════════════
#  7. AI SAFETY MONITORING
# ═══════════════════════════════════════════════════════════════════════════════

class AISafetyLog(models.Model):
    """
    Tracks AI-generated content for safety auditing.
    Used when AI features (e.g. smart tips, recommendations) are enabled.
    """

    STATUS_CHOICES = [
        ('safe', 'Safe'),
        ('flagged', 'Flagged'),
        ('blocked', 'Blocked'),
        ('reviewed', 'Reviewed — OK'),
        ('reviewed_unsafe', 'Reviewed — Unsafe'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='ai_safety_logs',
    )
    feature = models.CharField(
        max_length=50,
        help_text='Which AI feature, e.g. "smart_tips", "habit_recommendation"',
    )
    input_text = models.TextField(blank=True, default='')
    output_text = models.TextField(blank=True, default='')
    safety_score = models.FloatField(default=1.0, help_text='0=unsafe, 1=safe')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='safe')
    flag_reason = models.TextField(blank=True, default='')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='ai_safety_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'admin_ai_safety_logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at'], name='idx_ai_safety_status'),
        ]

    def __str__(self):
        return f'AI [{self.feature}] → {self.status} (score={self.safety_score})'


class AIUserRestriction(models.Model):
    """Per-user AI feature restrictions set by admins."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='ai_restrictions',
    )
    feature = models.CharField(max_length=50)
    is_disabled = models.BooleanField(default=True)
    reason = models.TextField(blank=True, default='')
    disabled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='ai_restrictions_issued',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'admin_ai_user_restrictions'
        unique_together = [('user', 'feature')]

    def __str__(self):
        return f'AI restriction: {self.user.email} — {self.feature}'
