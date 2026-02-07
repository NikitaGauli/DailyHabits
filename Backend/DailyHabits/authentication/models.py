from django.db import models

# Create your models here.
"""
Custom User Model for DailyHabits
apps/authentication/models.py
"""

from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    """
    Custom User Model
    Uses email as the unique identifier instead of username
    """
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
    profile_image = models.URLField(
        max_length=500,
        blank=True,
        null=True,
        verbose_name='Profile Image URL'
    )
    
    # User status
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_login = models.DateTimeField(null=True, blank=True)
    
    # Habit tracking fields (optional)
    current_streak = models.IntegerField(default=0)
    total_habits_completed = models.IntegerField(default=0)
    
    # Use custom manager
    objects = UserManager()
    
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['name']
    
    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        ordering = ['-created_at']
    
    def __str__(self):
        return self.email
    
    def get_full_name(self):
        return self.name
    
    def get_short_name(self):
        return self.name.split()[0] if self.name else self.email


class LoginActivity(models.Model):
    """
    Track user login events for security auditing.
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
        status_str = 'success' if self.was_successful else 'failed'
        return f'{self.user.email} - {status_str} - {self.login_at}'


class DataDeletionRequest(models.Model):
    """
    GDPR-style data deletion requests.
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