web: cd Backend/DailyHabits && python manage.py migrate --noinput && gunicorn DailyHabits.wsgi:application --bind 0.0.0.0:$PORT --workers 2 --timeout 120
