"""
URL Configuration — DailyHabits Project
========================================

Top-level URL routing for the DailyHabits backend API. Incoming HTTP requests
are matched against the patterns defined in ``urlpatterns`` and dispatched to
the appropriate view or included sub-router.

Routing strategy:
    - ``/api/``           -> API root (discovery / health-check endpoint)
    - ``/api/auth/``      -> Authentication module (JWT obtain, refresh, register)
    - ``/api/<resource>/`` -> Centralised DRF router (see ``api_router.py``)
    - ``/admin/``         -> Django admin panel
    - ``/api-auth/``      -> DRF browsable-API login (development only)

See Also:
    - api_router.py: ViewSet registration for all domain modules.
    - Django URL dispatcher: https://docs.djangoproject.com/en/5.2/topics/http/urls/
"""

from django.contrib import admin
from django.urls import path, include
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

# ── DRF / Django 5.x compatibility workaround ──────────────────────────────
# Django 5.1+ raises ValueError if a URL converter is registered twice.
# DRF's DefaultRouter calls format_suffix_patterns → register_converter
# for each router instance. Patch register_converter to be idempotent
# across all module-level references that DRF holds.
import django.urls.converters as _conv

_orig_register = _conv.register_converter

def _idempotent_register(converter, type_name):
    if type_name in _conv.REGISTERED_CONVERTERS:
        return  # Already registered — skip silently
    _orig_register(converter, type_name)

_conv.register_converter = _idempotent_register

# Patch the re-exported reference in django.urls
import django.urls as _django_urls
_django_urls.register_converter = _idempotent_register

# Patch DRF's module-level import of register_converter
try:
    import rest_framework.urlpatterns as _drf_urlpatterns
    _drf_urlpatterns.register_converter = _idempotent_register
except (ImportError, AttributeError):
    pass
# ────────────────────────────────────────────────────────────────────────────

from .api_router import router  # Centralised DRF DefaultRouter instance


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
            'admin': '/api/admin/',
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


# =============================================================================
# URL PATTERNS
# =============================================================================
# NOTE: The ``api/`` prefix is shared between the root view and the DRF router.
# Django matches top-down, so the explicit ``api_root`` view is tried first;
# unmatched paths fall through to the router-generated URL patterns.
urlpatterns = [
    # --- API Discovery / Health Check ---
    path('api/', api_root, name='api-root'),
    
    # --- Django Administration ---
    path('admin/', admin.site.urls),

    # --- Authentication (JWT obtain / refresh / register / logout) ---
    path('api/auth/', include('authentication.urls')),

    # --- Admin Panel API ---
    path('api/admin/', include('admin_panel.urls')),
    
    # --- Centralised REST Router ---
    # Habits, Analytics, Achievements, Insights, Notifications, Social, Settings
    path('api/', include(router.urls)),

    # --- DRF Browsable API Login (development convenience) ---
    path('api-auth/', include('rest_framework.urls')),
]
