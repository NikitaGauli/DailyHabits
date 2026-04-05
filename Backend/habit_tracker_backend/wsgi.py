"""Compatibility WSGI module.

This allows legacy start commands like:
    gunicorn habit_tracker_backend.wsgi:application

to run the real Django project located under Backend/DailyHabits.
"""

import os
import sys
from pathlib import Path

from django.core.wsgi import get_wsgi_application

BASE_DIR = Path(__file__).resolve().parent.parent
REAL_PROJECT_ROOT = BASE_DIR / 'DailyHabits'

# Ensure the real project root (contains manage.py and DailyHabits package)
# is importable when Render runs from Backend as the working directory.
if str(REAL_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(REAL_PROJECT_ROOT))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

application = get_wsgi_application()
