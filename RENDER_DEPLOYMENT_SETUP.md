# Render Deployment Setup Guide

## Critical Issue: Environment Variables

Your backend needs these environment variables set in Render dashboard to start successfully.

### 🚨 REQUIRED (App will not start without these)

1. **SECRET_KEY** (Generate a strong secret)
   - Generate: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`
   - Must be at least 50 characters and have high entropy
   - Example: `django-insecure-abcd1234...` (very long string)

2. **DEBUG**
   - Set to: `False`
   - (Already set in render.yaml, but verify)

3. **DATABASE_URL** (If using PostgreSQL on Render)
   - If you have a Render PostgreSQL database:
     - Create a PostgreSQL database in Render dashboard
     - Copy the connection string (e.g., `postgresql://user:pass@host:port/dbname`)
   - If using SQLite (development):
     - Leave this unset; Django will use SQLite file
     - ⚠️ SQLite works but is not recommended for production with multiple dynos

### ⚠️ RECOMMENDED (For full functionality)

4. **ALLOWED_HOSTS**
   - Set to: `yourdomain.onrender.com` (Render auto-generates this)
   - Or: `.onrender.com` (already in render.yaml)

5. **GOOGLE_CLIENT_ID**
   - Get from: https://console.cloud.google.com/
   - Create OAuth 2.0 credentials (Web application)
   - Add authorized redirect URIs:
     - `https://yourdomain.onrender.com/api/auth/google/`
     - `https://yourdomain.onrender.com/`
   - Example: `123456789-abc...googleusercontent.com`

6. **CORS_ALLOW_ALL_ORIGINS**
   - Set to: `False` (production security)
   - Then set **CORS_ALLOWED_ORIGINS** to your Flutter app domain(s)
   - Example: `https://app.example.com,https://web.example.com`

7. **Email Configuration** (for password resets, notifications)
   - `EMAIL_BACKEND`: `django.core.mail.backends.smtp.EmailBackend`
   - `EMAIL_HOST`: `smtp.gmail.com`
   - `EMAIL_PORT`: `587`
   - `EMAIL_USE_TLS`: `True`
   - `EMAIL_HOST_USER`: Your Gmail address
   - `EMAIL_HOST_PASSWORD`: Gmail App Password (16 chars from https://myaccount.google.com/apppasswords)
   - `DEFAULT_FROM_EMAIL`: `noreply@yourdomain.com`
   - `SUPPORT_EMAIL`: `support@yourdomain.com`

### 📋 Steps to Deploy on Render

1. **Create/Update Render Service:**
   - Go to https://render.com/dashboard
   - Create a new Web Service
   - Connect your GitHub repository
   - Select the `main` branch
   - Build command: (auto-detected from `render.yaml`)
   - Start command: (auto-detected from `render.yaml`)

2. **Set Environment Variables:**
   - Go to service settings → Environment
   - Add all variables from the "REQUIRED" and "RECOMMENDED" sections above
   - Example screenshot:
     ```
     SECRET_KEY = django-insecure-jkl9876543210...
     DEBUG = False
     DATABASE_URL = postgresql://...
     ALLOWED_HOSTS = myapi.onrender.com
     GOOGLE_CLIENT_ID = 123456...
     CORS_ALLOW_ALL_ORIGINS = False
     CORS_ALLOWED_ORIGINS = https://app.example.com
     ```

3. **Deploy:**
   - Click "Deploy" or redeploy from the dashboard
   - Monitor logs for errors
   - Check Health/Status

4. **Verify Deployment:**
   - API endpoint: `https://yourdomain.onrender.com/api/`
   - Admin panel: `https://yourdomain.onrender.com/admin/`
   - Both should load without 500 errors

### 🐛 Troubleshooting

**Error: "SECRET_KEY has less than 50 characters"**
- Generate a new one: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`

**Error: "ModuleNotFoundError: No module named 'requests'"**
- ✅ Already fixed in requirements.txt

**Error: "static files not collected"**
- ✅ render.yaml now includes `python manage.py collectstatic --noinput`

**Error: "database connection refused"**
- Make sure DATABASE_URL is correct and PostgreSQL is running on Render
- Or remove DATABASE_URL to use SQLite

**Error: "debug page showing in production"**
- Ensure `DEBUG=False` is set in environment variables

**Connection timeout to Render API**
- Check that `ALLOWED_HOSTS` includes the Render domain

### 📝 Files Modified in This Deployment

- `Backend/requirements.txt` - Added `requests` library
- `Backend/runtime.txt` - Python 3.12.3
- `Backend/Procfile` - Gunicorn startup (root level)
- `Backend/DailyHabits/DailyHabits/settings.py` - Updated static files, CORS, directories
- `Procfile` - Root-level entry point for Render
- `render.yaml` - Updated build/start commands and Python version
- `runtime.txt` - Root-level Python version

### ✅ Next Steps

1. [ ] Generate and set `SECRET_KEY` in Render
2. [ ] Create PostgreSQL database on Render (or use SQLite)
3. [ ] Set `DATABASE_URL` if using Postgres
4. [ ] Set `GOOGLE_CLIENT_ID` from Google Cloud Console
5. [ ] Configure email (optional, but recommended)
6. [ ] Deploy and monitor logs at https://dashboard.render.com

### 🚀 After Deployment

- Check logs for any startup errors
- Test API: `curl https://yourdomain.onrender.com/api/`
- Flutter app should point to: `https://yourdomain.onrender.com` (no trailing slash)
- Update Flutter frontend with new backend URL if deploying for first time
