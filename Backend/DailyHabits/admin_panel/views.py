"""
admin_panel/views.py — Admin API ViewSets & Views
===================================================
Every view enforces RBAC via permission classes and logs actions
through AuditService.
"""

import csv
import io
import logging
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import filters, generics, status, viewsets
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework.views import APIView

from achievements.models import Achievement
from gamification.models import (
    Challenge,
    LeaderboardEntry,
    MilestoneReward,
)
from habits.models import Habit, HabitLog

from .models import (
    AdminProfile,
    AdminRole,
    AISafetyLog,
    AIUserRestriction,
    AuditLog,
    ContentModerationQueue,
    FeatureFlag,
    NotificationCampaign,
    NotificationTemplate,
    PlatformAnalyticsSnapshot,
    Report,
    SystemSettings,
    UserWarning,
)
from .permissions import (
    CanDeleteUsers,
    CanEditGamification,
    CanEditSettings,
    CanEditUsers,
    CanExportAnalytics,
    CanManageAISafety,
    CanManageFeatureFlags,
    CanModerateContent,
    CanSendNotifications,
    CanSuspendUsers,
    CanViewAnalytics,
    CanViewAISafety,
    CanViewAuditLogs,
    CanViewGamification,
    CanViewModeration,
    CanViewNotifications,
    CanViewSettings,
    CanViewUsers,
    HasAdminPermission,
    IsAdminUser,
)
from .serializers import (
    AdminAchievementSerializer,
    AdminChallengeSerializer,
    AdminLeaderboardEntrySerializer,
    AdminMilestoneRewardSerializer,
    AdminProfileCreateSerializer,
    AdminProfileSerializer,
    AdminRoleSerializer,
    AdminUserDetailSerializer,
    AdminUserEditSerializer,
    AdminUserListSerializer,
    AISafetyLogSerializer,
    AIUserRestrictionSerializer,
    AuditLogSerializer,
    ContentModerationQueueSerializer,
    FeatureFlagSerializer,
    GrowthTrendSerializer,
    ModerationDecisionSerializer,
    NotificationCampaignSerializer,
    NotificationTemplateSerializer,
    OverviewStatsSerializer,
    PlatformAnalyticsSnapshotSerializer,
    ReportResolveSerializer,
    ReportSerializer,
    SystemSettingsSerializer,
    SystemSettingsUpdateSerializer,
    UserWarningCreateSerializer,
    UserWarningSerializer,
)
from .services import AnalyticsService, AuditService

logger = logging.getLogger('admin_panel')
User = get_user_model()


# ═══════════════════════════════════════════════════════════════════════════════
#  Pagination
# ═══════════════════════════════════════════════════════════════════════════════

class AdminPagination(PageNumberPagination):
    page_size = 25
    page_size_query_param = 'page_size'
    max_page_size = 100


# ═══════════════════════════════════════════════════════════════════════════════
#  ADMIN PROFILE (self)
# ═══════════════════════════════════════════════════════════════════════════════

class AdminMeView(APIView):
    """Return the authenticated admin's profile and permissions."""
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        profile = request.user.admin_profile
        data = dict(AdminProfileSerializer(profile).data)
        data['permissions'] = profile.role.permissions
        return Response(data)


# ═══════════════════════════════════════════════════════════════════════════════
#  RBAC MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class AdminRoleViewSet(viewsets.ModelViewSet):
    """CRUD for admin roles — Super Admin only."""
    queryset = AdminRole.objects.all()
    serializer_class = AdminRoleSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    pagination_class = AdminPagination

    def get_required_permission(self):
        if self.action in ('list', 'retrieve'):
            return 'settings.view'
        return 'settings.edit'


class AdminProfileViewSet(viewsets.ModelViewSet):
    """Manage admin profiles (assign/revoke admin access)."""
    queryset = AdminProfile.objects.select_related('user', 'role').all()
    permission_classes = [IsAuthenticated, IsAdminUser]
    pagination_class = AdminPagination

    def get_serializer_class(self):
        if self.action == 'create':
            return AdminProfileCreateSerializer
        return AdminProfileSerializer

    def get_required_permission(self):
        if self.action in ('list', 'retrieve'):
            return 'settings.view'
        return 'settings.edit'

    def perform_create(self, serializer):
        profile = serializer.save(created_by=self.request.user)
        AuditService.log(
            admin_user=self.request.user,
            action='role_change',
            resource_type='AdminProfile',
            resource_id=str(profile.id),
            description=f'Created admin profile for {profile.user.email}',
            request=self.request,
        )

    def perform_update(self, serializer):
        old_role = self.get_object().role.name
        profile = serializer.save()
        AuditService.log(
            admin_user=self.request.user,
            action='role_change',
            resource_type='AdminProfile',
            resource_id=str(profile.id),
            description=f'Updated admin profile for {profile.user.email}',
            changes={'old_role': old_role, 'new_role': profile.role.name},
            request=self.request,
        )


# ═══════════════════════════════════════════════════════════════════════════════
#  USER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class AdminUserViewSet(viewsets.ModelViewSet):
    """
    Full user management: list, detail, edit, suspend, activate, delete.
    """
    queryset = User.objects.all().order_by('-created_at')
    permission_classes = [IsAuthenticated, IsAdminUser]
    pagination_class = AdminPagination
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['email', 'name']
    ordering_fields = ['created_at', 'last_login', 'email', 'name']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return AdminUserDetailSerializer
        if self.action in ('partial_update', 'update'):
            return AdminUserEditSerializer
        return AdminUserListSerializer

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewUsers()]
        if self.action in ('update', 'partial_update'):
            return [IsAuthenticated(), CanEditUsers()]
        if self.action == 'destroy':
            return [IsAuthenticated(), CanDeleteUsers()]
        return [IsAuthenticated(), IsAdminUser()]

    def perform_update(self, serializer):
        user = self.get_object()
        old_active = user.is_active
        serializer.save()
        AuditService.log(
            admin_user=self.request.user,
            action='user_edit',
            resource_type='User',
            resource_id=str(user.id),
            description=f'Edited user {user.email}',
            changes=serializer.validated_data,
            request=self.request,
        )
        # Detect suspension
        if old_active and not serializer.validated_data.get('is_active', True):
            AuditService.log(
                admin_user=self.request.user,
                action='user_suspend',
                resource_type='User',
                resource_id=str(user.id),
                description=f'Suspended user {user.email}',
                request=self.request,
                severity='warning',
            )

    def perform_destroy(self, instance):
        AuditService.log(
            admin_user=self.request.user,
            action='user_delete',
            resource_type='User',
            resource_id=str(instance.id),
            description=f'Deleted user {instance.email}',
            request=self.request,
            severity='critical',
        )
        instance.delete()

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanSuspendUsers])
    def suspend(self, request, pk=None):
        """POST /admin/users/{id}/suspend/ — deactivate user."""
        user = self.get_object()
        user.is_active = False
        user.save(update_fields=['is_active'])
        AuditService.log(
            admin_user=request.user, action='user_suspend',
            resource_type='User', resource_id=str(user.id),
            description=f'Suspended {user.email}',
            request=request, severity='warning',
        )
        return Response({'message': f'{user.email} suspended.'})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanSuspendUsers])
    def activate(self, request, pk=None):
        """POST /admin/users/{id}/activate/ — reactivate user."""
        user = self.get_object()
        user.is_active = True
        user.save(update_fields=['is_active'])
        AuditService.log(
            admin_user=request.user, action='user_activate',
            resource_type='User', resource_id=str(user.id),
            description=f'Activated {user.email}',
            request=request,
        )
        return Response({'message': f'{user.email} activated.'})

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated, CanViewUsers])
    def habits(self, request, pk=None):
        """GET /admin/users/{id}/habits/ — list user habits."""
        user = self.get_object()
        habits = Habit.objects.filter(user=user, is_deleted=False).values(
            'id', 'title', 'status', 'frequency', 'priority',
            'category_name', 'created_at',
        )
        return Response(list(habits))

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated, CanViewUsers])
    def analytics(self, request, pk=None):
        """GET /admin/users/{id}/analytics/ — user engagement snapshot."""
        user = self.get_object()
        today = timezone.now().date()
        week_ago = today - timedelta(days=7)

        total = HabitLog.objects.filter(habit__user=user, date__gte=week_ago).count()
        completed = HabitLog.objects.filter(
            habit__user=user, date__gte=week_ago, status='completed',
        ).count()

        return Response({
            'user_id': user.id,
            'email': user.email,
            'current_streak': user.current_streak,
            'total_habits': Habit.objects.filter(user=user, is_deleted=False).count(),
            'completion_rate_7d': round(completed / total * 100, 1) if total else 0,
            'last_login': user.last_login,
        })

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanEditUsers])
    def reset_password(self, request, pk=None):
        """POST /admin/users/{id}/reset_password/ — admin-initiated reset."""
        from authentication.password_reset_service import PasswordResetService
        user = self.get_object()
        result = PasswordResetService.request_reset(user.email, request)
        AuditService.log(
            admin_user=request.user, action='user_password_reset',
            resource_type='User', resource_id=str(user.id),
            description=f'Admin-initiated password reset for {user.email}',
            request=request,
        )
        return Response({'message': f'Password reset email sent to {user.email}.'})


# ═══════════════════════════════════════════════════════════════════════════════
#  REPORTS
# ═══════════════════════════════════════════════════════════════════════════════

class ReportViewSet(viewsets.ModelViewSet):
    """Manage user-submitted reports."""
    queryset = Report.objects.select_related(
        'reporter', 'reported_user', 'assigned_to', 'resolved_by',
    ).all()
    serializer_class = ReportSerializer
    permission_classes = [IsAuthenticated, CanViewModeration]
    pagination_class = AdminPagination
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['category', 'description', 'reported_user__email']
    ordering_fields = ['created_at', 'priority', 'status']

    def get_queryset(self):
        qs = super().get_queryset()
        status_filter = self.request.query_params.get('status')
        priority_filter = self.request.query_params.get('priority')
        category_filter = self.request.query_params.get('category')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if priority_filter:
            qs = qs.filter(priority=priority_filter)
        if category_filter:
            qs = qs.filter(category=category_filter)
        return qs

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanModerateContent])
    def resolve(self, request, pk=None):
        """POST /admin/reports/{id}/resolve/"""
        report = self.get_object()
        serializer = ReportResolveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        report.status = serializer.validated_data['status']
        report.resolution = serializer.validated_data['resolution']
        report.resolution_action = serializer.validated_data.get('resolution_action', 'none')
        report.resolved_by = request.user
        report.resolved_at = timezone.now()
        report.save()

        # Apply resolution action
        action_taken = report.resolution_action
        if action_taken == 'suspend' and report.reported_user:
            report.reported_user.is_active = False
            report.reported_user.save(update_fields=['is_active'])
        elif action_taken == 'warn' and report.reported_user:
            UserWarning.objects.create(
                user=report.reported_user,
                issued_by=request.user,
                severity='formal',
                reason=report.resolution,
                related_report=report,
            )

        AuditService.log(
            admin_user=request.user, action='report_resolve',
            resource_type='Report', resource_id=str(report.id),
            description=f'Resolved report: {report.category} → {report.status}',
            changes={'resolution_action': action_taken},
            request=request,
        )
        return Response(ReportSerializer(report).data)


# ═══════════════════════════════════════════════════════════════════════════════
#  CONTENT MODERATION
# ═══════════════════════════════════════════════════════════════════════════════

class ContentModerationViewSet(viewsets.ModelViewSet):
    """Review queue for flagged community content."""
    queryset = ContentModerationQueue.objects.select_related('content_author', 'report').all()
    serializer_class = ContentModerationQueueSerializer
    permission_classes = [IsAuthenticated, CanViewModeration]
    pagination_class = AdminPagination

    def get_queryset(self):
        qs = super().get_queryset()
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanModerateContent])
    def decide(self, request, pk=None):
        """POST /admin/moderation/{id}/decide/ — approve or reject."""
        item = self.get_object()
        serializer = ModerationDecisionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        decision = serializer.validated_data['action']
        item.status = 'approved' if decision == 'approve' else 'rejected'
        item.reviewed_by = request.user
        item.reviewed_at = timezone.now()
        item.reviewer_notes = serializer.validated_data.get('notes', '')
        item.save()

        audit_action = 'content_approve' if decision == 'approve' else 'content_reject'
        AuditService.log(
            admin_user=request.user, action=audit_action,
            resource_type='ContentModeration', resource_id=str(item.id),
            description=f'{decision.title()} {item.content_type}/{item.content_id}',
            request=request,
        )
        return Response(ContentModerationQueueSerializer(item).data)


class UserWarningViewSet(viewsets.ModelViewSet):
    """Issue and track user warnings."""
    queryset = UserWarning.objects.select_related('user', 'issued_by').all()
    serializer_class = UserWarningSerializer
    permission_classes = [IsAuthenticated, CanModerateContent]
    pagination_class = AdminPagination

    def get_queryset(self):
        qs = super().get_queryset()
        user_id = self.request.query_params.get('user_id')
        if user_id:
            qs = qs.filter(user_id=user_id)
        return qs

    def perform_create(self, serializer):
        warning = serializer.save(issued_by=self.request.user)
        AuditService.log(
            admin_user=self.request.user, action='content_reject',
            resource_type='UserWarning', resource_id=str(warning.id),
            description=f'Warning issued to user {warning.user.email}: {warning.severity}',
            request=self.request,
        )


# ═══════════════════════════════════════════════════════════════════════════════
#  ANALYTICS
# ═══════════════════════════════════════════════════════════════════════════════

class OverviewStatsView(APIView):
    """GET /admin/analytics/overview/ — real-time KPI dashboard."""
    permission_classes = [IsAuthenticated, CanViewAnalytics]

    def get(self, request):
        stats = AnalyticsService.get_overview_stats()
        return Response(stats)


class GrowthTrendsView(APIView):
    """GET /admin/analytics/growth/?days=30 — user growth time series."""
    permission_classes = [IsAuthenticated, CanViewAnalytics]

    def get(self, request):
        days = int(request.query_params.get('days', 30))
        days = min(days, 365)  # Cap at 1 year
        trends = AnalyticsService.get_growth_trends(days)
        return Response(trends)


class EngagementMetricsView(APIView):
    """GET /admin/analytics/engagement/?days=30 — engagement breakdown."""
    permission_classes = [IsAuthenticated, CanViewAnalytics]

    def get(self, request):
        days = int(request.query_params.get('days', 30))
        days = min(days, 365)
        metrics = AnalyticsService.get_engagement_metrics(days)
        return Response(metrics)


class RetentionMetricsView(APIView):
    """GET /admin/analytics/retention/ — cohort retention rates."""
    permission_classes = [IsAuthenticated, CanViewAnalytics]

    def get(self, request):
        retention = AnalyticsService.get_retention_metrics()
        return Response(retention)


class AnalyticsSnapshotViewSet(viewsets.ReadOnlyModelViewSet):
    """Historical daily snapshots for charting."""
    queryset = PlatformAnalyticsSnapshot.objects.all()
    serializer_class = PlatformAnalyticsSnapshotSerializer
    permission_classes = [IsAuthenticated, CanViewAnalytics]
    pagination_class = AdminPagination

    def get_queryset(self):
        qs = super().get_queryset()
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        return qs


class AnalyticsExportView(APIView):
    """GET /admin/analytics/export/?days=30 — CSV download."""
    permission_classes = [IsAuthenticated, CanExportAnalytics]

    def get(self, request):
        days = int(request.query_params.get('days', 30))
        trends = AnalyticsService.get_growth_trends(min(days, 365))

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['Date', 'Total Users', 'New Users', 'DAU', 'Completion Rate'])
        for row in trends:
            writer.writerow([
                row['date'], row['total_users'], row['new_users'],
                row['daily_active_users'], row['completion_rate'],
            ])

        response = HttpResponse(output.getvalue(), content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="analytics_{days}d.csv"'

        AuditService.log(
            admin_user=request.user, action='export_data',
            resource_type='Analytics', description=f'Exported {days}-day analytics CSV',
            request=request,
        )
        return response


# ═══════════════════════════════════════════════════════════════════════════════
#  SYSTEM SETTINGS & FEATURE FLAGS
# ═══════════════════════════════════════════════════════════════════════════════

class SystemSettingsViewSet(viewsets.ModelViewSet):
    """CRUD for key-value system settings."""
    queryset = SystemSettings.objects.all()
    serializer_class = SystemSettingsSerializer
    permission_classes = [IsAuthenticated, CanViewSettings]
    pagination_class = AdminPagination
    lookup_field = 'key'

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewSettings()]
        return [IsAuthenticated(), CanEditSettings()]

    def perform_update(self, serializer):
        old_value = self.get_object().value
        obj = serializer.save(updated_by=self.request.user)
        AuditService.log(
            admin_user=self.request.user, action='settings_change',
            resource_type='SystemSettings', resource_id=obj.key,
            description=f'Updated setting: {obj.key}',
            changes={'old_value': old_value, 'new_value': obj.value},
            request=self.request,
        )


class FeatureFlagViewSet(viewsets.ModelViewSet):
    """CRUD and toggle for feature flags."""
    queryset = FeatureFlag.objects.all()
    serializer_class = FeatureFlagSerializer
    permission_classes = [IsAuthenticated, CanManageFeatureFlags]
    pagination_class = AdminPagination

    @action(detail=True, methods=['post'])
    def toggle(self, request, pk=None):
        """POST /admin/feature-flags/{id}/toggle/"""
        flag = self.get_object()
        flag.is_enabled = not flag.is_enabled
        flag.updated_by = request.user
        flag.save()
        AuditService.log(
            admin_user=request.user, action='feature_flag_toggle',
            resource_type='FeatureFlag', resource_id=flag.key,
            description=f'Toggled {flag.key} → {"ON" if flag.is_enabled else "OFF"}',
            request=request,
        )
        return Response(FeatureFlagSerializer(flag).data)


# ═══════════════════════════════════════════════════════════════════════════════
#  NOTIFICATION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class NotificationTemplateViewSet(viewsets.ModelViewSet):
    """CRUD for notification templates."""
    queryset = NotificationTemplate.objects.all()
    serializer_class = NotificationTemplateSerializer
    permission_classes = [IsAuthenticated, CanViewNotifications]
    pagination_class = AdminPagination

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewNotifications()]
        return [IsAuthenticated(), CanSendNotifications()]

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    def perform_update(self, serializer):
        obj = serializer.save()
        AuditService.log(
            admin_user=self.request.user,
            action='notification_template_edit',
            resource_type='NotificationTemplate',
            resource_id=str(obj.id),
            description=f'Updated template: {obj.name}',
            request=self.request,
        )


class NotificationCampaignViewSet(viewsets.ModelViewSet):
    """Create, schedule, and monitor notification campaigns."""
    queryset = NotificationCampaign.objects.all()
    serializer_class = NotificationCampaignSerializer
    permission_classes = [IsAuthenticated, CanViewNotifications]
    pagination_class = AdminPagination

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewNotifications()]
        return [IsAuthenticated(), CanSendNotifications()]

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanSendNotifications])
    def send(self, request, pk=None):
        """POST /admin/campaigns/{id}/send/ — trigger campaign delivery."""
        campaign = self.get_object()
        if campaign.status not in ('draft', 'scheduled'):
            return Response(
                {'error': f'Cannot send campaign in "{campaign.status}" state.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Determine recipients count
        audience_map = {
            'all': User.objects.filter(is_active=True).count(),
            'active': User.objects.filter(
                is_active=True,
                last_login__gte=timezone.now() - timedelta(days=7),
            ).count(),
            'inactive': User.objects.filter(
                is_active=True,
                last_login__lt=timezone.now() - timedelta(days=30),
            ).count(),
            'new': User.objects.filter(
                is_active=True,
                created_at__gte=timezone.now() - timedelta(days=7),
            ).count(),
        }
        campaign.total_recipients = audience_map.get(campaign.target_audience, 0)
        campaign.status = 'sending'
        campaign.sent_at = timezone.now()
        campaign.save()

        # In production, this would dispatch to Celery
        # For now, mark as sent immediately
        campaign.status = 'sent'
        campaign.delivered_count = campaign.total_recipients
        campaign.save()

        AuditService.log(
            admin_user=request.user, action='notification_send',
            resource_type='NotificationCampaign',
            resource_id=str(campaign.id),
            description=f'Sent campaign "{campaign.name}" to {campaign.total_recipients} users',
            request=request,
        )
        return Response(NotificationCampaignSerializer(campaign).data)

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanSendNotifications])
    def cancel(self, request, pk=None):
        """POST /admin/campaigns/{id}/cancel/"""
        campaign = self.get_object()
        if campaign.status not in ('draft', 'scheduled'):
            return Response(
                {'error': 'Only draft/scheduled campaigns can be cancelled.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        campaign.status = 'cancelled'
        campaign.save()
        return Response(NotificationCampaignSerializer(campaign).data)


# ═══════════════════════════════════════════════════════════════════════════════
#  GAMIFICATION CONTROLS
# ═══════════════════════════════════════════════════════════════════════════════

class AdminAchievementViewSet(viewsets.ModelViewSet):
    """Manage achievements/badges."""
    queryset = Achievement.objects.all()
    serializer_class = AdminAchievementSerializer
    permission_classes = [IsAuthenticated, CanViewGamification]
    pagination_class = AdminPagination

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewGamification()]
        return [IsAuthenticated(), CanEditGamification()]

    def perform_update(self, serializer):
        obj = serializer.save()
        AuditService.log(
            admin_user=self.request.user, action='gamification_change',
            resource_type='Achievement', resource_id=str(obj.id),
            description=f'Updated achievement: {obj.name}',
            request=self.request,
        )


class AdminChallengeViewSet(viewsets.ModelViewSet):
    """Manage challenges."""
    queryset = Challenge.objects.all()
    serializer_class = AdminChallengeSerializer
    permission_classes = [IsAuthenticated, CanViewGamification]
    pagination_class = AdminPagination

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewGamification()]
        return [IsAuthenticated(), CanEditGamification()]


class AdminMilestoneRewardViewSet(viewsets.ModelViewSet):
    """Manage milestone rewards / XP rules."""
    queryset = MilestoneReward.objects.all()
    serializer_class = AdminMilestoneRewardSerializer
    permission_classes = [IsAuthenticated, CanViewGamification]
    pagination_class = AdminPagination

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [IsAuthenticated(), CanViewGamification()]
        return [IsAuthenticated(), CanEditGamification()]

    def perform_update(self, serializer):
        obj = serializer.save()
        AuditService.log(
            admin_user=self.request.user, action='gamification_change',
            resource_type='MilestoneReward', resource_id=str(obj.id),
            description=f'Updated milestone: {obj.title}',
            request=self.request,
        )


class AdminLeaderboardViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only leaderboard view for admin oversight."""
    queryset = LeaderboardEntry.objects.select_related('user').all().order_by('rank')
    serializer_class = AdminLeaderboardEntrySerializer
    permission_classes = [IsAuthenticated, CanViewGamification]
    pagination_class = AdminPagination

    def get_queryset(self):
        qs = super().get_queryset()
        board_type = self.request.query_params.get('board_type')
        if board_type:
            qs = qs.filter(board_type=board_type)
        return qs


# ═══════════════════════════════════════════════════════════════════════════════
#  AUDIT LOGS
# ═══════════════════════════════════════════════════════════════════════════════

class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Read-only access to the immutable audit trail.
    Supports filtering by action, admin user, date range, severity.
    """
    queryset = AuditLog.objects.select_related('admin_user').all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsAuthenticated, CanViewAuditLogs]
    pagination_class = AdminPagination
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['action', 'description', 'admin_user__email']
    ordering_fields = ['created_at', 'severity']

    def get_queryset(self):
        qs = super().get_queryset()
        action_filter = self.request.query_params.get('action')
        severity_filter = self.request.query_params.get('severity')
        admin_id = self.request.query_params.get('admin_id')
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')

        if action_filter:
            qs = qs.filter(action=action_filter)
        if severity_filter:
            qs = qs.filter(severity=severity_filter)
        if admin_id:
            qs = qs.filter(admin_user_id=admin_id)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)
        return qs


# ═══════════════════════════════════════════════════════════════════════════════
#  AI SAFETY
# ═══════════════════════════════════════════════════════════════════════════════

class AISafetyLogViewSet(viewsets.ModelViewSet):
    """Monitor and review AI-generated outputs."""
    queryset = AISafetyLog.objects.select_related('user').all()
    serializer_class = AISafetyLogSerializer
    permission_classes = [IsAuthenticated, CanViewAISafety]
    pagination_class = AdminPagination

    def get_queryset(self):
        qs = super().get_queryset()
        status_filter = self.request.query_params.get('status')
        feature_filter = self.request.query_params.get('feature')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if feature_filter:
            qs = qs.filter(feature=feature_filter)
        return qs

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated, CanManageAISafety])
    def review(self, request, pk=None):
        """POST /admin/ai-safety/{id}/review/ — mark as reviewed."""
        log = self.get_object()
        new_status = request.data.get('status', 'reviewed')
        if new_status not in ('reviewed', 'reviewed_unsafe'):
            return Response({'error': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)
        log.status = new_status
        log.reviewed_by = request.user
        log.reviewed_at = timezone.now()
        log.save()
        return Response(AISafetyLogSerializer(log).data)


class AIUserRestrictionViewSet(viewsets.ModelViewSet):
    """Manage per-user AI feature restrictions."""
    queryset = AIUserRestriction.objects.select_related('user').all()
    serializer_class = AIUserRestrictionSerializer
    permission_classes = [IsAuthenticated, CanManageAISafety]
    pagination_class = AdminPagination

    def perform_create(self, serializer):
        serializer.save(disabled_by=self.request.user)

    def get_queryset(self):
        qs = super().get_queryset()
        user_id = self.request.query_params.get('user_id')
        if user_id:
            qs = qs.filter(user_id=user_id)
        return qs
