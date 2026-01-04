"""
URL configuration for DailyHabits project.
"""

from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    # Admin panel
    path('admin/', admin.site.urls),

    # Authentication APIs (login, register, token, etc.)
    path('api/auth/', include('authentication.urls')),
    
    # Habits APIs
    path('api/habits/', include('habits.urls')),

    # Browsable API login/logout (DRF)
    path('api-auth/', include('rest_framework.urls')),
]
