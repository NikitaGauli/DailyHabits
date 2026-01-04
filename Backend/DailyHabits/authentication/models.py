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