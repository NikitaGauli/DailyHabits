"""
Copy this file's content into PythonAnywhere WSGI configuration file:
    /var/www/<your-pythonanywhere-username>_pythonanywhere_com_wsgi.py

Then click Reload in the PythonAnywhere Web tab.
"""

import os
import sys

PROJECT_PATH = "/home/<your-pythonanywhere-username>/Development/Backend/DailyHabits"
if PROJECT_PATH not in sys.path:
    sys.path.insert(0, PROJECT_PATH)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "DailyHabits.settings_pythonanywhere")

from django.core.wsgi import get_wsgi_application

application = get_wsgi_application()
