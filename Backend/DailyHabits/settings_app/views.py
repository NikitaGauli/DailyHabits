"""
Settings App - Views
====================
ViewSets for all settings module endpoints.  NO Firebase Cloud Messaging.
"""

import csv
import io
import json
from datetime import datetime

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.renderers import BaseRenderer, JSONRenderer
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny


# =========================================================================
#  CUSTOM RENDERERS  (allow DRF content negotiation for binary downloads)
# =========================================================================

class PdfRenderer(BaseRenderer):
    """Pass-through renderer that satisfies DRF content negotiation for PDF."""
    media_type = 'application/pdf'
    format = 'pdf'
    charset = None
    render_style = 'binary'

    def render(self, data, accepted_media_type=None, renderer_context=None):
        return data


class CsvRenderer(BaseRenderer):
    """Pass-through renderer that satisfies DRF content negotiation for CSV."""
    media_type = 'text/csv'
    format = 'csv'
    charset = 'utf-8'

    def render(self, data, accepted_media_type=None, renderer_context=None):
        return data

from .models import (
    UserSettings, PrivacySettings, SecuritySettings,
    LoginSession, SettingsAuditLog, ExportRequest,
    PrivacyPolicy, FAQ, SupportTicket,
)
from .serializers import (
    UserSettingsSerializer, PrivacySettingsSerializer,
    SecuritySettingsSerializer, LoginSessionSerializer,
    SettingsAuditLogSerializer, ExportRequestSerializer,
    PrivacyPolicySerializer, FAQSerializer, SupportTicketSerializer,
)


# =========================================================================
#  USER SETTINGS
# =========================================================================

class UserSettingsViewSet(viewsets.ViewSet):
    """Retrieve and update user application preferences."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        obj, _ = UserSettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'theme': obj.theme,
                'accentColor': obj.accent_color,
                'animationsEnabled': obj.animations_enabled,
                'fontSize': obj.font_size,
                'dailySummaryEnabled': obj.daily_summary_enabled,
                'dailySummaryTime': obj.daily_summary_time.strftime('%H:%M') if obj.daily_summary_time else '20:00',
                'quotesEnabled': obj.quotes_enabled,
                'quoteFrequency': obj.quote_frequency,
                'quoteTone': obj.quote_tone,
                'quietHoursEnabled': obj.quiet_hours_enabled,
                'quietHoursStart': obj.quiet_hours_start.strftime('%H:%M') if obj.quiet_hours_start else None,
                'quietHoursEnd': obj.quiet_hours_end.strftime('%H:%M') if obj.quiet_hours_end else None,
                'quietHoursAllowEmergency': obj.quiet_hours_allow_emergency,
                'quietHoursSeparateWeekend': obj.quiet_hours_separate_weekend,
                'quietHoursWeekdayStart': obj.quiet_hours_weekday_start.strftime('%H:%M') if obj.quiet_hours_weekday_start else None,
                'quietHoursWeekdayEnd': obj.quiet_hours_weekday_end.strftime('%H:%M') if obj.quiet_hours_weekday_end else None,
                'quietHoursWeekendStart': obj.quiet_hours_weekend_start.strftime('%H:%M') if obj.quiet_hours_weekend_start else None,
                'quietHoursWeekendEnd': obj.quiet_hours_weekend_end.strftime('%H:%M') if obj.quiet_hours_weekend_end else None,
                'timezone': obj.timezone,
                'language': obj.language,
                'weekStartDay': obj.week_start_day,
                'analyticsConsent': obj.analytics_consent,
                'aiPersonalization': obj.ai_personalization,
                'compactMode': obj.compact_mode,
                'hapticFeedback': obj.haptic_feedback,
                'autoArchiveDays': obj.auto_archive_days,
                'defaultHabitVisibility': obj.default_habit_visibility,
            },
        })

    # -----------------------------------------------------------------
    #  Dedicated Color Preference Endpoint
    # -----------------------------------------------------------------

    # Whitelist of allowed accent colors — must stay in sync with the
    # Flutter `_accentColors` map in appearance_page.dart.
    ALLOWED_COLORS = frozenset([
        'indigo', 'blue', 'teal', 'green', 'amber',
        'orange', 'rose', 'purple', 'pink', 'cyan',
    ])

    @action(detail=False, methods=['post'], url_path='color')
    def update_color(self, request):
        """
        POST /api/user-settings/color/

        Accept a single ``color`` value, validate it against the allowed
        palette, persist it for the authenticated user, and return a
        standardised success response.

        Request body::

            { "color": "green" }

        Success response (200)::

            {
                "status": "success",
                "message": "Color preference updated",
                "preferred_color": "green"
            }

        Validation error (400)::

            {
                "status": "error",
                "message": "Invalid color. Allowed: indigo, blue, …",
                "allowed_colors": ["indigo", "blue", …]
            }
        """
        color = request.data.get('color', '').strip().lower()

        if not color:
            return Response(
                {
                    'status': 'error',
                    'message': 'The "color" field is required.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if color not in self.ALLOWED_COLORS:
            return Response(
                {
                    'status': 'error',
                    'message': (
                        f'Invalid color "{color}". '
                        f'Allowed: {", ".join(sorted(self.ALLOWED_COLORS))}'
                    ),
                    'allowed_colors': sorted(self.ALLOWED_COLORS),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        obj, _ = UserSettings.objects.get_or_create(user=request.user)
        old_color = obj.accent_color
        obj.accent_color = color
        obj.save(update_fields=['accent_color', 'updated_at'])

        # Audit trail
        if old_color != color:
            SettingsAuditLog.log(
                user=request.user,
                category='appearance',
                action='update_color_preference',
                description=f'Accent color changed from {old_color} to {color}',
                old_value={'accentColor': old_color},
                new_value={'accentColor': color},
                request=request,
            )

        return Response({
            'status': 'success',
            'message': 'Color preference updated',
            'preferred_color': color,
        })

    @action(detail=False, methods=['put', 'patch'])
    def update_settings(self, request):
        obj, _ = UserSettings.objects.get_or_create(user=request.user)
        data = request.data
        field_map = {
            'theme': 'theme',
            'accentColor': 'accent_color',
            'animationsEnabled': 'animations_enabled',
            'fontSize': 'font_size',
            'dailySummaryEnabled': 'daily_summary_enabled',
            'dailySummaryTime': 'daily_summary_time',
            'quotesEnabled': 'quotes_enabled',
            'quoteFrequency': 'quote_frequency',
            'quoteTone': 'quote_tone',
            'quietHoursEnabled': 'quiet_hours_enabled',
            'quietHoursStart': 'quiet_hours_start',
            'quietHoursEnd': 'quiet_hours_end',
            'quietHoursAllowEmergency': 'quiet_hours_allow_emergency',
            'quietHoursSeparateWeekend': 'quiet_hours_separate_weekend',
            'quietHoursWeekdayStart': 'quiet_hours_weekday_start',
            'quietHoursWeekdayEnd': 'quiet_hours_weekday_end',
            'quietHoursWeekendStart': 'quiet_hours_weekend_start',
            'quietHoursWeekendEnd': 'quiet_hours_weekend_end',
            'timezone': 'timezone',
            'language': 'language',
            'weekStartDay': 'week_start_day',
            'analyticsConsent': 'analytics_consent',
            'aiPersonalization': 'ai_personalization',
            'compactMode': 'compact_mode',
            'hapticFeedback': 'haptic_feedback',
            'autoArchiveDays': 'auto_archive_days',
            'defaultHabitVisibility': 'default_habit_visibility',
        }
        old_values = {}
        new_values = {}
        for api_key, model_field in field_map.items():
            if api_key in data:
                old_values[api_key] = str(getattr(obj, model_field))
                setattr(obj, model_field, data[api_key])
                new_values[api_key] = str(data[api_key])
        obj.save()
        if old_values:
            SettingsAuditLog.log(
                user=request.user, category='appearance',
                action='update_settings',
                description=f"Updated: {', '.join(new_values.keys())}",
                old_value=old_values, new_value=new_values,
                request=request,
            )
        return Response({'success': True, 'message': 'Settings updated'})


# =========================================================================
#  PRIVACY SETTINGS
# =========================================================================

class PrivacySettingsViewSet(viewsets.ViewSet):
    """Retrieve and update privacy and data-sharing controls."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        obj, _ = PrivacySettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'accountVisibility': obj.account_visibility,
                'showProfileInSearch': obj.show_profile_in_search,
                'showInLeaderboard': obj.show_in_leaderboard,
                'whoCanViewHabits': obj.who_can_view_habits,
                'whoCanViewStreaks': obj.who_can_view_streaks,
                'shareProgressWithGroups': obj.share_progress_with_groups,
                'whoCanSendFriendRequests': obj.who_can_send_friend_requests,
                'allowGroupInvites': obj.allow_group_invites,
                'showOnlineStatus': obj.show_online_status,
                'shareAnonymousUsageData': obj.share_anonymous_usage_data,
                'allowAiTraining': obj.allow_ai_training,
            },
        })

    @action(detail=False, methods=['put', 'patch'])
    def update_settings(self, request):
        obj, _ = PrivacySettings.objects.get_or_create(user=request.user)
        data = request.data
        field_map = {
            'accountVisibility': 'account_visibility',
            'showProfileInSearch': 'show_profile_in_search',
            'showInLeaderboard': 'show_in_leaderboard',
            'whoCanViewHabits': 'who_can_view_habits',
            'whoCanViewStreaks': 'who_can_view_streaks',
            'shareProgressWithGroups': 'share_progress_with_groups',
            'whoCanSendFriendRequests': 'who_can_send_friend_requests',
            'allowGroupInvites': 'allow_group_invites',
            'showOnlineStatus': 'show_online_status',
            'shareAnonymousUsageData': 'share_anonymous_usage_data',
            'allowAiTraining': 'allow_ai_training',
        }
        old_values = {}
        new_values = {}
        for api_key, model_field in field_map.items():
            if api_key in data:
                old_values[api_key] = str(getattr(obj, model_field))
                setattr(obj, model_field, data[api_key])
                new_values[api_key] = str(data[api_key])
        obj.save()
        if old_values:
            SettingsAuditLog.log(
                user=request.user, category='privacy',
                action='update_privacy_settings',
                description=f"Updated: {', '.join(new_values.keys())}",
                old_value=old_values, new_value=new_values,
                request=request,
            )
        return Response({'success': True, 'message': 'Privacy settings updated'})


# =========================================================================
#  SECURITY SETTINGS
# =========================================================================

class SecuritySettingsViewSet(viewsets.ViewSet):
    """Retrieve and update security preferences."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        obj, _ = SecuritySettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'twoFactorEnabled': obj.two_factor_enabled,
                'twoFactorMethod': obj.two_factor_method,
                'biometricLockEnabled': obj.biometric_lock_enabled,
                'requireAuthForExport': obj.require_auth_for_export,
                'requireAuthForDelete': obj.require_auth_for_delete,
                'sessionTimeoutMinutes': obj.session_timeout_minutes,
                'loginNotificationEnabled': obj.login_notification_enabled,
            },
        })

    @action(detail=False, methods=['put', 'patch'])
    def update_settings(self, request):
        obj, _ = SecuritySettings.objects.get_or_create(user=request.user)
        data = request.data
        field_map = {
            'twoFactorEnabled': 'two_factor_enabled',
            'twoFactorMethod': 'two_factor_method',
            'biometricLockEnabled': 'biometric_lock_enabled',
            'requireAuthForExport': 'require_auth_for_export',
            'requireAuthForDelete': 'require_auth_for_delete',
            'sessionTimeoutMinutes': 'session_timeout_minutes',
            'loginNotificationEnabled': 'login_notification_enabled',
        }
        old_values = {}
        new_values = {}
        for api_key, model_field in field_map.items():
            if api_key in data:
                old_values[api_key] = str(getattr(obj, model_field))
                setattr(obj, model_field, data[api_key])
                new_values[api_key] = str(data[api_key])
        obj.save()
        if old_values:
            SettingsAuditLog.log(
                user=request.user, category='security',
                action='update_security_settings',
                description=f"Updated: {', '.join(new_values.keys())}",
                old_value=old_values, new_value=new_values,
                request=request,
            )
        return Response({'success': True, 'message': 'Security settings updated'})

    @action(detail=False, methods=['post'], url_path='change-password')
    def change_password(self, request):
        current_password = request.data.get('currentPassword', '')
        new_password = request.data.get('newPassword', '')
        if not current_password or not new_password:
            return Response(
                {'success': False, 'message': 'Current and new password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.check_password(current_password):
            return Response(
                {'success': False, 'message': 'Current password is incorrect'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new_password) < 8:
            return Response(
                {'success': False, 'message': 'Password must be at least 8 characters'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(new_password)
        request.user.save()
        SettingsAuditLog.log(
            user=request.user, category='security',
            action='change_password',
            description='Password changed successfully',
            request=request,
        )
        return Response({'success': True, 'message': 'Password changed successfully'})


# =========================================================================
#  LOGIN SESSIONS
# =========================================================================

class LoginSessionViewSet(viewsets.ViewSet):
    """Manage active login sessions / devices."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        sessions = LoginSession.objects.filter(user=request.user, is_active=True)
        return Response({
            'success': True,
            'sessions': [{
                'id': s.id,
                'deviceName': s.device_name,
                'deviceType': s.device_type,
                'platform': s.platform,
                'ipAddress': s.ip_address,
                'location': s.location,
                'isCurrent': s.is_current,
                'lastActiveAt': s.last_active_at.isoformat(),
                'loggedInAt': s.logged_in_at.isoformat(),
            } for s in sessions],
        })

    @action(detail=True, methods=['post'])
    def revoke(self, request, pk=None):
        try:
            session = LoginSession.objects.get(pk=pk, user=request.user, is_active=True)
            session.revoke()
            SettingsAuditLog.log(
                user=request.user, category='security',
                action='revoke_session',
                description=f'Revoked session: {session.device_name} ({session.platform})',
                request=request,
            )
            return Response({'success': True, 'message': 'Session revoked'})
        except LoginSession.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Session not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=False, methods=['post'], url_path='revoke-all')
    def revoke_all(self, request):
        count = LoginSession.objects.filter(
            user=request.user, is_active=True, is_current=False,
        ).update(is_active=False, logged_out_at=timezone.now())
        SettingsAuditLog.log(
            user=request.user, category='security',
            action='revoke_all_sessions',
            description=f'Revoked {count} sessions',
            request=request,
        )
        return Response({'success': True, 'message': f'Revoked {count} sessions', 'count': count})


# =========================================================================
#  SETTINGS AUDIT LOG
# =========================================================================

class SettingsAuditLogViewSet(viewsets.ViewSet):
    """Read-only audit trail for settings changes."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        category = request.query_params.get('category')
        qs = SettingsAuditLog.objects.filter(user=request.user)
        if category:
            qs = qs.filter(category=category)
        logs = qs[:50]
        return Response({
            'success': True,
            'logs': [{
                'id': log.id,
                'category': log.category,
                'action': log.action,
                'description': log.description,
                'oldValue': log.old_value,
                'newValue': log.new_value,
                'ipAddress': log.ip_address,
                'createdAt': log.created_at.isoformat(),
            } for log in logs],
        })


# =========================================================================
#  DATA EXPORT
# =========================================================================

class ExportViewSet(viewsets.ViewSet):
    """
    User data-export lifecycle management.

    Endpoints:
        GET  /api/exports/                — List past export requests.
        POST /api/exports/request/        — Queue a new CSV / JSON / PDF export.
        GET  /api/exports/download/?id=N  — Download a completed export.
        GET  /api/exports/habit-report/   — Generate & stream a PDF analytics
                                            report on-the-fly (no queue).
    """
    permission_classes = [IsAuthenticated]
    # Include PDF & CSV renderers so DRF's content negotiation does NOT
    # reject requests with Accept: application/pdf (HTTP 406).
    renderer_classes = [JSONRenderer, PdfRenderer, CsvRenderer]

    def list(self, request):
        exports = ExportRequest.objects.filter(user=request.user)[:20]
        return Response({
            'success': True,
            'exports': [{
                'id': e.id,
                'format': e.export_format,
                'dateFrom': e.date_from.isoformat(),
                'dateTo': e.date_to.isoformat(),
                'status': e.status,
                'createdAt': e.created_at.isoformat(),
                'completedAt': e.completed_at.isoformat() if e.completed_at else None,
            } for e in exports],
        })

    @action(detail=False, methods=['post'], url_path='request')
    def request_export(self, request):
        fmt = request.data.get('format', 'json')
        date_from = request.data.get('dateFrom')
        date_to = request.data.get('dateTo')
        if not date_from or not date_to:
            return Response(
                {'success': False, 'message': 'dateFrom and dateTo are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if fmt not in ('pdf', 'csv', 'json'):
            return Response(
                {'success': False, 'message': 'Format must be pdf, csv, or json'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        export_req = ExportRequest.objects.create(
            user=request.user, export_format=fmt,
            date_from=date_from, date_to=date_to,
        )
        try:
            self._generate_export(export_req)
        except Exception as e:
            export_req.status = 'failed'
            export_req.error_message = str(e)
            export_req.save()
        SettingsAuditLog.log(
            user=request.user, category='export',
            action='request_export',
            description=f'{fmt.upper()} export from {date_from} to {date_to}',
            request=request,
        )
        return Response({
            'success': True, 'message': 'Export created',
            'exportId': export_req.id, 'status': export_req.status,
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'])
    def download(self, request):
        """
        Download a previously completed export.

        For PDF exports the report is generated server-side via ReportLab
        and streamed as ``application/pdf``.
        """
        export_id = request.query_params.get('id')
        if not export_id:
            return Response({'success': False, 'message': 'id required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            export_req = ExportRequest.objects.get(id=export_id, user=request.user)
        except ExportRequest.DoesNotExist:
            return Response({'success': False, 'message': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if export_req.status != 'completed':
            return Response({'success': False, 'message': 'Export not ready'}, status=status.HTTP_400_BAD_REQUEST)
        from habits.models import Habit, HabitLog
        habits = Habit.objects.filter(user=request.user, is_deleted=False, created_at__date__lte=export_req.date_to)
        logs = HabitLog.objects.filter(
            habit__user=request.user, date__range=[export_req.date_from, export_req.date_to],
        ).select_related('habit').order_by('date')

        # ── JSON download ─────────────────────────────────────────────
        if export_req.export_format == 'json':
            data = self._build_export_data(request.user, habits, logs, export_req)
            response = HttpResponse(json.dumps(data, indent=2, default=str), content_type='application/json')
            response['Content-Disposition'] = f'attachment; filename="dailyhabits_export_{export_req.date_from}_{export_req.date_to}.json"'
            return response

        # ── CSV download ──────────────────────────────────────────────
        if export_req.export_format == 'csv':
            buffer = io.StringIO()
            writer = csv.writer(buffer)
            writer.writerow(['Date', 'Habit', 'Category', 'Status', 'Streak', 'Notes'])
            for log in logs:
                writer.writerow([log.date.isoformat(), log.habit.title, log.habit.category_name, log.status, log.habit.current_streak, log.notes or ''])
            response = HttpResponse(buffer.getvalue(), content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="dailyhabits_export_{export_req.date_from}_{export_req.date_to}.csv"'
            return response

        # ── PDF download (ReportLab) ──────────────────────────────────
        from .pdf_report_service import generate_habit_report_pdf
        try:
            pdf_bytes = generate_habit_report_pdf(request.user)
            response = HttpResponse(pdf_bytes, content_type='application/pdf')
            response['Content-Disposition'] = (
                f'attachment; filename="dailyhabits_report_'
                f'{export_req.date_from}_{export_req.date_to}.pdf"'
            )
            return response
        except Exception as exc:
            return Response(
                {'success': False, 'message': f'PDF generation failed: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    # -----------------------------------------------------------------
    #  Dedicated Habit Report PDF Endpoint (instant, no queue)
    # -----------------------------------------------------------------

    @action(detail=False, methods=['get'], url_path='habit-report')
    def habit_report(self, request):
        """
        GET /api/exports/habit-report/

        Generates a professional Habit Analytics Report PDF on-the-fly
        using ReportLab and streams it back as a downloadable file.
        No ``ExportRequest`` record is required — this is a direct,
        one-shot report suitable for the Flutter "Export PDF" button.

        Response:
            200: ``application/pdf`` binary stream with
                 ``Content-Disposition: attachment``.
            500: JSON error envelope if PDF generation fails.
        """
        from .pdf_report_service import generate_habit_report_pdf
        try:
            pdf_bytes = generate_habit_report_pdf(request.user)
        except Exception as exc:
            return Response(
                {'success': False, 'message': f'PDF generation failed: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # Audit trail for traceability
        SettingsAuditLog.log(
            user=request.user,
            category='export',
            action='generate_habit_report',
            description='Generated habit analytics PDF report',
            request=request,
        )

        today = timezone.now().strftime('%Y-%m-%d')
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'attachment; filename="DailyHabits_Report_{today}.pdf"'
        )
        # Expose Content-Disposition header to the Flutter/browser client
        response['Access-Control-Expose-Headers'] = 'Content-Disposition'
        return response

    def _generate_export(self, export_req):
        export_req.status = 'completed'
        export_req.completed_at = timezone.now()
        export_req.save()

    # -----------------------------------------------------------------
    #  Direct CSV / JSON Export (instant, no queue)
    # -----------------------------------------------------------------

    @action(detail=False, methods=['get'], url_path='export-data')
    def export_data(self, request):
        """
        GET /api/exports/export-data/?format=csv&dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD

        Generates a CSV or JSON file on-the-fly and streams it as a
        downloadable attachment.  Mirrors the ``habit-report`` endpoint
        but for tabular / structured formats.

        Query params:
            format   — ``csv`` or ``json`` (required)
            dateFrom — start date ISO-8601 (required)
            dateTo   — end date ISO-8601 (required)

        Response:
            200: binary stream (text/csv or application/json) with
                 ``Content-Disposition: attachment``.
            400: JSON error for missing / invalid parameters.
            500: JSON error on generation failure.
        """
        fmt = request.query_params.get('format', '').lower()
        date_from = request.query_params.get('dateFrom')
        date_to = request.query_params.get('dateTo')

        if fmt not in ('csv', 'json'):
            return Response(
                {'success': False, 'message': 'format must be csv or json'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not date_from or not date_to:
            return Response(
                {'success': False, 'message': 'dateFrom and dateTo are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            from habits.models import Habit, HabitLog
            habits = Habit.objects.filter(
                user=request.user,
                is_deleted=False,
                created_at__date__lte=date_to,
            )
            logs = HabitLog.objects.filter(
                habit__user=request.user,
                date__range=[date_from, date_to],
            ).select_related('habit').order_by('date')

            if fmt == 'json':
                data = self._build_export_data_direct(
                    request.user, habits, logs, date_from, date_to,
                )
                body = json.dumps(data, indent=2, default=str)
                response = HttpResponse(body, content_type='application/json')
                response['Content-Disposition'] = (
                    f'attachment; filename="dailyhabits_export_{date_from}_{date_to}.json"'
                )
            else:  # csv
                buffer = io.StringIO()
                writer = csv.writer(buffer)
                writer.writerow([
                    'Date', 'Habit', 'Category', 'Status', 'Streak', 'Notes',
                ])
                for log in logs:
                    writer.writerow([
                        log.date.isoformat(),
                        log.habit.title,
                        log.habit.category_name,
                        log.status,
                        log.habit.current_streak,
                        log.notes or '',
                    ])
                response = HttpResponse(
                    buffer.getvalue(), content_type='text/csv',
                )
                response['Content-Disposition'] = (
                    f'attachment; filename="dailyhabits_export_{date_from}_{date_to}.csv"'
                )

            response['Access-Control-Expose-Headers'] = 'Content-Disposition'

            # Audit trail
            SettingsAuditLog.log(
                user=request.user,
                category='export',
                action='export_data_direct',
                description=f'{fmt.upper()} export from {date_from} to {date_to}',
                request=request,
            )
            return response

        except Exception as exc:
            return Response(
                {'success': False, 'message': f'Export failed: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def _build_export_data_direct(user, habits, logs, date_from, date_to):
        """Build JSON export dict without requiring an ExportRequest record."""
        return {
            'user': {
                'email': user.email,
                'name': user.name,
                'exportedAt': timezone.now().isoformat(),
            },
            'period': {'from': date_from, 'to': date_to},
            'habits': [
                {
                    'title': h.title,
                    'category': h.category_name,
                    'frequency': h.frequency,
                    'currentStreak': h.current_streak,
                    'bestStreak': h.best_streak,
                    'status': h.status,
                    'createdAt': h.created_at.isoformat(),
                }
                for h in habits
            ],
            'logs': [
                {
                    'date': l.date.isoformat(),
                    'habit': l.habit.title,
                    'status': l.status,
                    'completedAt': (
                        l.completed_at.isoformat() if l.completed_at else None
                    ),
                    'notes': l.notes or '',
                }
                for l in logs[:2000]
            ],
            'summary': {
                'totalHabits': habits.count(),
                'totalLogs': logs.count(),
                'completedLogs': logs.filter(status='completed').count(),
            },
        }


# =========================================================================
#  PRIVACY POLICY
# =========================================================================

class PrivacyPolicyViewSet(viewsets.ViewSet):
    """Public access to privacy-policy documents."""
    permission_classes = [AllowAny]

    def list(self, request):
        policy = PrivacyPolicy.objects.filter(is_current=True).first()
        if not policy:
            return Response({
                'success': True,
                'policy': {
                    'version': '1.0', 'title': 'Privacy Policy',
                    'content': self._default_policy(),
                    'effectiveDate': '2025-01-01', 'lastUpdated': '2025-01-01',
                },
            })
        return Response({
            'success': True,
            'policy': {
                'version': policy.version, 'title': policy.title,
                'content': policy.content,
                'effectiveDate': policy.effective_date.isoformat(),
                'lastUpdated': policy.created_at.isoformat(),
            },
        })

    @action(detail=False, methods=['get'])
    def all(self, request):
        policies = PrivacyPolicy.objects.all()[:10]
        return Response({
            'success': True,
            'policies': [{'version': p.version, 'title': p.title, 'effectiveDate': p.effective_date.isoformat(), 'isCurrent': p.is_current} for p in policies],
        })

    @staticmethod
    def _default_policy():
        return """# DailyHabits Privacy Policy\n\n**Effective Date:** January 1, 2025\n\n## 1. Information We Collect\nWe collect information you provide directly, including your name, email address, and habit data.\n\n## 2. How We Use Your Information\nYour data is used to provide and improve the DailyHabits service, including personalized insights and notifications.\n\n## 3. Data Storage & Security\nAll data is encrypted in transit and at rest. We use industry-standard security practices.\n\n## 4. Data Sharing\nWe do not sell or share your personal data with third parties.\n\n## 5. Your Rights\nYou have the right to access, export, or delete your data at any time through the app settings.\n\n## 6. Data Retention\nWe retain your data for as long as your account is active. You may request deletion at any time.\n\n## 7. Changes to This Policy\nWe will notify you of significant changes via in-app notification.\n\n## 8. Contact Us\nFor privacy questions, contact support@dailyhabits.app"""


# =========================================================================
#  FAQ & SUPPORT
# =========================================================================

class FAQViewSet(viewsets.ViewSet):
    """Public FAQ list."""
    permission_classes = [AllowAny]

    def list(self, request):
        faqs = FAQ.objects.filter(is_active=True)
        if not faqs.exists():
            return Response({'success': True, 'faqs': self._default_faqs()})
        return Response({
            'success': True,
            'faqs': [{'id': f.id, 'question': f.question, 'answer': f.answer, 'category': f.category} for f in faqs],
        })

    @staticmethod
    def _default_faqs():
        return [
            {'id': 1, 'question': 'How do I create a new habit?', 'answer': 'Tap the + button on the home screen, fill in your habit details, and tap Create.', 'category': 'Getting Started'},
            {'id': 2, 'question': 'How do streaks work?', 'answer': 'A streak counts consecutive days you complete a habit. Missing a day resets the streak to 0.', 'category': 'Features'},
            {'id': 3, 'question': 'Can I export my data?', 'answer': 'Yes! Go to Settings - Export Data. You can export as JSON, CSV, or PDF.', 'category': 'Data'},
            {'id': 4, 'question': 'How do I set reminders?', 'answer': 'Open a habit, tap the reminder icon, and set your preferred time and days.', 'category': 'Notifications'},
            {'id': 5, 'question': 'How do quiet hours work?', 'answer': 'Go to Settings - Quiet Hours. Set start/end times. No non-emergency notifications will be sent during these hours.', 'category': 'Notifications'},
            {'id': 6, 'question': 'How do I delete my account?', 'answer': 'Go to Settings - Delete Account. Your data will be permanently removed within 30 days.', 'category': 'Account'},
        ]


class SupportTicketViewSet(viewsets.ModelViewSet):
    """CRUD for user support tickets."""
    permission_classes = [IsAuthenticated]
    serializer_class = SupportTicketSerializer

    def get_queryset(self):
        return SupportTicket.objects.filter(user=self.request.user)

    def list(self, request):
        tickets = self.get_queryset()[:30]
        return Response({
            'success': True,
            'tickets': [{
                'id': t.id, 'subject': t.subject, 'category': t.category,
                'priority': t.priority, 'status': t.status,
                'adminResponse': t.admin_response,
                'createdAt': t.created_at.isoformat(),
                'updatedAt': t.updated_at.isoformat(),
            } for t in tickets],
        })

    def create(self, request, *args, **kwargs):
        subject = request.data.get('subject', '').strip()
        description = request.data.get('description', '').strip()
        category = request.data.get('category', 'general')
        priority = request.data.get('priority', 'medium')
        screenshot_url = request.data.get('screenshotUrl', '')
        if not subject or not description:
            return Response(
                {'success': False, 'message': 'Subject and description are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        ticket = SupportTicket.objects.create(
            user=request.user, subject=subject, description=description,
            category=category, priority=priority, screenshot_url=screenshot_url,
        )
        return Response({
            'success': True, 'message': "Support ticket created. We'll get back to you soon!",
            'ticketId': ticket.id,
        }, status=status.HTTP_201_CREATED)

    def retrieve(self, request, *args, **kwargs):
        try:
            ticket = self.get_queryset().get(pk=kwargs['pk'])
            return Response({
                'success': True,
                'ticket': {
                    'id': ticket.id, 'subject': ticket.subject,
                    'description': ticket.description, 'category': ticket.category,
                    'priority': ticket.priority, 'status': ticket.status,
                    'screenshotUrl': ticket.screenshot_url,
                    'adminResponse': ticket.admin_response,
                    'resolvedAt': ticket.resolved_at.isoformat() if ticket.resolved_at else None,
                    'createdAt': ticket.created_at.isoformat(),
                    'updatedAt': ticket.updated_at.isoformat(),
                },
            })
        except SupportTicket.DoesNotExist:
            return Response({'success': False, 'message': 'Ticket not found'}, status=status.HTTP_404_NOT_FOUND)
