"""
URL configuration for DailyHabits project.
Production-ready API routing
"""

from django.contrib import admin
from django.urls import path, include
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .api_router import router


@api_view(['GET'])
@permission_classes([AllowAny])
def api_root(request):
    """
    API root endpoint with version and status info
    """
    return Response({
        'status': 'online',
        'version': '2.0.0',
        'api': 'DailyHabits API',
        'endpoints': {
            'auth': '/api/auth/',
            'habits': '/api/habits/',
            'analytics': '/api/analytics/',
            'achievements': '/api/achievements/',
            'insights': '/api/insights/',
            'notifications': '/api/notifications/',
            'social': '/api/social/',
            'intelligence': '/api/notification-intelligence/',
        },
        'documentation': '/api/docs/',
    })


urlpatterns = [
    # API Root
    path('api/', api_root, name='api-root'),
    
    # Admin panel
    path('admin/', admin.site.urls),

    # Authentication APIs (login, register, token, etc.)
    path('api/auth/', include('authentication.urls')),
    
    # Centralized API Router (Habits, Analytics, Achievements, Insights, Notifications, Social)
    path('api/', include(router.urls)),

    # Browsable API login/logout (DRF)
    path('api-auth/', include('rest_framework.urls')),
]
