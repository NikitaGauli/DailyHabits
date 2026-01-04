# Daily Habits Backend

A Django REST Framework API for managing daily habits, tracking completions, and calculating streaks.

## Features

✅ **Habit Management**
- Create, read, update, delete habits
- Organize by category (Health, Productivity, Learning, Wellness)
- Color-coded habits with custom colors

✅ **Completion Tracking**
- Mark habits as complete for specific dates
- Add notes to completions
- View completion history with date ranges

✅ **Statistics & Analytics**
- Current and longest streak tracking
- Weekly completion percentages
- Total completion counts
- Weekly summary statistics

✅ **User-Specific Data**
- Multi-user support with authentication
- Each user only sees their own habits
- Token-based authentication

✅ **Database Indexes**
- Optimized queries for fast performance
- Indexes on frequently queried fields

## Project Structure

```
Backend/
├── DailyHabits/              # Main Django project
│   ├── DailyHabits/          # Project settings
│   │   ├── settings.py       # Django configuration
│   │   ├── urls.py           # URL routing
│   │   └── wsgi.py           # WSGI app
│   ├── habits/               # Habits app
│   │   ├── models.py         # Data models (Habit, HabitCompletion, HabitStats)
│   │   ├── views.py          # API viewsets
│   │   ├── serializers.py    # DRF serializers
│   │   ├── urls.py           # App URL routing
│   │   ├── admin.py          # Django admin configuration
│   │   ├── apps.py           # App configuration
│   │   ├── utils.py          # Utility functions
│   │   ├── tests.py          # Unit tests
│   │   └── management/       # Management commands
│   │       └── commands/
│   │           └── populate_sample_data.py
│   └── manage.py             # Django CLI
├── env/                      # Virtual environment
├── requirements.txt          # Python dependencies
└── API_DOCUMENTATION.md      # Detailed API docs
```

## Installation

### 1. Set up virtual environment
```bash
cd Backend
# Create virtual environment
python -m venv env
# Activate it
.\env\Scripts\activate  # Windows
source env/bin/activate  # macOS/Linux
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Run migrations
```bash
cd DailyHabits
python manage.py migrate
```

### 4. Create admin user
```bash
python manage.py createsuperuser
# Follow prompts to create admin account
```

### 5. Generate sample data (optional)
```bash
python manage.py populate_sample_data
```

## Running the Server

```bash
cd DailyHabits
python manage.py runserver
```

The server will start at `http://localhost:8000`

**API endpoints:** http://localhost:8000/api/
**Admin interface:** http://localhost:8000/admin/

## Database Models

### Habit
Core habit model with user association.

```python
Habit(
    user,              # FK to User
    title,             # Habit name
    description,       # Details
    category,          # Health/Productivity/Learning/Wellness
    color,             # Hex color code
    frequency,         # Days per week
    created_at,        # Auto timestamp
    updated_at,        # Auto timestamp
    is_active          # Boolean flag
)
```

### HabitCompletion
Records when a habit was completed.

```python
HabitCompletion(
    habit,             # FK to Habit
    completed_date,    # Date completed
    completed_at,      # Timestamp
    notes              # Optional notes
)
```

Constraints:
- One completion per habit per day (unique_together)

### HabitStats
Cached statistics for quick access.

```python
HabitStats(
    habit,                      # OneToOne FK to Habit
    current_streak,             # Consecutive days
    longest_streak,             # Best streak ever
    total_completions,          # Total count
    weekly_completions,         # This week's count
    last_completion_date,       # Most recent
    last_updated                # When stats updated
)
```

## API Overview

### Authentication
All endpoints require token authentication:
```
Authorization: Token YOUR_TOKEN_HERE
```

Get a token by creating a user in the admin interface or through a login endpoint.

### Main Endpoints

#### Habits
- `GET /api/habits/` - List user's habits
- `POST /api/habits/` - Create new habit
- `GET /api/habits/{id}/` - Get habit details
- `PUT/PATCH /api/habits/{id}/` - Update habit
- `DELETE /api/habits/{id}/` - Delete habit
- `GET /api/habits/todays_habits/` - Get today's habits
- `GET /api/habits/{id}/stats/` - Get habit statistics
- `GET /api/habits/{id}/completions/` - Get completion history
- `GET /api/habits/weekly_stats/` - Get weekly summary

#### Completions
- `POST /api/habits/{id}/mark_complete/` - Mark habit complete
- `POST /api/habits/{id}/unmark_complete/` - Remove completion
- `GET /api/completions/` - List all completions

#### Other
- `GET /api/habits/categories/` - Get available categories

See [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) for detailed endpoint documentation.

## Utility Functions

### `calculate_streak(habit)`
Calculates current streak by counting consecutive days backwards from today.

### `calculate_longest_streak(habit)`
Finds the longest consecutive days streak ever achieved.

### `calculate_weekly_completions(habit)`
Counts completions in current week (Monday-Sunday).

### `update_habit_stats(habit)`
Recalculates and updates all statistics for a habit.

### `get_user_dashboard_stats(user)`
Returns dashboard summary for a user across all habits.

## Testing

Run the test suite:
```bash
python manage.py test habits
```

Test coverage includes:
- Model creation and validation
- Streak calculation logic
- API endpoint functionality
- User-specific data isolation
- Completion tracking

## Configuration

### Settings File (DailyHabits/settings.py)

Key configurations:
- `DEBUG = True` (development)
- `DATABASES` - SQLite by default
- `REST_FRAMEWORK` - DRF authentication and pagination
- `CORS_ALLOWED_ORIGINS` - CORS settings for frontend

To run with a different database (PostgreSQL, MySQL), update the `DATABASES` setting.

### CORS Settings
Frontend URLs that can access the API:
```python
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",    # React frontend
    "http://localhost:8000",    # Development
]
```

## Admin Interface

Access at `http://localhost:8000/admin/` with your superuser account.

Features:
- Manage habits with auto-filtering by user
- View and edit completion records
- Monitor statistics
- Search by habit title or username

## Performance Optimizations

### Database Indexes
- `habits_habi_user_id_c66d7a_idx` - Fast user habit queries
- `habits_habi_user_id_f5e729_idx` - Fast user + active status queries
- `habits_habi_habit_i_9c550c_idx` - Fast habit completion lookups
- `habits_habi_complet_b49718_idx` - Fast date-based queries

### Caching
Statistics are cached in HabitStats model for O(1) retrieval.
Use `update_habit_stats()` to refresh when completions change.

### Query Optimization
ViewSets use `prefetch_related` and `select_related` to minimize database hits.

## Deployment

For production:
1. Set `DEBUG = False` in settings
2. Update `ALLOWED_HOSTS` with your domain
3. Use environment variables for `SECRET_KEY`
4. Configure a production database (PostgreSQL recommended)
5. Use a production WSGI server (Gunicorn, uWSGI)
6. Enable HTTPS/SSL
7. Set up proper CORS origins

Example environment variables:
```bash
DJANGO_SECRET_KEY=your-secret-key-here
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
DATABASE_URL=postgresql://user:password@localhost/habitdb
```

## Troubleshooting

### `No module named 'rest_framework'`
Install DRF: `pip install djangorestframework`

### `No module named 'corsheaders'`
Install CORS: `pip install django-cors-headers`

### Database errors
Run migrations: `python manage.py migrate`

### Admin login fails
Create a superuser: `python manage.py createsuperuser`

## Future Enhancements

- [ ] Social features (share habits, compare stats)
- [ ] Habit templates and presets
- [ ] Advanced analytics (charts, trends)
- [ ] Notifications and reminders
- [ ] Habit recommendations based on AI
- [ ] Export data (CSV, PDF)
- [ ] Backup and restore

## License

MIT License

## Support

For issues or questions, refer to the [API Documentation](./API_DOCUMENTATION.md).
