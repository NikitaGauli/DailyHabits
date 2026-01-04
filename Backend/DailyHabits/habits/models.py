from django.db import models
from django.conf import settings

class Habit(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='habits')
    title = models.CharField(max_length=255)
    time = models.CharField(max_length=100) # e.g. "6:00 AM - Mindfulness"
    category = models.CharField(max_length=100)
    
    # Storing icon and color as integers/hex or codes to match Flutter
    # For simplicity, we'll store them as integers (codePoint and value)
    icon_code = models.IntegerField(help_text="Flutter Icon codePoint")
    color_value = models.BigIntegerField(help_text="Flutter Color value (ARGB)")
    
    is_completed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} ({self.user.email})"
