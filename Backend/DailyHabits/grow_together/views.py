"""
Grow Together — API Views
==========================

DRF ViewSet classes exposing the Grow Together API surface.
All endpoints require ``IsAuthenticated`` and return JSON envelopes
with a top-level ``success`` boolean.
"""

from __future__ import annotations

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from .models import (
    CollaborativeHabit,
    CollaborativeHabitMember,
    CollaborativeHabitProgress,
    HabitInvite,
    ProgressComment,
    GroupMilestone,
)
from .serializers import (
    CollaborativeHabitCreateSerializer,
    CollaborativeHabitSerializer,
    CollaborativeHabitMemberSerializer,
    CollaborativeProgressSerializer,
    ProgressRecordSerializer,
    InviteCreateSerializer,
    HabitInviteSerializer,
    HabitActivityLogSerializer,
    ProgressReactionSerializer,
    ProgressCommentSerializer,
    WeeklyLeaderboardSerializer,
    GroupMilestoneSerializer,
    AbuseReportCreateSerializer,
    AbuseReportSerializer,
    GrowTogetherDashboardSerializer,
    StreakFreezeSerializer,
    StreakFreezeInfoSerializer,
    StreakCalendarSerializer,
    UnmarkProgressResponseSerializer,
    ProgressResultSerializer,
    TodayStatusSerializer,
    GroupProgressSerializer,
)
from .services import GrowTogetherService


# ─── Rate Throttles ─────────────────────────────────────────────────────

class GrowTogetherBurstThrottle(UserRateThrottle):
    """Burst rate limit: 30 requests per minute per user."""
    rate = '30/min'


class GrowTogetherSustainedThrottle(UserRateThrottle):
    """Sustained rate limit: 500 requests per hour per user."""
    rate = '500/hour'


# ═══════════════════════════════════════════════════════════════════════════
#  GROW TOGETHER VIEWSET
# ═══════════════════════════════════════════════════════════════════════════

class GrowTogetherViewSet(viewsets.ViewSet):
    """
    Comprehensive ViewSet for the Grow Together habit sharing system.

    Endpoints:
        POST   /create/               — Create a new collaborative habit
        GET    /                       — List user's collaborative habits
        GET    /{id}/                  — Retrieve a single collaborative habit
        GET    /dashboard/             — Full dashboard aggregate
        GET    /discover/              — Browse public habits to join
        POST   /{id}/invite/           — Send invitations to friends
        POST   /accept-invite/         — Accept an invitation
        POST   /decline-invite/        — Decline an invitation
        GET    /my-invites/            — List pending invitations
        POST   /{id}/progress/         — Log daily progress
        POST   /{id}/unmark-progress/  — Undo today's completion
        GET    /{id}/progress/         — Get member progress for a date
        GET    /{id}/streak-calendar/  — 30-day visual streak calendar
        GET    /{id}/streak-freezes/   — List streak freeze tokens
        POST   /{id}/buy-freeze/       — Purchase streak freeze with XP
        POST   /{id}/use-freeze/       — Use streak freeze on a missed day
        GET    /{id}/members/          — List all members
        POST   /{id}/leave/            — Leave the habit
        POST   /{id}/remove-member/    — Remove a member (owner/admin)
        POST   /{id}/join/             — Join a public habit
        POST   /progress/{id}/react/   — Toggle reaction on progress
        POST   /progress/{id}/comment/ — Comment on progress
        GET    /progress/{id}/comments/— List comments
        GET    /{id}/feed/             — Activity feed for a habit
        GET    /feed/                  — Global feed across all habits
        GET    /{id}/leaderboard/      — Weekly leaderboard
        GET    /{id}/milestones/       — Group milestones
        GET    /{id}/analytics/        — Engagement analytics
        POST   /{id}/report/           — Report abuse
    """

    permission_classes = [IsAuthenticated]
    throttle_classes = [GrowTogetherBurstThrottle, GrowTogetherSustainedThrottle]

    # ─── Core CRUD ──────────────────────────────────────────────────

    def list(self, request):
        """GET /api/grow-together/ — List my collaborative habits."""
        habits = GrowTogetherService.get_user_collaborative_habits(request.user)
        serializer = CollaborativeHabitSerializer(
            habits, many=True, context={'request': request},
        )
        return Response({'success': True, 'results': serializer.data})

    def retrieve(self, request, pk=None):
        """GET /api/grow-together/{id}/ — Get a single collaborative habit."""
        try:
            habit = CollaborativeHabit.objects.select_related(
                'owner',
            ).prefetch_related(
                'members__user', 'progress_records', 'milestones',
            ).get(id=pk, is_active=True)
        except (CollaborativeHabit.DoesNotExist, ValueError):
            return Response(
                {'success': False, 'message': 'Collaborative habit not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        is_member = habit.members.filter(
            user=request.user, is_active=True,
        ).exists()
        if not is_member and habit.privacy != 'public':
            return Response(
                {'success': False, 'message': 'Access denied.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = CollaborativeHabitSerializer(
            habit, context={'request': request},
        )
        return Response({'success': True, 'habit': serializer.data})

    @action(detail=False, methods=['post'], url_path='create')
    def create_habit(self, request):
        """POST /api/grow-together/create/ — Create a new collaborative habit."""
        serializer = CollaborativeHabitCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'errors': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            habit = GrowTogetherService.create_collaborative_habit(
                request.user, serializer.validated_data,
            )
            out = CollaborativeHabitSerializer(
                habit, context={'request': request},
            )
            return Response(
                {'success': True, 'habit': out.data},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=False, methods=['get'], url_path='dashboard')
    def dashboard(self, request):
        """GET /api/grow-together/dashboard/ — Full dashboard."""
        data = GrowTogetherService.get_dashboard(request.user)
        serializer = GrowTogetherDashboardSerializer(
            {
                'myCollaborativeHabits': data['myCollaborativeHabits'],
                'pendingInvites': data['pendingInvites'],
                'discoverableHabits': data['discoverableHabits'],
                'recentActivity': data['recentActivity'],
                'totalActiveHabits': data['totalActiveHabits'],
                'totalCompletionsToday': data['totalCompletionsToday'],
                'overallGroupStreak': data['overallGroupStreak'],
            },
            context={'request': request},
        )
        return Response({'success': True, **serializer.data})

    @action(detail=False, methods=['get'], url_path='discover')
    def discover(self, request):
        """GET /api/grow-together/discover/ — Browse public habits."""
        limit = min(int(request.query_params.get('limit', 20)), 50)
        habits = GrowTogetherService.get_discoverable_habits(request.user, limit)
        serializer = CollaborativeHabitSerializer(
            habits, many=True, context={'request': request},
        )
        return Response({'success': True, 'results': serializer.data})

    # ─── Invitations ────────────────────────────────────────────────

    @action(detail=True, methods=['post'], url_path='invite')
    def invite(self, request, pk=None):
        """POST /api/grow-together/{id}/invite/ — Invite friends."""
        serializer = InviteCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'errors': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            invites = GrowTogetherService.send_invites(
                user=request.user,
                collaborative_habit_id=str(pk),
                friend_ids=serializer.validated_data['friendIds'],
                message=serializer.validated_data.get('message', ''),
            )
            out = HabitInviteSerializer(invites, many=True)
            return Response(
                {'success': True, 'invites': out.data, 'count': len(invites)},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=False, methods=['post'], url_path='accept-invite')
    def accept_invite(self, request):
        """POST /api/grow-together/accept-invite/ — Accept an invitation."""
        invite_id = request.data.get('inviteId')
        if not invite_id:
            return Response(
                {'success': False, 'message': 'inviteId is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            member = GrowTogetherService.accept_invite(request.user, str(invite_id))
            return Response({
                'success': True,
                'message': 'Invitation accepted!',
                'habitId': str(member.collaborative_habit_id),
            })
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=False, methods=['post'], url_path='decline-invite')
    def decline_invite(self, request):
        """POST /api/grow-together/decline-invite/ — Decline an invitation."""
        invite_id = request.data.get('inviteId')
        if not invite_id:
            return Response(
                {'success': False, 'message': 'inviteId is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            GrowTogetherService.decline_invite(request.user, str(invite_id))
            return Response({'success': True, 'message': 'Invitation declined.'})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=False, methods=['get'], url_path='my-invites')
    def my_invites(self, request):
        """GET /api/grow-together/my-invites/ — List pending invitations."""
        invites = GrowTogetherService.get_pending_invites(request.user)
        serializer = HabitInviteSerializer(invites, many=True)
        return Response({'success': True, 'results': serializer.data})

    # ─── Progress ───────────────────────────────────────────────────

    @action(detail=True, methods=['get', 'post'], url_path='progress')
    def progress(self, request, pk=None):
        """
        GET  /api/grow-together/{id}/progress/ — Today's progress.
        POST /api/grow-together/{id}/progress/ — Log your progress.
        """
        if request.method == 'GET':
            date_str = request.query_params.get('date')
            target_date = None
            if date_str:
                from datetime import date as dt_date
                try:
                    target_date = dt_date.fromisoformat(date_str)
                except ValueError:
                    return Response(
                        {'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            records = GrowTogetherService.get_daily_progress(str(pk), target_date)
            serializer = CollaborativeProgressSerializer(records, many=True)
            return Response({'success': True, 'results': serializer.data})

        ser = ProgressRecordSerializer(data=request.data)
        if not ser.is_valid():
            return Response(
                {'success': False, 'errors': ser.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            result = GrowTogetherService.log_progress(
                user=request.user,
                collaborative_habit_id=str(pk),
                note=ser.validated_data.get('note', ''),
                completion_count=ser.validated_data.get('completionCount', 1),
            )
            out = ProgressResultSerializer(result)
            return Response(
                {'success': True, **out.data},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Unmark Progress (Undo) ────────────────────────────────────

    @action(detail=True, methods=['post'], url_path='unmark-progress')
    def unmark_progress(self, request, pk=None):
        """POST /api/grow-together/{id}/unmark-progress/ — Undo today's completion."""
        try:
            result = GrowTogetherService.unmark_progress(
                user=request.user,
                collaborative_habit_id=str(pk),
            )
            out = UnmarkProgressResponseSerializer(result)
            return Response({'success': True, **out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Streak Calendar ───────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='streak-calendar')
    def streak_calendar(self, request, pk=None):
        """GET /api/grow-together/{id}/streak-calendar/ — 30-day visual streak history."""
        days = min(int(request.query_params.get('days', 30)), 90)
        try:
            data = GrowTogetherService.get_streak_calendar(
                user=request.user,
                collaborative_habit_id=str(pk),
                days=days,
            )
            out = StreakCalendarSerializer(data)
            return Response({'success': True, **out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Today Status ──────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='today-status')
    def today_status(self, request, pk=None):
        """GET /api/grow-together/{id}/today-status/ — User's completion status for today."""
        try:
            data = GrowTogetherService.get_today_status(
                user=request.user,
                collaborative_habit_id=str(pk),
            )
            out = TodayStatusSerializer(data)
            return Response({'success': True, **out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Group Progress ────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='group-progress')
    def group_progress(self, request, pk=None):
        """GET /api/grow-together/{id}/group-progress/ — Group-level progress for today."""
        date_str = request.query_params.get('date')
        target_date = None
        if date_str:
            from datetime import date as dt_date
            try:
                target_date = dt_date.fromisoformat(date_str)
            except ValueError:
                return Response(
                    {'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            data = GrowTogetherService.get_group_progress(
                collaborative_habit_id=str(pk),
                target_date=target_date,
            )
            out = GroupProgressSerializer(data)
            return Response({'success': True, **out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Streak Freezes ────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='streak-freezes')
    def streak_freezes(self, request, pk=None):
        """GET /api/grow-together/{id}/streak-freezes/ — List streak freeze tokens."""
        try:
            data = GrowTogetherService.get_streak_freezes(
                user=request.user,
                collaborative_habit_id=str(pk),
            )
            out = StreakFreezeInfoSerializer(data)
            return Response({'success': True, **out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=True, methods=['post'], url_path='buy-freeze')
    def buy_freeze(self, request, pk=None):
        """POST /api/grow-together/{id}/buy-freeze/ — Purchase a streak freeze."""
        try:
            freeze = GrowTogetherService.purchase_streak_freeze(
                user=request.user,
                collaborative_habit_id=str(pk),
            )
            out = StreakFreezeSerializer(freeze)
            return Response(
                {'success': True, 'freeze': out.data},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=True, methods=['post'], url_path='use-freeze')
    def use_freeze(self, request, pk=None):
        """POST /api/grow-together/{id}/use-freeze/ — Use a streak freeze."""
        target_date = None
        date_str = request.data.get('date')
        if date_str:
            from datetime import date as dt_date
            try:
                target_date = dt_date.fromisoformat(date_str)
            except ValueError:
                return Response(
                    {'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            freeze = GrowTogetherService.use_streak_freeze(
                user=request.user,
                collaborative_habit_id=str(pk),
                target_date=target_date,
            )
            out = StreakFreezeSerializer(freeze)
            return Response({'success': True, 'freeze': out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Members ────────────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='members')
    def members(self, request, pk=None):
        """GET /api/grow-together/{id}/members/ — List all members."""
        members = GrowTogetherService.get_members(str(pk))
        serializer = CollaborativeHabitMemberSerializer(members, many=True)
        return Response({'success': True, 'results': serializer.data})

    @action(detail=True, methods=['post'], url_path='leave')
    def leave(self, request, pk=None):
        """POST /api/grow-together/{id}/leave/ — Leave the habit."""
        try:
            GrowTogetherService.leave_habit(request.user, str(pk))
            return Response({'success': True, 'message': 'You have left the habit.'})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=True, methods=['post'], url_path='remove-member')
    def remove_member(self, request, pk=None):
        """POST /api/grow-together/{id}/remove-member/ — Remove a member."""
        user_id = request.data.get('userId')
        if not user_id:
            return Response(
                {'success': False, 'message': 'userId is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            GrowTogetherService.remove_member(request.user, str(pk), int(user_id))
            return Response({'success': True, 'message': 'Member removed.'})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=True, methods=['post'], url_path='join')
    def join(self, request, pk=None):
        """POST /api/grow-together/{id}/join/ — Join a public habit."""
        try:
            member = GrowTogetherService.join_public_habit(request.user, str(pk))
            out = CollaborativeHabitMemberSerializer(member)
            return Response({'success': True, 'member': out.data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Social: Reactions & Comments ───────────────────────────────

    @action(detail=False, methods=['post'],
            url_path=r'progress/(?P<progress_id>[^/.]+)/react')
    def react_to_progress(self, request, progress_id=None):
        """POST /api/grow-together/progress/{id}/react/ — Toggle reaction."""
        reaction_type = request.data.get('reactionType')
        if not reaction_type:
            return Response(
                {'success': False, 'message': 'reactionType is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        valid_types = ['fire', 'clap', 'heart', 'celebrate', 'strong']
        if reaction_type not in valid_types:
            return Response(
                {'success': False, 'message': f'Invalid reactionType. Choose from: {valid_types}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            result = GrowTogetherService.toggle_reaction(
                request.user, str(progress_id), reaction_type,
            )
            return Response({'success': True, **result})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    @action(detail=False, methods=['get', 'post'],
            url_path=r'progress/(?P<progress_id>[^/.]+)/comments')
    def progress_comments(self, request, progress_id=None):
        """GET/POST comments on a progress entry."""
        if request.method == 'GET':
            comments = GrowTogetherService.get_progress_comments(str(progress_id))
            serializer = ProgressCommentSerializer(comments, many=True)
            return Response({'success': True, 'results': serializer.data})

        content = request.data.get('content', '').strip()
        if not content:
            return Response(
                {'success': False, 'message': 'content is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            comment = GrowTogetherService.add_comment(
                request.user, str(progress_id), content,
            )
            out = ProgressCommentSerializer(comment)
            return Response(
                {'success': True, 'comment': out.data},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Feed ───────────────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='feed')
    def habit_feed(self, request, pk=None):
        """GET /api/grow-together/{id}/feed/ — Activity feed for a habit."""
        page = int(request.query_params.get('page', 1))
        limit = min(int(request.query_params.get('limit', 30)), 50)
        logs = GrowTogetherService.get_activity_feed(str(pk), limit, page)
        serializer = HabitActivityLogSerializer(logs, many=True)
        return Response({'success': True, 'page': page, 'results': serializer.data})

    @action(detail=False, methods=['get'], url_path='feed')
    def global_feed(self, request):
        """GET /api/grow-together/feed/ — Global feed across all habits."""
        page = int(request.query_params.get('page', 1))
        limit = min(int(request.query_params.get('limit', 30)), 50)
        logs = GrowTogetherService.get_global_feed(request.user, limit, page)
        serializer = HabitActivityLogSerializer(logs, many=True)
        return Response({'success': True, 'page': page, 'results': serializer.data})

    # ─── Leaderboard ────────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='leaderboard')
    def leaderboard(self, request, pk=None):
        """GET /api/grow-together/{id}/leaderboard/ — Weekly leaderboard."""
        entries = GrowTogetherService.get_weekly_leaderboard(str(pk))
        serializer = WeeklyLeaderboardSerializer(entries, many=True)
        return Response({'success': True, 'results': serializer.data})

    # ─── Milestones ─────────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='milestones')
    def milestones(self, request, pk=None):
        """GET /api/grow-together/{id}/milestones/ — Group milestones."""
        milestones = GroupMilestone.objects.filter(
            collaborative_habit_id=pk,
        ).select_related('achieved_by').order_by('created_at')
        serializer = GroupMilestoneSerializer(milestones, many=True)
        return Response({'success': True, 'results': serializer.data})

    # ─── Analytics ──────────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='analytics')
    def analytics(self, request, pk=None):
        """GET /api/grow-together/{id}/analytics/ — Engagement analytics."""
        try:
            data = GrowTogetherService.get_habit_analytics(str(pk))
            return Response({'success': True, **data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ─── Moderation ─────────────────────────────────────────────────

    @action(detail=True, methods=['post'], url_path='report')
    def report(self, request, pk=None):
        """POST /api/grow-together/{id}/report/ — Report abuse."""
        serializer = AbuseReportCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'errors': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            report = GrowTogetherService.report_abuse(
                user=request.user,
                collaborative_habit_id=str(pk),
                reported_user_id=serializer.validated_data['reportedUserId'],
                reason=serializer.validated_data['reason'],
                description=serializer.validated_data['description'],
            )
            out = AbuseReportSerializer(report)
            return Response(
                {'success': True, 'report': out.data},
                status=status.HTTP_201_CREATED,
            )
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )
