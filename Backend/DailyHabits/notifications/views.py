"""
Notification Views
==================
Django REST Framework ViewSets that expose the notification subsystem
over a RESTful JSON API.

ViewSets
--------
- :class:`NotificationViewSet`            — CRUD + list / mark-read / snooze
  for inbox notifications.
- :class:`SmartTipViewSet`                — List / like / save / dismiss
  personalized smart tips.
- :class:`NotificationSettingsViewSet`    — Retrieve and update per-user
  notification preferences.
- :class:`HabitReminderViewSet`           — CRUD + toggle for per-habit
  recurring reminders.
- :class:`NotificationIntelligenceViewSet`— Read-only analytics endpoints
  (smart suggestions, streak risks, weekly nudges, delivery gate).

All endpoints require authentication via ``IsAuthenticated`` and scope
querysets to the requesting user to enforce data isolation.
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone

from .models import Notification, SmartTip, NotificationSettings, HabitReminder
from .serializers import (
    NotificationSerializer,
    SmartTipSerializer,
    NotificationSettingsSerializer,
    HabitReminderSerializer,
)


# =============================================================================
#  NOTIFICATION VIEWSET — inbox notification management
# =============================================================================

class NotificationViewSet(viewsets.ModelViewSet):
    """
    Full CRUD ViewSet for user inbox notifications.

    Standard DRF endpoints:
        - ``GET    /notifications/``             — List (with optional filters).
        - ``GET    /notifications/{id}/``        — Retrieve single notification.
        - ``DELETE /notifications/{id}/``        — Delete a notification.

    Custom actions:
        - ``GET    /notifications/unread/``      — Unread count.
        - ``POST   /notifications/{id}/mark-read/`` — Mark one as read.
        - ``POST   /notifications/mark-all-read/``  — Bulk mark-as-read.
        - ``POST   /notifications/{id}/dismiss/``   — Dismiss.
        - ``POST   /notifications/{id}/snooze/``    — Snooze for *N* minutes.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        """Return notifications for the authenticated user with related objects."""
        return Notification.objects.filter(
            user=self.request.user
        ).select_related('habit', 'from_user', 'group')

    def list(self, request):
        """List notifications with optional ``type`` and ``is_read`` query-param filters."""
        queryset = self.get_queryset()

        # Optional filters from query params
        notification_type = request.query_params.get('type')
        is_read = request.query_params.get('is_read')

        if notification_type:
            queryset = queryset.filter(notification_type=notification_type)
        if is_read is not None:
            if is_read == 'true':
                queryset = queryset.filter(status='read')
            else:
                queryset = queryset.exclude(status='read')

        # Cap at 50 most recent notifications
        notifications = queryset[:50]

        # Build the response payload with denormalized related fields
        return Response({
            'success': True,
            'notifications': [{
                'id': n.id,
                'type': n.notification_type,
                'title': n.title,
                'message': n.message,
                'status': n.status,
                'scheduledTime': n.scheduled_time.isoformat() if n.scheduled_time else None,
                'sentAt': n.sent_at.isoformat() if n.sent_at else None,
                'readAt': n.read_at.isoformat() if n.read_at else None,
                'iconCode': n.icon_code,
                'colorValue': n.color_value,
                'actionType': n.action_type,
                'actionData': n.action_data,
                'habitId': n.habit_id,
                'habitTitle': n.habit.title if n.habit else None,
                'fromUserId': n.from_user_id,
                'fromUserName': n.from_user.name if n.from_user else None,
                'fromUserImage': n.from_user.profile_image if n.from_user else None,
                'groupId': n.group_id,
                'groupName': n.group.name if n.group else None,
                'createdAt': n.created_at.isoformat(),
            } for n in notifications],
            'unreadCount': self.get_queryset().exclude(status='read').exclude(status='dismissed').count(),
        })

    @action(detail=False, methods=['get'])
    def unread(self, request):
        """Return the total count of unread (non-read, non-dismissed) notifications."""
        count = self.get_queryset().exclude(status__in=['read', 'dismissed']).count()
        return Response({'success': True, 'unreadCount': count})

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Mark a single notification as read by its primary key."""
        try:
            notification = self.get_queryset().get(pk=pk)
            notification.mark_as_read()
            return Response({'success': True, 'message': 'Notification marked as read'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        """Bulk-mark all unread/unsent notifications as read."""
        updated = self.get_queryset().exclude(status__in=['read', 'dismissed']).update(status='read', read_at=timezone.now())
        return Response({'success': True, 'message': f'Marked {updated} notifications as read', 'count': updated})

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        """Dismiss a notification (removes it from the active inbox)."""
        try:
            notification = self.get_queryset().get(pk=pk)
            notification.status = 'dismissed'
            notification.save(update_fields=['status'])
            return Response({'success': True, 'message': 'Notification dismissed'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    def destroy(self, request, *args, **kwargs):
        """Permanently delete a notification."""
        try:
            notification = self.get_queryset().get(pk=kwargs['pk'])
            notification.delete()
            return Response({'success': True, 'message': 'Notification deleted'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def snooze(self, request, pk=None):
        """Snooze a notification for *N* minutes (default 30)."""
        try:
            notification = self.get_queryset().get(pk=pk)
            minutes = int(request.data.get('minutes', 30))
            notification.snooze(minutes)
            return Response({'success': True, 'message': f'Notification snoozed for {minutes} minutes'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    # ── Friend request actions (from notification) ────────────────────

    @action(detail=True, methods=['post'], url_path='accept-friend')
    def accept_friend(self, request, pk=None):
        """Accept a friend request directly from a notification.

        Finds the pending Friendship from the notification's ``from_user``
        to the authenticated user, accepts it, marks the notification read,
        and creates a ``friend_accepted`` notification for the sender.
        """
        from social.models import Friendship
        from notifications.services import NotificationCreator

        try:
            notification = self.get_queryset().get(pk=pk, notification_type='friend_request')
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

        if not notification.from_user:
            return Response({'success': False, 'message': 'Invalid friend request notification'}, status=status.HTTP_400_BAD_REQUEST)

        # Find the pending friendship
        friendship = Friendship.objects.filter(
            from_user=notification.from_user,
            to_user=request.user,
            status='pending',
        ).first()

        if not friendship:
            return Response({'success': False, 'message': 'Friend request not found or already handled'}, status=status.HTTP_404_NOT_FOUND)

        # Accept the friendship
        friendship.status = 'accepted'
        friendship.save()

        # Mark this notification as read
        notification.mark_as_read()

        # Notify the sender that their request was accepted
        NotificationCreator.friend_accepted(to_user=notification.from_user, from_user=request.user)

        return Response({'success': True, 'message': 'Friend request accepted'})

    @action(detail=True, methods=['post'], url_path='reject-friend')
    def reject_friend(self, request, pk=None):
        """Reject a friend request directly from a notification.

        Finds the pending Friendship, rejects it, and marks the
        notification as dismissed.
        """
        from social.models import Friendship

        try:
            notification = self.get_queryset().get(pk=pk, notification_type='friend_request')
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

        if not notification.from_user:
            return Response({'success': False, 'message': 'Invalid friend request notification'}, status=status.HTTP_400_BAD_REQUEST)

        # Find the pending friendship
        friendship = Friendship.objects.filter(
            from_user=notification.from_user,
            to_user=request.user,
            status='pending',
        ).first()

        if not friendship:
            return Response({'success': False, 'message': 'Friend request not found or already handled'}, status=status.HTTP_404_NOT_FOUND)

        # Reject the friendship
        friendship.status = 'rejected'
        friendship.save()

        # Dismiss this notification
        notification.status = 'dismissed'
        notification.save(update_fields=['status'])

        return Response({'success': True, 'message': 'Friend request rejected'})


# =============================================================================
#  SMART TIP VIEWSET — personalized guidance cards
# =============================================================================

class SmartTipViewSet(viewsets.ModelViewSet):
    """
    ViewSet for personalized smart tips (non-urgent habit guidance).

    Standard endpoints:
        - ``GET    /smart-tips/``                — List active tips (auto-generates if needed).
        - ``GET    /smart-tips/{id}/``           — Retrieve a single tip.

    Custom actions:
        - ``POST   /smart-tips/{id}/mark-read/`` — Mark as read.
        - ``POST   /smart-tips/{id}/like/``      — Toggle like.
        - ``POST   /smart-tips/{id}/save-tip/``  — Toggle bookmark.
        - ``POST   /smart-tips/{id}/dismiss/``   — Dismiss from feed.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = SmartTipSerializer

    def get_queryset(self):
        """Return non-dismissed tips for the authenticated user."""
        return SmartTip.objects.filter(user=self.request.user, is_dismissed=False).select_related('habit')

    def list(self, request):
        """
        List active smart tips.

        Triggers lazy tip generation via :meth:`SmartTipService.generate_tips_if_needed`
        before querying, ensuring the feed is always fresh.
        """
        from .services import SmartTipService
        # Ensure the user has fresh tips before returning the list
        SmartTipService.generate_tips_if_needed(request.user)
        queryset = self.get_queryset()
        tips = queryset[:30]
        return Response({
            'success': True,
            'tips': [{
                'id': t.id,
                'tipType': t.tip_type,
                'title': t.title,
                'message': t.message,
                'iconCode': t.icon_code,
                'colorValue': t.color_value,
                'isRead': t.is_read,
                'isLiked': t.is_liked,
                'isSaved': t.is_saved,
                'habitId': t.habit_id,
                'habitTitle': t.habit.title if t.habit else None,
                'metadata': t.metadata,
                'createdAt': t.created_at.isoformat(),
            } for t in tips],
            'totalCount': queryset.count(),
        })

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Mark a single smart tip as read."""
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_read = True
            tip.save(update_fields=['is_read'])
            return Response({'success': True})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        """Toggle the *liked* flag on a smart tip."""
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_liked = not tip.is_liked
            tip.save(update_fields=['is_liked'])
            return Response({'success': True, 'isLiked': tip.is_liked})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'], url_path='save-tip')
    def save_tip(self, request, pk=None):
        """Toggle the *saved* (bookmarked) flag on a smart tip."""
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_saved = not tip.is_saved
            tip.save(update_fields=['is_saved'])
            return Response({'success': True, 'isSaved': tip.is_saved})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        """Dismiss a tip so it no longer appears in the user's feed."""
        try:
            tip = SmartTip.objects.filter(user=request.user, pk=pk).first()
            if not tip:
                return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)
            tip.is_dismissed = True
            tip.save(update_fields=['is_dismissed'])
            return Response({'success': True, 'message': 'Tip dismissed'})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)


# =============================================================================
#  NOTIFICATION SETTINGS VIEWSET — per-user delivery preferences
# =============================================================================

class NotificationSettingsViewSet(viewsets.ViewSet):
    """
    ViewSet for reading and updating notification delivery preferences.

    Uses ``get_or_create`` to lazily initialise settings on first access,
    so every user always has a complete settings object.

    Endpoints:
        - ``GET  /notification-settings/``               — Retrieve current settings.
        - ``PUT  /notification-settings/update_settings/`` — Full update.
        - ``PATCH /notification-settings/update_settings/`` — Partial update.
    """
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """Return the current notification settings for the authenticated user."""
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'notificationsEnabled': settings_obj.notifications_enabled,
                'soundEnabled': settings_obj.sound_enabled,
                'vibrationEnabled': settings_obj.vibration_enabled,
                'habitReminders': settings_obj.habit_reminders,
                'missedHabitAlerts': settings_obj.missed_habit_alerts,
                'achievementNotifications': settings_obj.achievement_notifications,
                'streakAlerts': settings_obj.streak_alerts,
                'insightNotifications': settings_obj.insight_notifications,
                'motivationalQuotes': settings_obj.motivational_quotes,
                'smartTipsEnabled': settings_obj.smart_tips_enabled,
                'socialNotifications': settings_obj.social_notifications,
                'quietHoursEnabled': settings_obj.quiet_hours_enabled,
                'quietHoursStart': settings_obj.quiet_hours_start.isoformat() if settings_obj.quiet_hours_start else None,
                'quietHoursEnd': settings_obj.quiet_hours_end.isoformat() if settings_obj.quiet_hours_end else None,
                'reminderMinutesBefore': settings_obj.reminder_minutes_before,
                'maxNotificationsPerDay': settings_obj.max_notifications_per_day,
                'defaultSnoozeMinutes': settings_obj.default_snooze_minutes,
                'timezone': settings_obj.timezone,
                'weekendRemindersEnabled': settings_obj.weekend_reminders_enabled,
                'reminderWindowStart': settings_obj.reminder_window_start.isoformat() if settings_obj.reminder_window_start else None,
                'reminderWindowEnd': settings_obj.reminder_window_end.isoformat() if settings_obj.reminder_window_end else None,
                'deliveryMode': settings_obj.delivery_mode,
                'digestTime': settings_obj.digest_time.isoformat() if settings_obj.digest_time else None,
                'cooldownMinutes': settings_obj.cooldown_minutes,
            }
        })

    @action(detail=False, methods=['put', 'patch'])
    def update_settings(self, request):
        """
        Update notification settings from a flat camelCase JSON payload.

        The ``field_mapping`` dict translates front-end camelCase keys to
        Django snake_case model fields.  Only keys present in the request
        body are applied, making this safe for partial updates.
        """
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        data = request.data

        # Map front-end camelCase field names → Django model snake_case fields
        field_mapping = {
            'notificationsEnabled': 'notifications_enabled',
            'soundEnabled': 'sound_enabled',
            'vibrationEnabled': 'vibration_enabled',
            'habitReminders': 'habit_reminders',
            'missedHabitAlerts': 'missed_habit_alerts',
            'achievementNotifications': 'achievement_notifications',
            'streakAlerts': 'streak_alerts',
            'insightNotifications': 'insight_notifications',
            'motivationalQuotes': 'motivational_quotes',
            'smartTipsEnabled': 'smart_tips_enabled',
            'socialNotifications': 'social_notifications',
            'quietHoursEnabled': 'quiet_hours_enabled',
            'reminderMinutesBefore': 'reminder_minutes_before',
            'maxNotificationsPerDay': 'max_notifications_per_day',
            'defaultSnoozeMinutes': 'default_snooze_minutes',
            'timezone': 'timezone',
            'weekendRemindersEnabled': 'weekend_reminders_enabled',
            'reminderWindowStart': 'reminder_window_start',
            'reminderWindowEnd': 'reminder_window_end',
            'deliveryMode': 'delivery_mode',
            'digestTime': 'digest_time',
            'cooldownMinutes': 'cooldown_minutes',
        }
        # Apply only the fields present in the request payload
        for api_field, model_field in field_mapping.items():
            if api_field in data:
                setattr(settings_obj, model_field, data[api_field])
        settings_obj.save()
        return Response({'success': True, 'message': 'Settings updated successfully'})


# =============================================================================
#  HABIT REMINDER VIEWSET — per-habit recurring reminders
# =============================================================================

class HabitReminderViewSet(viewsets.ModelViewSet):
    """
    CRUD ViewSet for user-configured habit reminders.

    Standard endpoints:
        - ``GET    /habit-reminders/``            — List all reminders.
        - ``POST   /habit-reminders/``            — Create a new reminder.
        - ``PUT    /habit-reminders/{id}/``       — Full update.
        - ``PATCH  /habit-reminders/{id}/``       — Partial update.
        - ``DELETE /habit-reminders/{id}/``       — Delete.

    Custom actions:
        - ``POST   /habit-reminders/{id}/toggle/`` — Toggle enabled/disabled.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = HabitReminderSerializer

    def get_queryset(self):
        """Return reminders for habits owned by the authenticated user."""
        return HabitReminder.objects.filter(habit__user=self.request.user)

    def list(self, request):
        """List all reminders with their associated habit titles."""
        reminders = self.get_queryset().select_related('habit')
        return Response({
            'success': True,
            'reminders': [{
                'id': r.id,
                'habitId': r.habit_id,
                'habitTitle': r.habit.title,
                'reminderTime': r.reminder_time.isoformat(),
                'repeatType': r.repeat_type,
                'customDays': r.custom_days,
                'isEnabled': r.is_enabled,
                'message': r.message,
                'lastSent': r.last_sent.isoformat() if r.last_sent else None,
            } for r in reminders]
        })

    @action(detail=True, methods=['post'])
    def toggle(self, request, pk=None):
        """Toggle a reminder's ``is_enabled`` flag on/off."""
        try:
            reminder = self.get_queryset().get(pk=pk)
            reminder.is_enabled = not reminder.is_enabled
            reminder.save()
            return Response({'success': True, 'isEnabled': reminder.is_enabled})
        except HabitReminder.DoesNotExist:
            return Response({'success': False, 'message': 'Reminder not found'}, status=status.HTTP_404_NOT_FOUND)


# =============================================================================
#  NOTIFICATION INTELLIGENCE VIEWSET — AI-powered analytics
# =============================================================================

class NotificationIntelligenceViewSet(viewsets.ViewSet):
    """
    Read-only ViewSet exposing the smart-analytics engine.

    All methods delegate to :class:`~notifications.services.NotificationIntelligence`.

    Endpoints:
        - ``GET  /notification-intelligence/smart-suggestions/`` — Optimal reminder-time suggestions.
        - ``GET  /notification-intelligence/streak-risks/``      — At-risk streak alerts.
        - ``GET  /notification-intelligence/weekly-nudges/``     — Week-over-week performance nudges.
        - ``POST /notification-intelligence/should-send/``       — Delivery-gate check.
        - ``GET  /notification-intelligence/summary/``           — Aggregated intelligence payload.
    """
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='smart-suggestions')
    def smart_suggestions(self, request):
        """Return optimal reminder-time suggestions for habits lacking reminders."""
        from .services import NotificationIntelligence
        suggestions = NotificationIntelligence.get_smart_reminder_suggestions(request.user)
        return Response({'success': True, 'suggestions': suggestions})

    @action(detail=False, methods=['get'], url_path='streak-risks')
    def streak_risks(self, request):
        """Return habits with active streaks at risk of breaking today."""
        from .services import NotificationIntelligence
        alerts = NotificationIntelligence.get_streak_risk_alerts(request.user)
        return Response({'success': True, 'alerts': alerts})

    @action(detail=False, methods=['get'], url_path='weekly-nudges')
    def weekly_nudges(self, request):
        """Return week-over-week performance comparison nudges."""
        from .services import NotificationIntelligence
        nudges = NotificationIntelligence.get_weekly_performance_nudges(request.user)
        return Response({'success': True, 'nudges': nudges})

    @action(detail=False, methods=['post'], url_path='should-send')
    def should_send(self, request):
        """Check whether the delivery gate allows sending a new notification."""
        from .services import NotificationIntelligence
        notification_type = request.data.get('notification_type', 'reminder')
        allowed = NotificationIntelligence.should_send_notification(request.user)
        return Response({'success': True, 'shouldSend': allowed, 'notificationType': notification_type})

    @action(detail=False, methods=['get'], url_path='summary')
    def intelligence_summary(self, request):
        """Return a combined payload from all intelligence endpoints."""
        from .services import NotificationIntelligence
        summary = NotificationIntelligence.get_notification_summary(request.user)
        return Response({'success': True, **summary})

