"""
Habits URL Configuration
========================

Registers the DRF routers that map HTTP endpoints to the habits ViewSets.

Routes generated:
    /habits/                     → HabitViewSet   (list, create)
    /habits/<pk>/                → HabitViewSet   (retrieve, update, destroy)
    /habits/today/               → HabitViewSet.today
    /habits/<pk>/toggle-complete/ → HabitViewSet.toggle_complete
    /habits/<pk>/skip/           → HabitViewSet.skip
    /habits/<pk>/history/        → HabitViewSet.history
    /habits/<pk>/stats/          → HabitViewSet.stats
    /habits/categories/          → HabitViewSet.categories
    /habits/stats_summary/       → HabitViewSet.stats_summary
    /habits/<pk>/pause/          → HabitViewSet.pause
    /habits/<pk>/resume/         → HabitViewSet.resume
    /habits/reorder/             → HabitViewSet.reorder
    /habits/<pk>/partial-complete/ → HabitViewSet.partial_complete
    /habit-logs/                 → HabitLogViewSet (list)

All routes are nested under the project-level ``/api/`` prefix defined
in the root ``urls.py``.

Authors:
    DailyHabits Engineering Team

Since:
    v1.0.0
"""

# === Django / DRF Imports ====================================================
from django.urls import path, include
from rest_framework.routers import DefaultRouter

# === Local Imports ===========================================================
from .views import HabitViewSet, HabitLogViewSet

# =============================================================================
# Router Registration
# =============================================================================

router = DefaultRouter()
router.register(r'habits', HabitViewSet, basename='habits')         # /habits/*
router.register(r'habit-logs', HabitLogViewSet, basename='habit-logs')  # /habit-logs/*

# =============================================================================
# URL Patterns
# =============================================================================

urlpatterns = [
    path('', include(router.urls)),  # Include all router-generated routes
]
