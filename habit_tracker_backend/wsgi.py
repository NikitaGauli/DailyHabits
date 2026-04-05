"""Root-level compatibility WSGI module.

Supports legacy Render start command:
    gunicorn habit_tracker_backend.wsgi:application

for this repository layout where the actual Django project package lives at:
    Backend/DailyHabits/DailyHabits
"""

import os
import sys
from pathlib import Path

from django.core.wsgi import get_wsgi_application

REPO_ROOT = Path(__file__).resolve().parent.parent
REAL_PROJECT_ROOT = REPO_ROOT / 'Backend' / 'DailyHabits'

# Ensure the real project root (contains manage.py and DailyHabits package)
# is importable regardless of Render working directory.
if str(REAL_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(REAL_PROJECT_ROOT))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')

application = get_wsgi_application()
