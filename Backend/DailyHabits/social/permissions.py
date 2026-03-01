"""
Social Permissions — Custom DRF Permission Classes
===================================================

Provides fine-grained access control for the habit sharing and community
engagement features.  These permissions are designed for **defense-in-depth**:
even if the Flutter frontend hides certain buttons or screens, the backend
independently enforces every access rule.

Permission Classes:
    - ``IsHabitOwner``         — Only the habit's creator can modify sharing.
    - ``CanViewSharedHabit``   — Owner, shared-with friend, or public viewers.
    - ``IsFriend``             — Verifies an accepted friendship exists.

Why backend validation is required:
    Frontend UI can be bypassed by direct API calls (Postman, curl, scripts).
    Permissions must be enforced server-side to prevent:
    - Unauthorized access to private habits
    - Sharing with non-friends
    - Reactions/comments from users without visibility access
"""

from rest_framework.permissions import BasePermission

from .models import Friendship, SharedHabit


# ═══════════════════════════════════════════════════════════════════════════
#  IS HABIT OWNER — Write Access Guard
# ═══════════════════════════════════════════════════════════════════════════


class IsHabitOwner(BasePermission):
    """
    Allows access only if the requesting user owns the target habit.

    Used on share/unshare/visibility-change endpoints to ensure only
    the habit creator can modify sharing settings.

    Usage:
        Apply as ``permission_classes = [IsAuthenticated, IsHabitOwner]``
        on ViewSet actions that require ownership.

    Object-level check:
        ``has_object_permission`` inspects ``obj.user`` (the habit's owner)
        against ``request.user``.
    """

    message = 'You do not own this habit.'

    def has_object_permission(self, request, view, obj):
        """
        Return ``True`` only if ``request.user`` is the habit owner.

        Args:
            request: The incoming DRF request.
            view: The view handling the request.
            obj: The ``Habit`` instance being accessed.

        Returns:
            bool: ``True`` if user owns the habit, ``False`` otherwise.
        """
        return obj.user == request.user


# ═══════════════════════════════════════════════════════════════════════════
#  CAN VIEW SHARED HABIT — Read Access Guard
# ═══════════════════════════════════════════════════════════════════════════


class CanViewSharedHabit(BasePermission):
    """
    Grants read access based on the habit's visibility and sharing state.

    Access is granted if **any** of the following conditions is met:
        1. The user is the habit **owner**.
        2. The habit has ``visibility='public'``.
        3. The habit has ``visibility='friends_only'`` AND the user is
           a confirmed friend of the owner.
        4. An explicit ``SharedHabit`` record exists linking the habit
           to the requesting user.

    Denied access returns a ``403 Forbidden`` with a descriptive message.
    """

    message = 'You do not have permission to view this habit.'

    def has_object_permission(self, request, view, obj):
        """
        Check whether the requesting user can view the given habit.

        Args:
            request: The incoming DRF request.
            view: The view handling the request.
            obj: The ``Habit`` instance being accessed.

        Returns:
            bool: ``True`` if the user has view access.
        """
        user = request.user

        # ── 1. Owner always has access ────────────────────────────────
        if obj.user == user:
            return True

        # ── 2. Public habits are visible to everyone ──────────────────
        if obj.visibility == 'public':
            return True

        # ── 3. Explicitly shared with this user ───────────────────────
        if SharedHabit.objects.filter(habit=obj, shared_with=user).exists():
            return True

        # ── 4. Friends-only + user is a confirmed friend ──────────────
        if obj.visibility == 'friends_only':
            return _are_friends(obj.user, user)

        # ── 5. Default deny ──────────────────────────────────────────
        return False


# ═══════════════════════════════════════════════════════════════════════════
#  IS FRIEND — Friendship Verification Guard
# ═══════════════════════════════════════════════════════════════════════════


class IsFriend(BasePermission):
    """
    Verifies that an accepted friendship exists between the requesting
    user and the target user.

    This permission is typically used **inline** within view logic
    (via the ``_are_friends`` helper) rather than as a class-level
    ``permission_classes`` entry, because the "target user" varies
    by endpoint context.

    The class form is provided for endpoints where the target user is
    derivable from the URL object (e.g. ``obj.user``).
    """

    message = 'You are not friends with this user.'

    def has_object_permission(self, request, view, obj):
        """
        Check for an accepted friendship between ``request.user``
        and ``obj.user``.

        Args:
            request: The incoming DRF request.
            view: The view handling the request.
            obj: An object whose ``.user`` attribute is the target user.

        Returns:
            bool: ``True`` if an accepted friendship exists.
        """
        return _are_friends(request.user, obj.user)


# ═══════════════════════════════════════════════════════════════════════════
#  HELPER — Friendship Check (used by multiple permission classes)
# ═══════════════════════════════════════════════════════════════════════════


def _are_friends(user_a, user_b):
    """
    Return ``True`` if ``user_a`` and ``user_b`` are confirmed friends.

    Checks both directions of the ``Friendship`` model since friendships
    are stored unidirectionally (from_user → to_user).

    Args:
        user_a: First ``User`` instance.
        user_b: Second ``User`` instance.

    Returns:
        bool: ``True`` if an accepted ``Friendship`` exists in either
              direction, ``False`` otherwise.
    """
    return Friendship.objects.filter(
        status='accepted',
    ).filter(
        # Either direction — friendship is bidirectional
        models_Q(from_user=user_a, to_user=user_b)
        | models_Q(from_user=user_b, to_user=user_a)
    ).exists()


# Local import alias to avoid circular imports at module level
from django.db.models import Q as models_Q  # noqa: E402
"""

Shared Habit Visibility Check Utility
--------------------------------------

Convenience function for inline permission checks within view logic
when the full DRF permission class flow is not applicable.
"""


def can_user_view_habit(user, habit):
    """
    Standalone utility to check if a user can view a habit.

    Useful in service-layer code and view logic where DRF's
    ``check_object_permissions`` is not available.

    Args:
        user: The ``User`` attempting to view the habit.
        habit: The ``Habit`` being accessed.

    Returns:
        bool: ``True`` if the user has view access.
    """
    # Owner always sees their own habits
    if habit.user == user:
        return True

    # Public habits are visible to all authenticated users
    if habit.visibility == 'public':
        return True

    # Explicitly shared with this user
    if SharedHabit.objects.filter(habit=habit, shared_with=user).exists():
        return True

    # Friends-only visibility + confirmed friendship
    if habit.visibility == 'friends_only':
        return _are_friends(habit.user, user)

    return False
