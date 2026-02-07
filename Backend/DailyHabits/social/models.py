"""
Social / Community Models
Feed posts, friends, share cards, privacy controls, group habits, referral system
"""

from django.db import models
from django.conf import settings
import uuid


# ═══════════════════════════════════════════════════════════════════════════
#  FRIENDSHIP
# ═══════════════════════════════════════════════════════════════════════════

class Friendship(models.Model):
    """Bidirectional friendship between two users."""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
    ]

    from_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_friend_requests',
    )
    to_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_friend_requests',
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'friendships'
        unique_together = ('from_user', 'to_user')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.from_user.email} → {self.to_user.email} ({self.status})"


# ═══════════════════════════════════════════════════════════════════════════
#  FEED POSTS, LIKES, COMMENTS
# ═══════════════════════════════════════════════════════════════════════════

class FeedPost(models.Model):
    """A post in the community feed."""
    POST_TYPES = [
        ('completion', 'Habit Completion'),
        ('streak', 'Streak Milestone'),
        ('achievement', 'Achievement Earned'),
        ('group_update', 'Group Update'),
        ('motivation', 'Motivational Post'),
    ]

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='feed_posts',
    )
    post_type = models.CharField(max_length=20, choices=POST_TYPES, default='completion')
    content = models.TextField(max_length=500)
    emoji = models.CharField(max_length=10, blank=True, default='')

    # Optional references
    habit = models.ForeignKey(
        'habits.Habit', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='feed_posts',
    )
    group = models.ForeignKey(
        'social.GroupHabit', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='feed_posts',
    )

    # Denormalized counters for performance
    like_count = models.IntegerField(default=0)
    comment_count = models.IntegerField(default=0)

    # Optional metadata stored as JSON
    metadata = models.JSONField(default=dict, blank=True)

    is_public = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'feed_posts'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at', 'author']),
        ]

    def __str__(self):
        return f"{self.author.email}: {self.content[:50]}"


class PostLike(models.Model):
    """A like / clap on a feed post."""
    post = models.ForeignKey(FeedPost, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='post_likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'post_likes'
        unique_together = ('post', 'user')

    def __str__(self):
        return f"{self.user.email} liked post {self.post_id}"


class PostComment(models.Model):
    """A comment on a feed post."""
    post = models.ForeignKey(FeedPost, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='post_comments',
    )
    content = models.TextField(max_length=300)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'post_comments'
        ordering = ['created_at']

    def __str__(self):
        return f"{self.author.email}: {self.content[:40]}"


# ═══════════════════════════════════════════════════════════════════════════
#  EXISTING MODELS (share cards, privacy, referrals, groups) below
# ═══════════════════════════════════════════════════════════════════════════


class ShareCard(models.Model):
    """
    Auto-generated share cards for daily, weekly, and streak summaries
    """
    SHARE_TYPES = [
        ('daily', 'Daily Summary'),
        ('weekly', 'Weekly Summary'),
        ('streak', 'Streak Milestone'),
        ('achievement', 'Achievement Earned'),
        ('custom', 'Custom Share'),
    ]
    
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('shared', 'Shared'),
        ('expired', 'Expired'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='share_cards'
    )
    
    id = models.AutoField(primary_key=True)
    share_type = models.CharField(max_length=50, choices=SHARE_TYPES)
    title = models.CharField(max_length=255)
    subtitle = models.CharField(max_length=255, blank=True)
    
    # Summary data rendered on the card
    card_data = models.JSONField(default=dict, help_text='Structured data for rendering the share card')
    
    # Stats displayed
    habits_completed = models.IntegerField(default=0)
    total_habits = models.IntegerField(default=0)
    streak_count = models.IntegerField(default=0)
    completion_rate = models.FloatField(default=0.0)
    
    # Share metadata
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    share_url = models.URLField(blank=True)
    shared_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    
    # Date range
    period_start = models.DateField()
    period_end = models.DateField()
    
    # Theming
    color_primary = models.CharField(max_length=10, default='#312C51')
    color_accent = models.CharField(max_length=10, default='#F0C38E')
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'share_cards'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.share_type} card - {self.user.email} ({self.period_start})"


class SharingPrivacy(models.Model):
    """
    Per-habit privacy controls for sharing
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sharing_privacy'
    )
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.CASCADE,
        related_name='privacy_settings'
    )
    
    id = models.AutoField(primary_key=True)
    # What can be shared
    allow_in_summary = models.BooleanField(default=True, help_text='Include in daily/weekly share cards')
    allow_streak_share = models.BooleanField(default=True, help_text='Include streak milestones')
    allow_in_group = models.BooleanField(default=True, help_text='Visible in group habits')
    show_details = models.BooleanField(default=False, help_text='Show habit description/notes')
    
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sharing_privacy'
        unique_together = ('user', 'habit')

    def __str__(self):
        return f"Privacy: {self.habit.title} - {self.user.email}"


class ReferralLink(models.Model):
    """
    Friend invite via referral links
    """
    referrer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referral_links'
    )
    code = models.CharField(max_length=12, unique=True)
    
    uses_count = models.IntegerField(default=0)
    max_uses = models.IntegerField(default=10)
    is_active = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'referral_links'

    def __str__(self):
        return f"Referral {self.code} by {self.referrer.email}"

    @property
    def is_valid(self):
        from django.utils import timezone
        if not self.is_active:
            return False
        if self.uses_count >= self.max_uses:
            return False
        if self.expires_at and timezone.now() > self.expires_at:
            return False
        return True


class Referral(models.Model):
    """
    Track successful referrals
    """
    referrer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referrals_made'
    )
    referred_user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='referred_by'
    )
    referral_link = models.ForeignKey(
        ReferralLink,
        on_delete=models.SET_NULL,
        null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'referrals'

    def __str__(self):
        return f"{self.referrer.email} -> {self.referred_user.email}"


class GroupHabit(models.Model):
    """
    Optional group habit participation
    """
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    
    habit_template = models.JSONField(
        default=dict,
        help_text='Template data for creating the habit for each member'
    )
    
    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_groups'
    )
    
    id = models.AutoField(primary_key=True)
    invite_code = models.CharField(max_length=8, unique=True)
    max_members = models.IntegerField(default=20)
    is_active = models.BooleanField(default=True)
    
    # Visual
    icon_code = models.IntegerField(default=0xE7FB)
    color_value = models.BigIntegerField(default=0xFFF0C38E)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'group_habits'
        ordering = ['-created_at']

    def __str__(self):
        return self.name

    @property
    def member_count(self):
        return self.members.count()


class GroupMember(models.Model):
    """
    Members of a group habit
    """
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('member', 'Member'),
    ]

    group = models.ForeignKey(
        GroupHabit,
        on_delete=models.CASCADE,
        related_name='members'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='group_memberships'
    )
    habit = models.ForeignKey(
        'habits.Habit',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text='The user\'s personal habit linked to this group'
    )
    
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'group_members'
        unique_together = ('group', 'user')

    def __str__(self):
        return f"{self.user.email} in {self.group.name}"
