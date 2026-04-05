# PythonAnywhere Deployment Guide (DailyHabits Backend)

This guide deploys your Django backend from this repository to PythonAnywhere in a production-safe way.

## 1. Prerequisites

- A PythonAnywhere account
- Your code pushed to GitHub (recommended)
- Python version on PythonAnywhere compatible with your dependencies (3.10+ recommended)

## 2. Clone Project on PythonAnywhere

Open a **Bash console** on PythonAnywhere and run:

```bash
cd ~
git clone <your-repo-url> Development
cd Development/Backend
python3.10 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

If your PythonAnywhere image has a different Python minor version, replace `python3.10` accordingly.

## 3. Set Environment Variables

In PythonAnywhere:

- Go to **Web** tab
- Open your web app
- Add variables from [Backend/.env.pythonanywhere.example](.env.pythonanywhere.example)

Minimum required:

- `SECRET_KEY`
- `ALLOWED_HOSTS`
- `CORS_ALLOWED_ORIGINS`
- `CSRF_TRUSTED_ORIGINS`

## 4. Configure WSGI File

Use PythonAnywhere web app type: **Manual configuration -> Django** (or existing app).

Edit the WSGI config file:

- `/var/www/<your-pythonanywhere-username>_pythonanywhere_com_wsgi.py`

Replace its content with [Backend/pythonanywhere_wsgi_template.py](pythonanywhere_wsgi_template.py), then update:

- `<your-pythonanywhere-username>` in `PROJECT_PATH`

Expected project path for this repo layout:

- `/home/<your-pythonanywhere-username>/Development/Backend/DailyHabits`

## 5. Install and Migrate

In a PythonAnywhere Bash console:

```bash
cd ~/Development/Backend
source .venv/bin/activate
cd DailyHabits
python manage.py migrate --settings=DailyHabits.settings_pythonanywhere
python manage.py collectstatic --noinput --settings=DailyHabits.settings_pythonanywhere
python manage.py createsuperuser --settings=DailyHabits.settings_pythonanywhere
```

## 6. Static and Media Mapping (Web Tab)

In PythonAnywhere **Web -> Static files**, add:

- URL: `/static/` -> Directory: `/home/<your-pythonanywhere-username>/Development/Backend/DailyHabits/staticfiles`
- URL: `/media/` -> Directory: `/home/<your-pythonanywhere-username>/Development/Backend/DailyHabits/media`

## 7. Reload Web App

In PythonAnywhere Web tab, click **Reload**.

Then test:

- `https://<your-pythonanywhere-username>.pythonanywhere.com/api/`
- `https://<your-pythonanywhere-username>.pythonanywhere.com/admin/`

## 8. Scheduled Notifications Without Celery Workers

PythonAnywhere free plans are not designed for always-on Celery workers. This project includes a management command fallback.

Add a **Scheduled task** in PythonAnywhere:

```bash
cd /home/<your-pythonanywhere-username>/Development/Backend/DailyHabits && /home/<your-pythonanywhere-username>/Development/Backend/.venv/bin/python manage.py send_reminders --settings=DailyHabits.settings_pythonanywhere
```

Suggested cadence: every 5-15 minutes.

## 9. Common Issues

### `DisallowedHost`

Add your exact hostname to `ALLOWED_HOSTS`, for example:

```text
myuser.pythonanywhere.com
```

### 403 CSRF errors

Ensure frontend + backend origins are set in:

- `CSRF_TRUSTED_ORIGINS`
- `CORS_ALLOWED_ORIGINS`

Both must include scheme, for example `https://...`.

### Static files not loading

- Re-run `collectstatic`
- Confirm static mapping path exactly matches your filesystem

### 500 error after deploy

Check logs in PythonAnywhere:

- Web tab -> **Error log**
- Web tab -> **Server log**

## 10. Security Checklist

- `DEBUG=False`
- Strong `SECRET_KEY`
- Only trusted domains in CORS/CSRF lists
- Keep dependencies updated (`pip list --outdated`)
- Rotate email/API credentials periodically
