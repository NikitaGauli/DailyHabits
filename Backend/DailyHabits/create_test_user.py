#!/usr/bin/env python
"""
Script to create a test user with authentication token for development
Run with: python manage.py shell < create_test_user.py
Or from Django shell: exec(open('create_test_user.py').read())
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()


# Create test user
email = 'test@example.com'
name = 'Test User'
password = 'testpass123'

try:
    user = User.objects.get(email=email)
    print(f"User '{email}' already exists")
except User.DoesNotExist:
    user = User.objects.create_user(email=email, name=name, password=password)  # type: ignore
    print(f"Created user: {email}")

# Create or get token
# Note: DRF Token is usually for default TokenAuthentication. 
# If using SimpleJWT, you don't generate tokens this way in DB usually, but manual token generation is possible.
# For now keeping it if the user relies on it, but typically JWT is obtained via login.
from rest_framework_simplejwt.tokens import RefreshToken

refresh = RefreshToken.for_user(user)
access_token = str(refresh.access_token)

print("\n" + "="*60)
print("TEST USER CREDENTIALS")
print("="*60)
print(f"Email: {email}")
print(f"Password: {password}")
print(f"Access Token: {access_token}")
print("="*60)
print("\nAdd this to your Flutter app:")
print(f"// Use this token for testing if needed")
