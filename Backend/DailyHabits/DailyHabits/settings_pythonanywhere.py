"""
Production settings for deploying DailyHabits on PythonAnywhere.

Usage:
    Set DJANGO_SETTINGS_MODULE=DailyHabits.settings_pythonanywhere
"""

import os

from .settings import *


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_list(name: str, default: str = "") -> list[str]:
    raw = os.environ.get(name, default)
    return [item.strip() for item in raw.split(",") if item.strip()]


DEBUG = False

# Always set SECRET_KEY in PythonAnywhere web app environment variables.
SECRET_KEY = os.environ.get("SECRET_KEY", SECRET_KEY)
if SECRET_KEY == "dev-secret-key-change-in-production":
    raise RuntimeError("SECRET_KEY must be set to a strong production value.")

ALLOWED_HOSTS = _env_list(
    "ALLOWED_HOSTS",
    "<your-pythonanywhere-username>.pythonanywhere.com",
)

# PythonAnywhere terminates SSL at the proxy layer.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = _env_bool("SECURE_SSL_REDIRECT", True)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = int(os.environ.get("SECURE_HSTS_SECONDS", "31536000"))
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
X_FRAME_OPTIONS = "DENY"
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True

# Keep CORS locked down in production.
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = _env_list("CORS_ALLOWED_ORIGINS", "")

# CSRF trusted origins should be full scheme+host entries.
CSRF_TRUSTED_ORIGINS = _env_list("CSRF_TRUSTED_ORIGINS", "")

# Keep static/media paths explicit for collectstatic and uploaded files.
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_ROOT = BASE_DIR / "media"

# PythonAnywhere free plans do not provide always-on workers for Celery.
# Run tasks eagerly in-process by default so task calls still execute.
CELERY_TASK_ALWAYS_EAGER = _env_bool("CELERY_TASK_ALWAYS_EAGER", True)
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "memory://")
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "cache+memory://")

# Keep logs in project folder.
LOGGING["handlers"]["file"]["filename"] = BASE_DIR / "logs" / "django.log"
