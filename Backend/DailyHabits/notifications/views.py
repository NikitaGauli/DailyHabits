"""
Notifications Views
API endpoints for Inbox, Smart Tips, notification settings, and reminders
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


class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Inbox notification management
    """
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        ).select_related('habit', 'from_user', 'group')

    def list(self, request):
        queryset = self.get_queryset()
        notification_type = request.query_params.get('type')
        is_read = request.query_params.get('is_read')

        if notification_type:
            queryset = queryset.filter(notification_type=notification_type)
        if is_read is not None:
            if is_read == 'true':
                queryset = queryset.filter(status='read')
            else:
                queryset = queryset.exclude(status='read')

        notifications = queryset[:50]

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
        count = self.get_queryset().exclude(status__in=['read', 'dismissed']).count()
        return Response({'success': True, 'unreadCount': count})

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        try:
            notification = self.get_queryset().get(pk=pk)
            notification.mark_as_read()
            return Response({'success': True, 'message': 'Notification marked as read'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        updated = self.get_queryset().exclude(status__in=['read', 'dismissed']).update(status='read', read_at=timezone.now())
        return Response({'success': True, 'message': f'Marked {updated} notifications as read', 'count': updated})

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        try:
            notification = self.get_queryset().get(pk=pk)
            notification.status = 'dismissed'
            notification.save(update_fields=['status'])
            return Response({'success': True, 'message': 'Notification dismissed'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    def destroy(self, request, *args, **kwargs):
        try:
            notification = self.get_queryset().get(pk=kwargs['pk'])
            notification.delete()
            return Response({'success': True, 'message': 'Notification deleted'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def snooze(self, request, pk=None):
        try:
            notification = self.get_queryset().get(pk=pk)
            minutes = int(request.data.get('minutes', 30))
            notification.snooze(minutes)
            return Response({'success': True, 'message': f'Notification snoozed for {minutes} minutes'})
        except Notification.DoesNotExist:
            return Response({'success': False, 'message': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)


class SmartTipViewSet(viewsets.ModelViewSet):
    """Smart Tips - personalized habit guidance"""
    permission_classes = [IsAuthenticated]
    serializer_class = SmartTipSerializer

    def get_queryset(self):
        return SmartTip.objects.filter(user=self.request.user, is_dismissed=False).select_related('habit')

    def list(self, request):
        from .services import SmartTipService
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
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_read = True
            tip.save(update_fields=['is_read'])
            return Response({'success': True})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_liked = not tip.is_liked
            tip.save(update_fields=['is_liked'])
            return Response({'success': True, 'isLiked': tip.is_liked})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'], url_path='save-tip')
    def save_tip(self, request, pk=None):
        try:
            tip = self.get_queryset().get(pk=pk)
            tip.is_saved = not tip.is_saved
            tip.save(update_fields=['is_saved'])
            return Response({'success': True, 'isSaved': tip.is_saved})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        try:
            tip = SmartTip.objects.filter(user=request.user, pk=pk).first()
            if not tip:
                return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)
            tip.is_dismissed = True
            tip.save(update_fields=['is_dismissed'])
            return Response({'success': True, 'message': 'Tip dismissed'})
        except SmartTip.DoesNotExist:
            return Response({'success': False, 'message': 'Tip not found'}, status=status.HTTP_404_NOT_FOUND)


class NotificationSettingsViewSet(viewsets.ViewSet):
    """Notification settings"""
    permission_classes = [IsAuthenticated]

    def list(self, request):
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
            }
        })

    @action(detail=False, methods=['put', 'patch'])
    def update_settings(self, request):
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        data = request.data
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
        }
        for api_field, model_field in field_mapping.items():
            if api_field in data:
                setattr(settings_obj, model_field, data[api_field])
        settings_obj.save()
        return Response({'success': True, 'message': 'Settings updated successfully'})


class HabitReminderViewSet(viewsets.ModelViewSet):
    """Habit reminders"""
    permission_classes = [IsAuthenticated]
    serializer_class = HabitReminderSerializer

    def get_queryset(self):
        return HabitReminder.objects.filter(habit__user=self.request.user)

    def list(self, request):
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
        try:
            reminder = self.get_queryset().get(pk=pk)
            reminder.is_enabled = not reminder.is_enabled
            reminder.save()
            return Response({'success': True, 'isEnabled': reminder.is_enabled})
        except HabitReminder.DoesNotExist:
            return Response({'success': False, 'message': 'Reminder not found'}, status=status.HTTP_404_NOT_FOUND)


class NotificationIntelligenceViewSet(viewsets.ViewSet):
    """AI-powered notification intelligence"""
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='smart-suggestions')
    def smart_suggestions(self, request):
        from .services import NotificationIntelligence
        suggestions = NotificationIntelligence.get_smart_reminder_suggestions(request.user)
        return Response({'success': True, 'suggestions': suggestions})

    @action(detail=False, methods=['get'], url_path='streak-risks')
    def streak_risks(self, request):
        from .services import NotificationIntelligence
        alerts = NotificationIntelligence.get_streak_risk_alerts(request.user)
        return Response({'success': True, 'alerts': alerts})

    @action(detail=False, methods=['get'], url_path='weekly-nudges')
    def weekly_nudges(self, request):
        from .services import NotificationIntelligence
        nudges = NotificationIntelligence.get_weekly_performance_nudges(request.user)
        return Response({'success': True, 'nudges': nudges})

    @action(detail=False, methods=['post'], url_path='should-send')
    def should_send(self, request):
        from .services import NotificationIntelligence
        notification_type = request.data.get('notification_type', 'reminder')
        allowed = NotificationIntelligence.should_send_notification(request.user)
        return Response({'success': True, 'shouldSend': allowed, 'notificationType': notification_type})

    @action(detail=False, methods=['get'], url_path='summary')
    def intelligence_summary(self, request):
        from .services import NotificationIntelligence
        summary = NotificationIntelligence.get_notification_summary(request.user)
        return Response({'success': True, **summary})
