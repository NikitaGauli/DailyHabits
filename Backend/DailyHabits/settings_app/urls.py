"""
Settings App — URL Configuration
=================================

This module intentionally defines an empty ``urlpatterns`` list.

All settings-app ViewSets are registered with the DRF ``DefaultRouter``
in the centralised API router at ``DailyHabits/api_router.py`` rather
than using per-app URL includes.  This keeps route registration
consistent across the project and avoids duplicated prefixes.

See Also:
    ``DailyHabits.api_router`` for the canonical route table.
"""

# =============================================================================
# URL PATTERNS
# =============================================================================

urlpatterns = []  # Routes are registered centrally in DailyHabits/api_router.py
