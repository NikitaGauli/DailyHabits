"""
Django Settings for DailyHabits Backend
========================================

Central configuration module for the DailyHabits project. This file controls
all Django framework behaviour, third-party integrations, and application-level
defaults for the habit-tracking platform.

Key configuration areas:
    - Security (SECRET_KEY, DEBUG, ALLOWED_HOSTS)
    - Installed applications & middleware pipeline
    - Database backend (SQLite for development)
    - REST Framework & JWT authentication
    - CORS policy for cross-origin Flutter client requests
    - Logging infrastructure

Environment variables are loaded from a ``.env`` file via ``python-dotenv``.
Sensitive values **must** be overridden through environment variables in
production deployments.

See Also:
    - Django settings reference: https://docs.djangoproject.com/en/5.2/ref/settings/
    - DRF settings: https://www.django-rest-framework.org/api-guide/settings/
    - SimpleJWT: https://django-rest-framework-simplejwt.readthedocs.io/
"""

import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

# Load environment variables from the .env file located at the project root.
# This must happen before any os.environ.get() calls below.
load_dotenv()

# BASE_DIR points to the outer DailyHabits/ directory that contains manage.py.
# All relative paths (DB, static, media, logs) are resolved from here.
BASE_DIR = Path(__file__).resolve().parent.parent

# =============================================================================
# SECURITY SETTINGS
# =============================================================================
# SECURITY WARNING: override SECRET_KEY via environment variable in production!
SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# SECURITY WARNING: never run with DEBUG=True in production!
DEBUG = False

# 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
ALLOWED_HOSTS = os.environ.get(
    'ALLOWED_HOSTS',
    'localhost,127.0.0.1,10.0.2.2,NikitaGauli11.pythonanywhere.com'
).split(',')

# =============================================================================
# GOOGLE OAUTH SETTINGS
# =============================================================================
# Web Client ID from Google Cloud Console — used to verify Google ID tokens
# sent by the Flutter frontend.  MUST be overridden via .env in production.
GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', '')

# =============================================================================
# APPLICATION DEFINITION
# =============================================================================
INSTALLED_APPS = [
    # --- Daphne ASGI server (must precede django.contrib.staticfiles) ---
    'daphne',

    # --- Jazzmin (must precede django.contrib.admin) ---
    'jazzmin',

    # --- Django built-in apps ---
    'django.contrib.admin',           # Admin site
    'django.contrib.auth',            # Core authentication framework
    'django.contrib.contenttypes',    # Content-type system for generic relations
    'django.contrib.sessions',        # Session framework
    'django.contrib.messages',        # Messaging framework
    'django.contrib.staticfiles',     # Static-file management

    # --- Third-party apps ---
    'rest_framework',                             # Django REST Framework
    'rest_framework_simplejwt',                   # JWT authentication
    'rest_framework_simplejwt.token_blacklist',   # Token revocation support
    'corsheaders',                                # Cross-Origin Resource Sharing
    'channels',                                   # Django Channels (WebSocket support)

    # --- Project apps (domain modules) ---
    'authentication',   # Custom user model, registration, login & token management
    'habits',           # Core habit CRUD and daily logging
    'analytics',        # Habit statistics, streaks & trend analysis
    'achievements',     # Badges, milestones & gamification rewards
    'notifications',    # Push notifications, smart tips & reminders
    'insights',         # AI/ML-driven personalised habit insights
    'social',           # Social sharing, friends, groups & activity feed
    'settings_app',     # User preferences, device tokens, exports & support
    'gamification',     # XP engine, challenges, leaderboards, virtual economy
    'grow_together',    # Grow Together — collaborative habit sharing system
    'admin_panel',      # Enterprise admin dashboard, RBAC, audit & moderation
]

# Middleware is processed top-to-bottom on requests, bottom-to-top on responses.
# Order matters — CORS must precede SecurityMiddleware, and WhiteNoise must
# come directly after SecurityMiddleware for correct static-file serving.
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',                 # CORS pre-flight handling (must be first)
    'django.middleware.security.SecurityMiddleware',         # HTTPS redirects, HSTS, etc.
    'whitenoise.middleware.WhiteNoiseMiddleware',            # Serve static files efficiently
    'django.contrib.sessions.middleware.SessionMiddleware',  # Session support
    'django.middleware.common.CommonMiddleware',             # URL normalisation & forbidden checks
    'django.middleware.csrf.CsrfViewMiddleware',            # CSRF protection
    'django.contrib.auth.middleware.AuthenticationMiddleware',  # Attach user to request
    'django.contrib.messages.middleware.MessageMiddleware',     # Flash messages
    'django.middleware.clickjacking.XFrameOptionsMiddleware',  # Clickjacking protection
]

# Points Django to the root URL configuration module.
ROOT_URLCONF = 'DailyHabits.urls'

# =============================================================================
# TEMPLATE ENGINE CONFIGURATION
# =============================================================================
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            BASE_DIR / 'templates',        # Project-level template overrides
        ],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# WSGI entry point used by traditional synchronous servers (Gunicorn, uWSGI).
WSGI_APPLICATION = 'DailyHabits.wsgi.application'

# =============================================================================
# ASGI & CHANNEL LAYER CONFIGURATION (Django Channels / WebSockets)
# =============================================================================
# ASGI entry point used by Daphne / Uvicorn for HTTP + WebSocket support.
ASGI_APPLICATION = 'DailyHabits.asgi.application'

# Channel layer backend — provides the message-passing infrastructure for
# WebSocket group communication (broadcasting notifications to user groups).
#
# Development:  InMemoryChannelLayer (single-process, no external dependency)
# Production:   Switch to RedisChannelLayer for multi-process / multi-server:
#
#     CHANNEL_LAYERS = {
#         'default': {
#             'BACKEND': 'channels_redis.core.RedisChannelLayer',
#             'CONFIG': {
#                 'hosts': [os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/0')],
#             },
#         },
#     }
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    },
}

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
# SQLite is used for local development. For production, swap to PostgreSQL or
# MySQL by changing ENGINE and providing the appropriate connection parameters.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# =============================================================================
# PASSWORD VALIDATION
# =============================================================================
# Validators run sequentially when a user sets or changes their password.
# MinimumLengthValidator is explicitly configured to require >= 8 characters.
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# =============================================================================
# INTERNATIONALIZATION
# =============================================================================
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kathmandu'   # NPT (UTC+05:45) — primary user base timezone
USE_I18N = True                 # Enable Django's translation / internationalisation system
USE_TZ = True                   # Store datetimes in UTC; convert to TIME_ZONE for display

# =============================================================================
# STATIC FILES
# =============================================================================
STATIC_URL = '/static/'                   # URL prefix for static assets
STATIC_ROOT = BASE_DIR / 'staticfiles'     # Destination for collectstatic output
# WhiteNoise serves static files with far-future Cache-Control headers and
# content-hash filenames for cache-busting in production.
STATICFILES_STORAGE = "whitenoise.storage.CompressedStaticFilesStorage"

# =============================================================================
# MEDIA FILES
# =============================================================================
MEDIA_URL = '/media/'              # URL prefix for user-uploaded content
MEDIA_ROOT = BASE_DIR / 'media'    # Filesystem path for user-uploaded files

# =============================================================================
# DEFAULT PRIMARY KEY
# =============================================================================
# BigAutoField provides 64-bit integer PKs, avoiding overflow on large tables.
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# =============================================================================
# CUSTOM USER MODEL
# =============================================================================
# Overrides Django's built-in User with the project's extended model.
# This MUST be set before the first migration is run.
AUTH_USER_MODEL = 'authentication.User'

# =============================================================================
# REST FRAMEWORK CONFIGURATION
# =============================================================================
REST_FRAMEWORK = {
    # JWT is the sole authentication backend — session auth is disabled for the API.
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    # All endpoints require authentication unless explicitly overridden.
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    # JSON-only API — no browsable HTML renderer in production.
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
    ],
    # Cursor-based pagination can be swapped in later for real-time feeds.
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    # Routes all API exceptions through a unified handler (see exceptions.py).
    'EXCEPTION_HANDLER': 'DailyHabits.exceptions.custom_exception_handler',
}

# =============================================================================
# JWT CONFIGURATION
# =============================================================================
SIMPLE_JWT = {
    # Token lifetimes — configurable via environment for different deployments.
    'ACCESS_TOKEN_LIFETIME': timedelta(days=int(os.environ.get('JWT_ACCESS_TOKEN_LIFETIME_DAYS', 1))),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=int(os.environ.get('JWT_REFRESH_TOKEN_LIFETIME_DAYS', 7))),

    # Rotate & blacklist: each refresh issues a new token pair and invalidates
    # the old refresh token, limiting the window for token reuse attacks.
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,

    # Stamp User.last_login on every token refresh for auditing.
    'UPDATE_LAST_LOGIN': True,
    
    # Signing configuration — HS256 with the project's SECRET_KEY.
    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,

    # Expected Authorization header format: "Bearer <token>"
    'AUTH_HEADER_TYPES': ('Bearer',),

    # Claims mapping
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
    'TOKEN_TYPE_CLAIM': 'token_type',
}

# =============================================================================
# CORS CONFIGURATION
# =============================================================================
# NOTE: CORS_ALLOW_ALL_ORIGINS should be False in production — restrict to
# the Flutter web domain (e.g., CORS_ALLOWED_ORIGINS list).
CORS_ALLOW_ALL_ORIGINS = os.environ.get('CORS_ALLOW_ALL_ORIGINS', 'True').lower() == 'true'
CORS_ALLOW_CREDENTIALS = True   # Required for cookie / Authorization-header flows
CORS_ALLOW_METHODS = ['DELETE', 'GET', 'OPTIONS', 'PATCH', 'POST', 'PUT']
CORS_ALLOW_HEADERS = [
    'accept', 'accept-encoding', 'authorization', 'content-type',
    'dnt', 'origin', 'user-agent', 'x-csrftoken', 'x-requested-with',
]

# =============================================================================
# EMAIL CONFIGURATION
# =============================================================================
# SMTP backend for production — use environment variables for credentials.
# For development, use the console backend to print emails to stdout.
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend',   # prints to stdout in dev
)
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'DailyHabits <noreply@dailyhabits.app>')
SUPPORT_EMAIL = os.environ.get('SUPPORT_EMAIL', 'support@dailyhabits.app')

# Deep-link base URL for the Flutter app's password-reset screen.
# Override in production for web-based reset flows.
PASSWORD_RESET_BASE_URL = os.environ.get(
    'PASSWORD_RESET_BASE_URL',
    'dailyhabits://reset-password',
)

# =============================================================================
# THROTTLE / RATE-LIMITING CONFIGURATION
# =============================================================================
# Cache-backed rate limiting for anonymous endpoints (password reset, etc.).
# Uses Django's default LocMemCache in dev; switch to Redis in production.
REST_FRAMEWORK_THROTTLE_RATES = {
    'password_reset_burst': '5/min',
    'password_reset_sustained': '20/hour',
    'validate_reset_token': '10/min',
    'reset_password': '5/min',
    'google_auth': '10/min',
}

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================
LOGGING = {
    'version': 1,                       # Dictconfig schema version (always 1)
    'disable_existing_loggers': False,   # Preserve third-party loggers

    # --- Formatters ---
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },

    # --- Handlers ---
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
        'file': {
            'class': 'logging.FileHandler',
            'filename': BASE_DIR / 'logs' / 'django.log',
            'formatter': 'verbose',
        },
    },

    # --- Root logger ---
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },

    # --- Per-module loggers ---
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': os.environ.get('DJANGO_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
        'habits': {
            'handlers': ['console'],
            'level': 'DEBUG',       # Verbose logging for core habit module during dev
            'propagate': False,
        },
        'authentication': {
            'handlers': ['console', 'file'],
            'level': 'INFO',        # Audit trail for password resets & auth events
            'propagate': False,
        },
        'admin_panel': {
            'handlers': ['console', 'file'],
            'level': 'INFO',        # Admin dashboard operations & audit events
            'propagate': False,
        },
    },
}

# Ensure the logs directory exists so the file handler doesn't raise on startup.
(BASE_DIR / 'logs').mkdir(exist_ok=True)

# =============================================================================
# JAZZMIN — ADMIN THEME CONFIGURATION
# =============================================================================
JAZZMIN_SETTINGS = {
    # ── Branding ──────────────────────────────────────────────────────────
    'site_title': 'DailyHabits Admin',
    'site_header': 'DailyHabits Super Admin',
    'site_brand': 'DailyHabits',
    'welcome_sign': 'Welcome to the DailyHabits Platform Control Center',
    'copyright': 'DailyHabits Platform',
    'site_logo': None,
    'login_logo': None,
    'site_icon': None,

    # ── Search bar ────────────────────────────────────────────────────────
    'search_model': ['authentication.User', 'habits.Habit'],

    # ── Top menu (user dropdown) ──────────────────────────────────────────
    'topmenu_links': [
        {'name': 'Dashboard', 'url': 'admin:index', 'permissions': ['auth.view_user']},
        {'name': 'API Root', 'url': '/api/', 'new_window': True},
        {'model': 'authentication.User'},
    ],

    # ── Side menu configuration ───────────────────────────────────────────
    'show_sidebar': True,
    'navigation_expanded': False,
    'hide_apps': [],
    'hide_models': [],
    'order_with_respect_to': [
        'authentication',
        'habits',
        'analytics',
        'achievements',
        'gamification',
        'grow_together',
        'social',
        'notifications',
        'insights',
        'settings_app',
        'admin_panel',
    ],

    # ── Icons (Font Awesome 5 free icons) ─────────────────────────────────
    'icons': {
        # Authentication
        'authentication': 'fas fa-users-cog',
        'authentication.User': 'fas fa-user',
        'authentication.LoginActivity': 'fas fa-sign-in-alt',
        'authentication.DataDeletionRequest': 'fas fa-user-slash',
        # Habits
        'habits': 'fas fa-tasks',
        'habits.Category': 'fas fa-tags',
        'habits.Habit': 'fas fa-check-circle',
        'habits.HabitLog': 'fas fa-clipboard-list',
        'habits.Streak': 'fas fa-fire',
        'habits.HabitCompletion': 'fas fa-check-double',
        # Analytics
        'analytics': 'fas fa-chart-line',
        'analytics.DailySummary': 'fas fa-calendar-day',
        'analytics.WeeklySummary': 'fas fa-calendar-week',
        'analytics.MonthlySummary': 'fas fa-calendar-alt',
        'analytics.HabitAnalytics': 'fas fa-chart-bar',
        # Achievements
        'achievements': 'fas fa-trophy',
        'achievements.Achievement': 'fas fa-medal',
        'achievements.UserAchievement': 'fas fa-award',
        'achievements.UserLevel': 'fas fa-layer-group',
        'achievements.Reward': 'fas fa-gift',
        'achievements.UserReward': 'fas fa-star',
        # Gamification
        'gamification': 'fas fa-gamepad',
        'gamification.XPEvent': 'fas fa-bolt',
        'gamification.StreakFreeze': 'fas fa-snowflake',
        'gamification.Challenge': 'fas fa-flag-checkered',
        'gamification.ChallengeParticipant': 'fas fa-user-check',
        'gamification.LeaderboardEntry': 'fas fa-sort-amount-up',
        'gamification.VirtualCurrency': 'fas fa-coins',
        'gamification.CurrencyTransaction': 'fas fa-exchange-alt',
        'gamification.DailyBonus': 'fas fa-calendar-check',
        'gamification.MilestoneReward': 'fas fa-gem',
        # Grow Together
        'grow_together': 'fas fa-people-carry',
        'grow_together.CollaborativeHabit': 'fas fa-hands-helping',
        'grow_together.CollaborativeHabitMember': 'fas fa-user-friends',
        'grow_together.AbuseReport': 'fas fa-exclamation-triangle',
        # Social
        'social': 'fas fa-share-alt',
        'social.ShareCard': 'fas fa-id-card',
        'social.ReferralLink': 'fas fa-link',
        'social.GroupHabit': 'fas fa-users',
        # Notifications
        'notifications': 'fas fa-bell',
        'notifications.Notification': 'fas fa-envelope',
        'notifications.HabitReminder': 'fas fa-alarm-clock',
        # Insights
        'insights': 'fas fa-lightbulb',
        'insights.MotivationalQuote': 'fas fa-quote-left',
        'insights.UserInsight': 'fas fa-brain',
        # Settings
        'settings_app': 'fas fa-cog',
        'settings_app.UserSettings': 'fas fa-user-cog',
        'settings_app.SupportTicket': 'fas fa-ticket-alt',
        'settings_app.FAQ': 'fas fa-question-circle',
        # Admin Panel
        'admin_panel': 'fas fa-shield-alt',
        'admin_panel.AdminRole': 'fas fa-user-shield',
        'admin_panel.AdminProfile': 'fas fa-id-badge',
        'admin_panel.AuditLog': 'fas fa-history',
        'admin_panel.Report': 'fas fa-flag',
        'admin_panel.ContentModerationQueue': 'fas fa-gavel',
        'admin_panel.UserWarning': 'fas fa-exclamation-circle',
        'admin_panel.SystemSettings': 'fas fa-sliders-h',
        'admin_panel.FeatureFlag': 'fas fa-toggle-on',
        'admin_panel.NotificationTemplate': 'fas fa-file-alt',
        'admin_panel.NotificationCampaign': 'fas fa-bullhorn',
        'admin_panel.PlatformAnalyticsSnapshot': 'fas fa-camera',
        'admin_panel.AISafetyLog': 'fas fa-robot',
        'admin_panel.AIUserRestriction': 'fas fa-ban',
        # Auth (default Django)
        'auth': 'fas fa-lock',
        'auth.Group': 'fas fa-users-cog',
    },
    'default_icon_parents': 'fas fa-folder',
    'default_icon_children': 'fas fa-circle',

    # ── Related modal ─────────────────────────────────────────────────────
    'related_modal_active': True,

    # ── Custom CSS/JS ─────────────────────────────────────────────────────
    'custom_css': 'admin/css/custom_admin.css',
    'custom_js': 'admin/js/dashboard_charts.js',

    # ── Changeform tweaks ─────────────────────────────────────────────────
    'changeform_format': 'horizontal_tabs',
    'changeform_format_overrides': {
        'authentication.User': 'collapsible',
        'admin_panel.AuditLog': 'single',
    },

    # ── Show UI Builder link ──────────────────────────────────────────────
    'show_ui_builder': False,
}

JAZZMIN_UI_TWEAKS = {
    'navbar_small_text': False,
    'footer_small_text': False,
    'body_small_text': False,
    'brand_small_text': False,
    'brand_colour': 'navbar-indigo',
    'accent': 'accent-primary',
    'navbar': 'navbar-indigo navbar-dark',
    'no_navbar_border': False,
    'navbar_fixed': True,
    'layout_boxed': False,
    'footer_fixed': False,
    'sidebar_fixed': True,
    'sidebar': 'sidebar-dark-indigo',
    'sidebar_nav_small_text': False,
    'sidebar_disable_expand': False,
    'sidebar_nav_child_indent': True,
    'sidebar_nav_compact_style': False,
    'sidebar_nav_legacy_style': False,
    'sidebar_nav_flat_style': False,
    'theme': 'default',
    'dark_mode_theme': None,
    'button_classes': {
        'primary': 'btn-primary',
        'secondary': 'btn-secondary',
        'info': 'btn-info',
        'warning': 'btn-warning',
        'danger': 'btn-danger',
        'success': 'btn-success',
    },
}

# =============================================================================
# CELERY — BACKGROUND TASK QUEUE
# =============================================================================
# Broker URL — Redis is required for production. Falls back to memory://
# for lightweight development without Redis.
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', 'redis://127.0.0.1:6379/0')
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'redis://127.0.0.1:6379/0')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_ENABLE_UTC = True
