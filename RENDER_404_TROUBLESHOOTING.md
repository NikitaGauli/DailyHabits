# Why You're Getting 404 on Render

## Root Cause: Missing Environment Variables

Your Django app **is running** but can't fully initialize because it's missing critical environment variables.

When you access `https://dailyhabits.onrender.com/`, Django returns 404 because:
1. The app might not have completed startup (missing env vars)
2. Migrations haven't run (no database initialized)
3. The root `/` path is now redirected to `/api/` (should work after fixes)

---

## 🔴 The 404 Error Explained

```
Not Found
The requested resource was not found on this server.
```

**What this means:**
- ✅ Render service started
- ✅ Django app is responding
- ❌ Django doesn't have a handler for that route
- ❌ OR the app crashed during initialization

---

## ⚡ Quick Fixes (Do These NOW)

### 1. **Check Render Logs**
Go to: **https://dashboard.render.com** → Select your service → Logs

Look for:
- `ERROR` or `CRITICAL` messages
- `ModuleNotFoundError` (missing dependency)
- `django.core.exceptions.ImproperlyConfigured` (missing env var)
- `psycopg2.OperationalError` (database connection failed)

### 2. **Set Missing Environment Variables**

Go to: **https://dashboard.render.com** → Your Service → Environment

Add **immediately**:

```
SECRET_KEY = django-insecure-<very-long-random-string-50+-chars>
DEBUG = False
```

**To generate SECRET_KEY**, run locally:
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### 3. **Redeploy**

Click **"Redeploy"** or push a new commit to trigger rebuild:
```bash
git commit --allow-empty -m "Force Render redeploy"
git push origin main
```

---

## 📋 Common 404 Causes & Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| 404 on all routes | App crashed at startup | Check Logs for `ERROR` or `CRITICAL` |
| 404 on `/api/` | `SECRET_KEY` not set | Add `SECRET_KEY` env var |
| 404 on `/api/` | Migrations haven't run | Procfile now includes `python manage.py migrate --noinput` |
| 404 on `/admin/` | `DEBUG=False` (correct) | Use `/api/` instead; admin requires auth |
| `Internal Server Error` | Exception in code | Check Logs for traceback |

---

## ✅ Test Your API

Once env vars are set, test these endpoints:

```bash
# Health check (should return JSON with API info)
curl https://dailyhabits.onrender.com/api/

# Admin panel (requires login)
https://dailyhabits.onrender.com/admin/

# API endpoints (may require JWT token)
curl https://dailyhabits.onrender.com/api/habits/
curl https://dailyhabits.onrender.com/api/analytics/
```

Expected response from `/api/`:
```json
{
  "status": "online",
  "version": "2.0.0",
  "api": "DailyHabits API",
  "endpoints": {
    "auth": "/api/auth/",
    "habits": "/api/habits/",
    ...
  }
}
```

---

## 🚀 What We Fixed

- ✅ **Added root redirect** → `https://domain.com/` now redirects to `/api/`
- ✅ **Updated Procfile** → Runs `migrate` on every deployment
- ✅ **Updated render.yaml** → Proper build/start commands

---

## 📝 Environment Variables Checklist

- [ ] **SECRET_KEY** - Set to a long random string
- [ ] **DEBUG** - Set to `False`
- [ ] **DATABASE_URL** - Set to PostgreSQL connection (or leave blank for SQLite)
- [ ] **ALLOWED_HOSTS** - Usually auto-handled by Render
- [ ] **GOOGLE_CLIENT_ID** - Get from Google Cloud Console (optional but needed for auth)

---

## 🔍 How to Check If It's Working

1. Go to Render dashboard logs
2. Look for: `Starting development server at 0.0.0.0:PORT` or `[INFO] Listening at: 0.0.0.0:PORT`
3. Check for errors like:
   - `django.core.exceptions.ImproperlyConfigured: CSRF_COOKIE_SECURE must be set to True`
   - This means env vars are working but need fine-tuning

---

## ❓ Still Seeing 404?

1. **Check Render logs** (most important!)
   - Go to service → Logs
   - Search for `ERROR` or `Traceback`
   
2. **Verify SECRET_KEY is set**
   - Environment → Click each var to confirm it's there
   
3. **Check build log**
   - Go to Deployments → Latest → View Log
   - Look for failed migration or collectstatic errors

4. **Force redeploy**
   ```bash
   git commit --allow-empty -m "Redeploy"
   git push origin main
   ```

5. **Test locally first**
   ```bash
   cd Backend/DailyHabits
   export SECRET_KEY="$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')"
   export DEBUG=False
   python manage.py runserver
   ```

---

## 📞 Next Steps

1. **Set SECRET_KEY and DEBUG in Render** (this is blocking you!)
2. **Check Render logs** for any errors
3. **Test `/api/` endpoint** → Should work
4. **Set DATABASE_URL** if using Postgres
5. **Set GOOGLE_CLIENT_ID** for authentication

**Once these are set, you should see:**
✅ API responding at `/api/`
✅ Admin at `/admin/` (requires login)
✅ No 404 errors

Let me know what errors you see in the Render logs!
