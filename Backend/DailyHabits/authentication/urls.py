"""
Authentication URLs
apps/authentication/urls.py
"""

from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    UserProfileView,
    ChangePasswordView,
    LoginHistoryView,
    DataExportView,
    DataDeletionRequestView,
)

app_name = 'authentication'

urlpatterns = [
    # Authentication endpoints
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    
    # User profile endpoints
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    
    # Security & privacy endpoints
    path('login-history/', LoginHistoryView.as_view(), name='login-history'),
    path('data-export/', DataExportView.as_view(), name='data-export'),
    path('request-deletion/', DataDeletionRequestView.as_view(), name='request-deletion'),
]