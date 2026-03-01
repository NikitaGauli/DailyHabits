"""
admin_panel/permissions.py — RBAC Permission Classes
=====================================================
Every admin API endpoint uses one of these permissions to enforce
role-based access control.  Permission keys follow the pattern:

    <resource>.<action>

Examples:
    users.view, users.edit, users.suspend, users.delete
    moderation.view, moderation.approve, moderation.reject
    analytics.view, analytics.export
    settings.view, settings.edit
    gamification.view, gamification.edit
    notifications.view, notifications.send
    audit.view
    ai_safety.view, ai_safety.manage
"""

from rest_framework.permissions import BasePermission


# ═══════════════════════════════════════════════════════════════════════════════
#  Base Admin Permission
# ═══════════════════════════════════════════════════════════════════════════════

class IsAdminUser(BasePermission):
    """
    Allow access only to users with an active AdminProfile.
    This is the base gate — all admin endpoints require this at minimum.
    """

    message = 'Admin access required.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return hasattr(request.user, 'admin_profile') and request.user.admin_profile.is_active


class HasAdminPermission(BasePermission):
    """
    Generic permission check against the admin's role permissions list.

    Usage on a view::

        class SomeView(APIView):
            permission_classes = [HasAdminPermission]
            required_permission = 'users.view'

    Or via ``get_required_permission()`` for action-level granularity.
    """

    message = 'You do not have the required admin permission.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        profile = getattr(request.user, 'admin_profile', None)
        if not profile or not profile.is_active:
            return False

        # Determine the required permission key
        perm = getattr(view, 'required_permission', None)
        if perm is None and hasattr(view, 'get_required_permission'):
            perm = view.get_required_permission()
        if perm is None:
            # No specific permission declared — fall back to admin-only gate
            return True

        return profile.has_permission(perm)


# ═══════════════════════════════════════════════════════════════════════════════
#  Resource-Specific Permission Classes
# ═══════════════════════════════════════════════════════════════════════════════

class _AdminPerm(BasePermission):
    """Internal helper that checks a single permission key."""

    perm_key: str = ''

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        profile = getattr(request.user, 'admin_profile', None)
        if not profile or not profile.is_active:
            return False
        return profile.has_permission(self.perm_key)


# ── Users ─────────────────────────────────────────────────────────────────────

class CanViewUsers(_AdminPerm):
    perm_key = 'users.view'
    message = 'Permission denied: users.view required.'


class CanEditUsers(_AdminPerm):
    perm_key = 'users.edit'
    message = 'Permission denied: users.edit required.'


class CanSuspendUsers(_AdminPerm):
    perm_key = 'users.suspend'
    message = 'Permission denied: users.suspend required.'


class CanDeleteUsers(_AdminPerm):
    perm_key = 'users.delete'
    message = 'Permission denied: users.delete required.'


# ── Moderation ────────────────────────────────────────────────────────────────

class CanViewModeration(_AdminPerm):
    perm_key = 'moderation.view'
    message = 'Permission denied: moderation.view required.'


class CanModerateContent(_AdminPerm):
    perm_key = 'moderation.approve'
    message = 'Permission denied: moderation.approve required.'


# ── Analytics ─────────────────────────────────────────────────────────────────

class CanViewAnalytics(_AdminPerm):
    perm_key = 'analytics.view'
    message = 'Permission denied: analytics.view required.'


class CanExportAnalytics(_AdminPerm):
    perm_key = 'analytics.export'
    message = 'Permission denied: analytics.export required.'


# ── Settings ──────────────────────────────────────────────────────────────────

class CanViewSettings(_AdminPerm):
    perm_key = 'settings.view'
    message = 'Permission denied: settings.view required.'


class CanEditSettings(_AdminPerm):
    perm_key = 'settings.edit'
    message = 'Permission denied: settings.edit required.'


# ── Gamification ──────────────────────────────────────────────────────────────

class CanViewGamification(_AdminPerm):
    perm_key = 'gamification.view'
    message = 'Permission denied: gamification.view required.'


class CanEditGamification(_AdminPerm):
    perm_key = 'gamification.edit'
    message = 'Permission denied: gamification.edit required.'


# ── Notifications ─────────────────────────────────────────────────────────────

class CanViewNotifications(_AdminPerm):
    perm_key = 'notifications.view'
    message = 'Permission denied: notifications.view required.'


class CanSendNotifications(_AdminPerm):
    perm_key = 'notifications.send'
    message = 'Permission denied: notifications.send required.'


# ── Audit ─────────────────────────────────────────────────────────────────────

class CanViewAuditLogs(_AdminPerm):
    perm_key = 'audit.view'
    message = 'Permission denied: audit.view required.'


# ── AI Safety ─────────────────────────────────────────────────────────────────

class CanViewAISafety(_AdminPerm):
    perm_key = 'ai_safety.view'
    message = 'Permission denied: ai_safety.view required.'


class CanManageAISafety(_AdminPerm):
    perm_key = 'ai_safety.manage'
    message = 'Permission denied: ai_safety.manage required.'


# ── Feature Flags ─────────────────────────────────────────────────────────────

class CanManageFeatureFlags(_AdminPerm):
    perm_key = 'feature_flags.manage'
    message = 'Permission denied: feature_flags.manage required.'


# ═══════════════════════════════════════════════════════════════════════════════
#  Role → Default Permissions Mapping (used by seed migration)
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_ROLE_PERMISSIONS = {
    'super_admin': ['*'],  # God mode
    'admin': [
        'users.*', 'moderation.*', 'analytics.*', 'settings.*',
        'gamification.*', 'notifications.*', 'audit.view',
        'ai_safety.*', 'feature_flags.manage',
    ],
    'moderator': [
        'users.view', 'moderation.*', 'analytics.view',
        'notifications.view', 'ai_safety.view',
    ],
    'support': [
        'users.view', 'users.edit', 'moderation.view',
        'analytics.view', 'notifications.view',
    ],
    'analytics': [
        'analytics.*',
    ],
}
