"""
Social / Community Views
========================

DRF ``ViewSet`` classes exposing the complete social API surface.
All endpoints require ``IsAuthenticated`` and return JSON envelopes
with a top-level ``success`` boolean.

ViewSets:
    1. **FeedViewSet** – Community activity feed (list, create, like, comment).
    2. **FriendViewSet** – Friend management (list, search, request, accept,
       reject, remove).
    3. **GroupHabitViewSet** – Group habits (CRUD, join, leave, members,
       leaderboard, discover).
    4. **ReferralViewSet** – Referral link and stats.
    5. **ShareCardViewSet** – Share-card listing and generation.
    6. **PrivacyViewSet** – Per-habit sharing privacy settings.
    7. **JoinedDashboardViewSet** – Aggregated community dashboard.
"""

from __future__ import annotations

from typing import Any, cast

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from django.db.models import Q

from .models import (
    Friendship, FeedPost, PostLike, PostComment,
    GroupHabit, GroupMember, ShareCard,
    SharedHabit, HabitReaction, HabitComment,
)
from .serializers import (
    FeedPostSerializer, FriendSerializer, FriendshipSerializer,
    PostCommentSerializer, GroupDetailSerializer, GroupMemberSerializer,
    SharedHabitSerializer, SharedHabitDetailSerializer,
    HabitReactionSerializer, HabitCommentSerializer,
    GroupChallengeSerializer, GroupChallengeCreateSerializer,
    EncouragementSerializer, EncouragementCreateSerializer,
    ActivityFeedItemSerializer, EnrichedGroupDetailSerializer,
)
from .services import SocialService
from habits.models import Habit
from notifications.services import NotificationCreator


# ═══════════════════════════════════════════════════════════════════════════
#  FEED
# ═══════════════════════════════════════════════════════════════════════════

class FeedViewSet(viewsets.ViewSet):
    """
    Community activity feed.

    Shows posts from the authenticated user, their friends, their groups,
    and any public posts.  Results are paginated (default 20, max 50).
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/feed/ — Return a paginated activity feed."""
        user = request.user
        page = int(request.query_params.get('page', 1))
        per_page = min(int(request.query_params.get('limit', 20)), 50)  # Cap at 50
        offset = (page - 1) * per_page

        # Gather the user's social graph
        friend_ids = SocialService.get_friend_ids(user)
        group_ids = list(GroupMember.objects.filter(
            user=user, is_active=True
        ).values_list('group_id', flat=True))

        # Build a combined query: own posts + friends + groups + public
        posts = FeedPost.objects.filter(
            Q(author_id__in=friend_ids) |
            Q(author=user) |
            Q(group_id__in=group_ids) |
            Q(is_public=True)
        ).select_related(
            'author', 'habit', 'group'
        ).prefetch_related(
            'likes', 'comments__author'
        ).distinct().order_by('-created_at')[offset:offset + per_page]

        serializer = FeedPostSerializer(
            posts, many=True, context={'request': request}
        )
        return Response({
            'success': True,
            'page': page,
            'results': serializer.data,
        })

    def create(self, request):
        """POST /api/social/feed/ — Create a new feed post."""
        content = request.data.get('content', '').strip()
        if not content:
            return Response(
                {'success': False, 'message': 'Content is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        post = FeedPost.objects.create(
            author=request.user,
            post_type=request.data.get('postType', 'motivation'),
            content=content,
            emoji=request.data.get('emoji', ''),
            habit_id=request.data.get('habitId'),
            group_id=request.data.get('groupId'),
            is_public=request.data.get('isPublic', True),
        )
        serializer = FeedPostSerializer(post, context={'request': request})
        return Response(
            {'success': True, 'post': serializer.data},
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        """POST /api/social/feed/{id}/like/ — Toggle like on a post.

        If the user has already liked the post, the like is removed
        (unlike). Otherwise a new like is created. The denormalized
        ``like_count`` on the post is updated atomically.
        """
        try:
            post = FeedPost.objects.get(pk=pk)
        except FeedPost.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Post not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        existing = PostLike.objects.filter(post=post, user=request.user)
        if existing.exists():
            # Unlike — remove the like and decrement counter
            existing.delete()
            post.like_count = max(0, post.like_count - 1)
            post.save(update_fields=['like_count'])
            return Response({'success': True, 'liked': False, 'likeCount': post.like_count})
        else:
            # Like — create the like and increment counter
            PostLike.objects.create(post=post, user=request.user)
            post.like_count += 1
            post.save(update_fields=['like_count'])

            # Notify post author (skip if liking own post)
            if post.author_id != request.user.id:
                NotificationCreator.post_liked(to_user=post.author, from_user=request.user, post=post)

            return Response({'success': True, 'liked': True, 'likeCount': post.like_count})

    @action(detail=True, methods=['get', 'post'])
    def comments(self, request, pk=None):
        """GET/POST /api/social/feed/{id}/comments/ — List or add comments.

        GET returns all comments chronologically.
        POST creates a new comment and increments the denormalized counter.
        """
        try:
            post = FeedPost.objects.get(pk=pk)
        except FeedPost.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Post not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if request.method == 'GET':
            comments = post.comments.select_related('author').order_by('created_at')  # type: ignore[attr-defined]
            serializer = PostCommentSerializer(comments, many=True)
            return Response({'success': True, 'comments': serializer.data})

        content = request.data.get('content', '').strip()
        if not content:
            return Response(
                {'success': False, 'message': 'Content is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        comment = PostComment.objects.create(
            post=post, author=request.user, content=content,
        )
        post.comment_count += 1
        post.save(update_fields=['comment_count'])

        # Notify post author (skip if commenting on own post)
        if post.author_id != request.user.id:
            NotificationCreator.post_commented(
                to_user=post.author, from_user=request.user,
                post=post, comment_preview=content,
            )

        serializer = PostCommentSerializer(comment)
        return Response(
            {'success': True, 'comment': serializer.data},
            status=status.HTTP_201_CREATED,
        )


# ═══════════════════════════════════════════════════════════════════════════
#  FRIENDS
# ═══════════════════════════════════════════════════════════════════════════

class FriendViewSet(viewsets.ViewSet):
    """
    Friend management endpoints.

    Supports listing confirmed friends, searching for users, sending /
    accepting / rejecting friend requests, and removing friendships.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/friends/ — List all confirmed friends."""
        friends = SocialService.get_friends(request.user)
        return Response({'success': True, 'friends': friends})

    @action(detail=False, methods=['get'])
    def search(self, request):
        """GET /api/social/friends/search/?q=... — Search users by name or email.

        Returns up to 20 matches with their current relationship status
        relative to the requesting user (none / pending / accepted / incoming).
        Minimum query length is 2 characters.
        """
        query = request.query_params.get('q', '').strip()
        if len(query) < 2:
            return Response({'success': True, 'users': []})

        from authentication.models import User
        users = User.objects.filter(
            Q(name__icontains=query) | Q(email__icontains=query),
            is_active=True,
        ).exclude(id=request.user.id)[:20]  # Exclude self, limit results

        # Pre-fetch existing relationship data for efficient status look-up
        sent_map = dict(Friendship.objects.filter(
            from_user=request.user
        ).values_list('to_user_id', 'status'))
        received_map = dict(Friendship.objects.filter(
            to_user=request.user
        ).values_list('from_user_id', 'status'))

        results = []
        for u in users:
            # Determine the relationship type for each search result
            rel = 'none'
            if u.id in sent_map:  # type: ignore[attr-defined]
                rel = sent_map[u.id]  # type: ignore[attr-defined]
            elif u.id in received_map:  # type: ignore[attr-defined]
                s = received_map[u.id]  # type: ignore[attr-defined]
                rel = 'incoming' if s == 'pending' else s
            results.append({
                'id': u.id,  # type: ignore[attr-defined]
                'name': u.name,
                'email': u.email,
                'profileImage': u.profile_image,
                'currentStreak': u.current_streak,
                'relationship': rel,
            })
        return Response({'success': True, 'users': results})

    @action(detail=False, methods=['get'])
    def requests(self, request):
        """GET /api/social/friends/requests/ — Pending incoming and outgoing requests."""
        incoming = Friendship.objects.filter(
            to_user=request.user, status='pending'
        ).select_related('from_user')
        outgoing = Friendship.objects.filter(
            from_user=request.user, status='pending'
        ).select_related('to_user')

        def user_data(u):
            return {
                'id': u.id, 'name': u.name,
                'email': u.email, 'profileImage': u.profile_image,
                'currentStreak': u.current_streak,
            }

        return Response({
            'success': True,
            'incoming': [{'friendshipId': f.id, 'user': user_data(f.from_user), 'createdAt': f.created_at.isoformat()} for f in incoming],  # type: ignore[attr-defined]
            'outgoing': [{'friendshipId': f.id, 'user': user_data(f.to_user), 'createdAt': f.created_at.isoformat()} for f in outgoing],  # type: ignore[attr-defined]
        })

    @action(detail=False, methods=['post'], url_path='send-request')
    def send_request(self, request):
        """POST /api/social/friends/send-request/ — Send a friend request.

        Validates the target user, checks for existing relationships,
        and creates or re-activates a pending ``Friendship``.
        """
        user_id = request.data.get('userId')
        if not user_id:
            return Response({'success': False, 'message': 'userId is required'}, status=status.HTTP_400_BAD_REQUEST)
        if int(user_id) == request.user.id:
            return Response({'success': False, 'message': 'Cannot add yourself'}, status=status.HTTP_400_BAD_REQUEST)

        # Check for any prior relationship between the two users
        existing = Friendship.objects.filter(
            Q(from_user=request.user, to_user_id=user_id) |
            Q(from_user_id=user_id, to_user=request.user)
        ).first()

        if existing:
            if existing.status == 'accepted':
                return Response({'success': False, 'message': 'Already friends'})
            if existing.status == 'pending':
                return Response({'success': False, 'message': 'Request already pending'})
            # Re-activate a previously rejected request
            existing.status = 'pending'
            existing.from_user = request.user
            existing.to_user_id = user_id  # type: ignore[attr-defined]
            existing.save()

            # Create notification for re-activated request
            from authentication.models import User
            try:
                to_user = User.objects.get(id=user_id)
                NotificationCreator.friend_request(to_user=to_user, from_user=request.user)
            except User.DoesNotExist:
                pass

            return Response({'success': True, 'message': 'Friend request sent'})

        Friendship.objects.create(from_user=request.user, to_user_id=user_id, status='pending')

        # Create notification for the recipient
        from authentication.models import User
        try:
            to_user = User.objects.get(id=user_id)
            NotificationCreator.friend_request(to_user=to_user, from_user=request.user)
        except User.DoesNotExist:
            pass

        return Response({'success': True, 'message': 'Friend request sent'}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='accept-request')
    def accept_request(self, request):
        """POST /api/social/friends/accept-request/ — Accept a pending friend request."""
        fid = request.data.get('friendshipId')
        try:
            friendship = Friendship.objects.get(id=fid, to_user=request.user, status='pending')
        except Friendship.DoesNotExist:
            return Response({'success': False, 'message': 'Request not found'}, status=status.HTTP_404_NOT_FOUND)
        friendship.status = 'accepted'
        friendship.save()

        # Notify the original sender that their request was accepted
        NotificationCreator.friend_accepted(to_user=friendship.from_user, from_user=request.user)

        return Response({'success': True, 'message': 'Friend request accepted'})

    @action(detail=False, methods=['post'], url_path='reject-request')
    def reject_request(self, request):
        """POST /api/social/friends/reject-request/ — Reject a pending friend request."""
        fid = request.data.get('friendshipId')
        try:
            friendship = Friendship.objects.get(id=fid, to_user=request.user, status='pending')
        except Friendship.DoesNotExist:
            return Response({'success': False, 'message': 'Request not found'}, status=status.HTTP_404_NOT_FOUND)
        friendship.status = 'rejected'
        friendship.save()
        return Response({'success': True, 'message': 'Request rejected'})

    @action(detail=False, methods=['post'])
    def remove(self, request):
        """POST /api/social/friends/remove/ — Remove an existing friendship."""
        user_id = request.data.get('userId')
        deleted = Friendship.objects.filter(
            Q(from_user=request.user, to_user_id=user_id) |
            Q(from_user_id=user_id, to_user=request.user),
            status='accepted',
        ).delete()
        if deleted[0] > 0:
            return Response({'success': True, 'message': 'Friend removed'})
        return Response({'success': False, 'message': 'Friendship not found'}, status=status.HTTP_404_NOT_FOUND)


# ═══════════════════════════════════════════════════════════════════════════
#  GROUPS
# ═══════════════════════════════════════════════════════════════════════════

class GroupHabitViewSet(viewsets.ViewSet):
    """
    Group habit management endpoints.

    Supports listing user's groups, creating groups, joining via invite
    code, leaving, viewing members, leaderboard ranking, and discovering
    public groups.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/groups/ — List groups the user belongs to."""
        memberships = GroupMember.objects.filter(
            user=request.user, is_active=True
        ).select_related('group', 'group__creator')
        groups = [m.group for m in memberships]
        serializer = GroupDetailSerializer(groups, many=True, context={'request': request})
        return Response({'success': True, 'groups': serializer.data})

    def create(self, request):
        """POST /api/social/groups/ — Create a new group habit."""
        name = request.data.get('name', '').strip()
        if not name:
            return Response({'success': False, 'message': 'Group name is required'}, status=status.HTTP_400_BAD_REQUEST)
        group = SocialService.create_group_habit(
            request.user, name=name,
            description=request.data.get('description', ''),
            habit_template=request.data.get('habitTemplate'),
        )
        serializer = GroupDetailSerializer(group, context={'request': request})
        return Response({'success': True, 'group': serializer.data}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def join(self, request):
        """POST /api/social/groups/join/ — Join a group using an invite code."""
        invite_code = request.data.get('inviteCode')
        if not invite_code:
            return Response({'success': False, 'message': 'Invite code is required'}, status=status.HTTP_400_BAD_REQUEST)
        result = SocialService.join_group(request.user, invite_code)
        if result['success']:
            serializer = GroupDetailSerializer(result['group'], context={'request': request})

            # Notify group creator that someone joined
            group = result['group']
            if group.creator_id != request.user.id:
                NotificationCreator.group_join(
                    to_user=group.creator,
                    member_user=request.user,
                    group=group,
                )

            return Response({'success': True, 'group': serializer.data})
        return Response({'success': False, 'message': result['message']}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        """POST /api/social/groups/{id}/leave/ — Leave a group (soft-deactivate)."""
        updated = GroupMember.objects.filter(group_id=pk, user=request.user, is_active=True).update(is_active=False)
        if updated:
            return Response({'success': True, 'message': 'Left group'})
        return Response({'success': False, 'message': 'Not a member'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """GET /api/social/groups/{id}/members/ — List active group members."""
        members = GroupMember.objects.filter(group_id=pk, is_active=True).select_related('user')
        data = [{'id': m.user.id, 'name': m.user.name, 'role': m.role, 'currentStreak': m.user.current_streak, 'joinedAt': m.joined_at.isoformat()} for m in members]
        return Response({'success': True, 'members': data})

    @action(detail=True, methods=['get'])
    def leaderboard(self, request, pk=None):
        """GET /api/social/groups/{id}/leaderboard/ — Group completion ranking."""
        leaderboard = SocialService.get_group_leaderboard(pk)
        return Response({'success': True, 'leaderboard': leaderboard})

    @action(detail=False, methods=['get'])
    def discover(self, request):
        """GET /api/social/groups/discover/ — Browse groups the user hasn't joined."""
        my_groups = list(GroupMember.objects.filter(user=request.user, is_active=True).values_list('group_id', flat=True))
        groups = GroupHabit.objects.filter(is_active=True).exclude(id__in=my_groups).order_by('-created_at')[:20]
        serializer = GroupDetailSerializer(groups, many=True, context={'request': request})
        return Response({'success': True, 'groups': serializer.data})

    # ── Group Challenges ─────────────────────────────────────────────────

    @action(detail=True, methods=['get', 'post'])
    def challenges(self, request, pk=None):
        """
        GET  /api/social/groups/{id}/challenges/ — list group challenges.
        POST /api/social/groups/{id}/challenges/ — create a new challenge.
        """
        if pk is None:
            return Response(
                {'success': False, 'message': 'Group ID is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if request.method == 'GET':
            data = SocialService.get_group_challenges(pk)
            return Response({'success': True, 'challenges': data})

        # POST — create challenge
        ser = GroupChallengeCreateSerializer(data=request.data)
        if not ser.is_valid():
            return Response(
                {'success': False, 'errors': ser.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        vd = cast(dict[str, Any], ser.validated_data)
        try:
            challenge = SocialService.create_group_challenge(
                user=request.user,
                group_id=int(pk),
                title=vd['title'],
                description=vd.get('description', ''),
                target_type=vd['targetType'],
                target_value=vd['targetValue'],
                start_date=vd.get('startDate'),
                end_date=vd.get('endDate'),
                xp_reward=vd.get('xpReward', 50),
                coin_reward=vd.get('coinReward', 10),
            )
            return Response({
                'success': True,
                'message': 'Challenge created!',
                'challengeId': challenge.id,
            }, status=status.HTTP_201_CREATED)
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ── Share Habit to Group ─────────────────────────────────────────────

    @action(detail=True, methods=['post'], url_path='share-habit')
    def share_habit_to_group(self, request, pk=None):
        """
        POST /api/social/groups/{id}/share-habit/

        Share one of your habits with the group.
        Expects: { "habitId": 42 }
        """
        if pk is None:
            return Response(
                {'success': False, 'message': 'Group ID is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        habit_id = request.data.get('habitId')
        if not habit_id:
            return Response(
                {'success': False, 'message': 'habitId is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            result = SocialService.share_habit_to_group(
                user=request.user,
                habit_id=int(habit_id),
                group_id=int(pk),
            )
            return Response({'success': True, **result})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # ── Enriched Group Detail ────────────────────────────────────────────

    @action(detail=True, methods=['get'], url_path='detail')
    def enriched_detail(self, request, pk=None):
        """
        GET /api/social/groups/{id}/detail/

        Rich group info with challenges, leaderboard, stats and member list.
        """
        if pk is None:
            return Response(
                {'success': False, 'message': 'Group ID is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            data = SocialService.get_group_detail(int(pk), request.user)
            return Response({'success': True, 'data': data})
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_404_NOT_FOUND,
            )


# ═══════════════════════════════════════════════════════════════════════════
#  REFERRALS
# ═══════════════════════════════════════════════════════════════════════════

class ReferralViewSet(viewsets.ViewSet):
    """
    Referral system endpoints.

    Provides the user's referral link and tracks successful referrals.
    """

    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='my-link')
    def my_link(self, request):
        """GET /api/social/referrals/my-link/ — Get or create the user's referral link."""
        link = SocialService.create_referral_link(request.user)
        from .models import Referral
        total_joined = Referral.objects.filter(referrer=request.user).count()
        return Response({
            'success': True,
            'referral': {
                'code': link.code,
                'totalInvited': link.uses_count,
                'totalJoined': total_joined,
                'maxUses': link.max_uses,
                'isActive': link.is_active,
                'expiresAt': link.expires_at.isoformat() if link.expires_at else None,
            }
        })

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """GET /api/social/referrals/stats/ — List successful referrals."""
        from .models import Referral
        referrals = Referral.objects.filter(referrer=request.user).select_related('referred_user')
        return Response({
            'success': True,
            'totalReferrals': referrals.count(),
            'referrals': [{'userName': r.referred_user.name, 'joinedAt': r.created_at.isoformat()} for r in referrals[:20]],
        })


# ═══════════════════════════════════════════════════════════════════════════
#  SHARE CARDS
# ═══════════════════════════════════════════════════════════════════════════

class ShareCardViewSet(viewsets.ViewSet):
    """
    Share-card endpoints.

    Lists existing cards and provides on-demand generation for daily
    and weekly summary cards.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/share-cards/ — List the user's share cards."""
        share_type = request.query_params.get('type')
        limit = min(int(request.query_params.get('limit', 20)), 50)
        cards = SocialService.get_user_share_cards(request.user, share_type=share_type, limit=limit)
        return Response({
            'success': True,
            'cards': [{
                'id': c.id, 'shareType': c.share_type, 'title': c.title,
                'subtitle': c.subtitle, 'cardData': c.card_data,
                'habitsCompleted': c.habits_completed, 'totalHabits': c.total_habits,
                'streakCount': c.streak_count, 'completionRate': c.completion_rate,
                'shareToken': str(c.share_token),
                'periodStart': c.period_start.isoformat(), 'periodEnd': c.period_end.isoformat(),
                'createdAt': c.created_at.isoformat(),
            } for c in cards],
        })

    @action(detail=False, methods=['post'], url_path='generate-daily')
    def generate_daily(self, request):
        """POST /api/social/share-cards/generate-daily/ — Generate a daily summary card."""
        card = SocialService.generate_daily_share_card(request.user)
        return Response({'success': True, 'card': {'id': card.id, 'shareType': card.share_type, 'title': card.title, 'shareToken': str(card.share_token)}}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='generate-weekly')
    def generate_weekly(self, request):
        """POST /api/social/share-cards/generate-weekly/ — Generate a weekly summary card."""
        card = SocialService.generate_weekly_share_card(request.user)
        return Response({'success': True, 'card': {'id': card.id, 'shareType': card.share_type, 'title': card.title, 'shareToken': str(card.share_token)}}, status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════
#  PRIVACY
# ═══════════════════════════════════════════════════════════════════════════

class PrivacyViewSet(viewsets.ViewSet):
    """
    Per-habit sharing privacy settings.

    Allows users to control which habits appear in share cards,
    streak shares, and group visibility.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/privacy/ — List privacy settings for all habits."""
        data = SocialService.get_privacy_settings(request.user)
        return Response({'success': True, 'privacySettings': data})

    @action(detail=False, methods=['put', 'patch'], url_path='update')
    def update_privacy(self, request):
        """PUT/PATCH /api/social/privacy/update/ — Update privacy for a single habit.

        Expects ``habitId`` plus one or more of ``allowInSummary``,
        ``allowStreakShare``, ``allowInGroup``, ``showDetails``.
        """
        habit_id = request.data.get('habitId')
        if not habit_id:
            return Response({'success': False, 'message': 'habitId is required'}, status=status.HTTP_400_BAD_REQUEST)

        # Map camelCase frontend keys to snake_case model field names
        mapping = {'allowInSummary': 'allow_in_summary', 'allowStreakShare': 'allow_streak_share', 'allowInGroup': 'allow_in_group', 'showDetails': 'show_details'}
        kwargs = {mapping[k]: v for k, v in request.data.items() if k in mapping}
        SocialService.update_privacy_setting(request.user, habit_id, **kwargs)
        return Response({'success': True, 'message': 'Privacy updated'})


# ═══════════════════════════════════════════════════════════════════════════
#  JOINED DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════

class JoinedDashboardViewSet(viewsets.ViewSet):
    """
    Aggregated community dashboard.

    Returns group memberships, friend count, the user's community streak,
    and recent friend activity in a single response for the *Community*
    tab home screen.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/joined/ — Return the aggregated community dashboard."""
        user = request.user
        # Fetch user's active group memberships with related data
        memberships = GroupMember.objects.filter(user=user, is_active=True).select_related('group', 'group__creator')
        groups = [m.group for m in memberships]
        group_data = GroupDetailSerializer(groups, many=True, context={'request': request}).data

        # Gather recent activity from all friends
        friend_ids = SocialService.get_friend_ids(user)
        recent_activity = FeedPost.objects.filter(
            author_id__in=friend_ids
        ).select_related('author', 'habit', 'group').prefetch_related(
            'likes', 'comments__author'
        ).order_by('-created_at')[:10]
        activity_data = FeedPostSerializer(recent_activity, many=True, context={'request': request}).data

        return Response({
            'success': True,
            'data': {
                'totalGroups': len(groups),
                'totalFriends': len(friend_ids),
                'communityStreak': user.current_streak,
                'groups': group_data,
                'recentFriendActivity': activity_data,
            }
        })


# ═══════════════════════════════════════════════════════════════════════════
#  SHARED HABITS
# ═══════════════════════════════════════════════════════════════════════════

class SharedHabitViewSet(viewsets.ViewSet):
    """
    Habit sharing endpoints — share, unshare, react, comment, and join.

    All actions are scoped to the authenticated user and enforce friendship
    checks via ``SocialService``.
    """

    permission_classes = [IsAuthenticated]

    # --- Share a habit with friends ------------------------------------------

    @action(detail=True, methods=['post'])
    def share(self, request, pk=None):
        """
        POST /api/social/shared-habits/{id}/share/

        Share a habit with one or more friends.  Expects:
            { "friendIds": [1, 2], "canComment": true, "canReact": true }
        """
        user = request.user
        friend_ids = request.data.get('friendIds', [])
        can_comment = request.data.get('canComment', True)
        can_react = request.data.get('canReact', True)

        if not friend_ids:
            return Response({
                'success': False,
                'message': 'friendIds is required.',
            }, status=status.HTTP_400_BAD_REQUEST)

        if pk is None:
            return Response({
                'success': False, 'message': 'Habit ID is required.',
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            result = SocialService.share_habit(
                user=user,
                habit_id=int(pk),
                friend_ids=friend_ids,
                can_comment=can_comment,
                can_react=can_react,
            )
            return Response({'success': True, **result})
        except ValueError as e:
            return Response({
                'success': False, 'message': str(e),
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False, 'message': str(e),
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # --- Remove sharing ------------------------------------------------------

    @action(detail=True, methods=['post'])
    def unshare(self, request, pk=None):
        """
        POST /api/social/shared-habits/{id}/unshare/

        Stop sharing a habit with a specific friend.
        Expects: { "friendId": 5 }
        """
        user = request.user
        friend_id = request.data.get('friendId')

        if not friend_id:
            return Response({
                'success': False, 'message': 'friendId is required.',
            }, status=status.HTTP_400_BAD_REQUEST)

        if pk is None:
            return Response({
                'success': False, 'message': 'Habit ID is required.',
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            SocialService.unshare_habit(
                user=user, habit_id=int(pk), friend_id=int(friend_id),
            )
            return Response({'success': True, 'message': 'Habit unshared.'})
        except ValueError as e:
            return Response({
                'success': False, 'message': str(e),
            }, status=status.HTTP_400_BAD_REQUEST)

    # --- Update visibility ---------------------------------------------------

    @action(detail=True, methods=['post'])
    def visibility(self, request, pk=None):
        """
        POST /api/social/shared-habits/{id}/visibility/

        Update the visibility level of a habit.
        Expects: { "visibility": "friends_only" }
        """
        user = request.user
        new_visibility = request.data.get('visibility')

        valid_choices = ['private', 'friends_only', 'public']
        if new_visibility not in valid_choices:
            return Response({
                'success': False,
                'message': f'visibility must be one of {valid_choices}.',
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            habit = Habit.objects.get(pk=pk, user=user, is_deleted=False)
        except Habit.DoesNotExist:
            return Response({
                'success': False, 'message': 'Habit not found.',
            }, status=status.HTTP_404_NOT_FOUND)

        habit.visibility = new_visibility
        habit.save(update_fields=['visibility'])

        return Response({
            'success': True,
            'message': 'Visibility updated.',
            'visibility': new_visibility,
        })

    # --- Habits shared with me -----------------------------------------------

    @action(detail=False, methods=['get'], url_path='shared-with-me')
    def shared_with_me(self, request):
        """
        GET /api/social/shared-habits/shared-with-me/

        List all habits that have been shared with the authenticated user.
        """
        user = request.user
        shared = SocialService.get_shared_feed(user)
        return Response({'success': True, 'data': shared})

    # --- Reactions ------------------------------------------------------------

    @action(detail=True, methods=['post'])
    def react(self, request, pk=None):
        """
        POST /api/social/shared-habits/{id}/react/

        Toggle an emoji reaction on a habit.  If the same reaction already
        exists it is removed (un-react); otherwise a new reaction is created.
        Expects: { "reactionType": "fire" }
        """
        user = request.user
        reaction_type = request.data.get('reactionType', 'like')

        valid_types = ['like', 'encourage', 'celebrate', 'fire', 'clap']
        if reaction_type not in valid_types:
            return Response({
                'success': False,
                'message': f'reactionType must be one of {valid_types}.',
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            habit = Habit.objects.get(pk=pk, is_deleted=False)
        except Habit.DoesNotExist:
            return Response({
                'success': False, 'message': 'Habit not found.',
            }, status=status.HTTP_404_NOT_FOUND)

        # Toggle reaction
        existing = HabitReaction.objects.filter(
            habit=habit, user=user, reaction_type=reaction_type,
        ).first()

        if existing:
            existing.delete()
            return Response({
                'success': True, 'action': 'removed',
                'reactionType': reaction_type,
            })

        HabitReaction.objects.create(
            habit=habit, user=user, reaction_type=reaction_type,
        )

        # Notify the habit owner
        if habit.user != user:
            from notifications.services import NotificationCreator
            NotificationCreator.habit_reaction_received(
                to_user=habit.user, from_user=user,
                habit=habit, reaction_type=reaction_type,
            )

        return Response({
            'success': True, 'action': 'added',
            'reactionType': reaction_type,
        }, status=status.HTTP_201_CREATED)

    # --- Comments -------------------------------------------------------------

    @action(detail=True, methods=['get', 'post'])
    def comments(self, request, pk=None):
        """
        GET  /api/social/shared-habits/{id}/comments/ — list comments.
        POST /api/social/shared-habits/{id}/comments/ — add a comment.
        """
        try:
            habit = Habit.objects.get(pk=pk, is_deleted=False)
        except Habit.DoesNotExist:
            return Response({
                'success': False, 'message': 'Habit not found.',
            }, status=status.HTTP_404_NOT_FOUND)

        if request.method == 'GET':
            comments = HabitComment.objects.filter(
                habit=habit,
            ).select_related('author').order_by('-created_at')[:50]
            data = HabitCommentSerializer(comments, many=True).data
            return Response({'success': True, 'comments': data})

        # POST — add comment
        content = request.data.get('content', '').strip()
        if not content:
            return Response({
                'success': False, 'message': 'content is required.',
            }, status=status.HTTP_400_BAD_REQUEST)

        comment = HabitComment.objects.create(
            habit=habit, author=request.user, content=content[:300],
        )

        # Notify the habit owner
        if habit.user != request.user:
            from notifications.services import NotificationCreator
            NotificationCreator.habit_comment_received(
                to_user=habit.user, from_user=request.user,
                habit=habit, comment_preview=content[:60],
            )

        return Response({
            'success': True,
            'comment': HabitCommentSerializer(comment).data,
        }, status=status.HTTP_201_CREATED)

    # --- Join (clone) a shared habit -----------------------------------------

    @action(detail=True, methods=['post'], url_path='join-habit')
    def join_habit(self, request, pk=None):
        """
        POST /api/social/shared-habits/{id}/join-habit/

        Clone a shared habit into the authenticated user's own habit list.
        """
        user = request.user

        try:
            source = Habit.objects.get(pk=pk, is_deleted=False)
        except Habit.DoesNotExist:
            return Response({
                'success': False, 'message': 'Habit not found.',
            }, status=status.HTTP_404_NOT_FOUND)

        if source.user == user:
            return Response({
                'success': False, 'message': 'Cannot join your own habit.',
            }, status=status.HTTP_400_BAD_REQUEST)

        # Clone the habit
        new_habit = Habit(
            user=user,
            title=source.title,
            description=source.description or '',
            category_name=source.category_name,
            icon_code=source.icon_code,
            color_value=source.color_value,
            frequency=source.frequency,
            custom_days=source.custom_days,
            target_count=source.target_count,
            time=source.time,
            visibility='private',
        )
        new_habit.save()

        return Response({
            'success': True,
            'message': f'Habit "{source.title}" joined!',
            'habitId': new_habit.id,
        }, status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════
#  ENCOURAGEMENT
# ═══════════════════════════════════════════════════════════════════════════

class EncouragementViewSet(viewsets.ViewSet):
    """
    Send and receive encouragement nudges between friends.

    Encouragements are lightweight motivational messages that trigger
    push notifications and appear in the activity feed.
    """

    permission_classes = [IsAuthenticated]

    def create(self, request):
        """
        POST /api/social/encouragements/

        Send encouragement to a friend.
        Expects: { "toUserId": 5, "encourageType": "cheer", "message": "...", "habitId": null }
        """
        ser = EncouragementCreateSerializer(data=request.data)
        if not ser.is_valid():
            return Response(
                {'success': False, 'errors': ser.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        vd = cast(dict[str, Any], ser.validated_data)
        try:
            enc = SocialService.send_encouragement(
                from_user=request.user,
                to_user_id=vd['toUserId'],
                encourage_type=vd.get('encourageType', 'cheer'),
                message=vd.get('message', ''),
                habit_id=vd.get('habitId'),
            )
            return Response({
                'success': True,
                'message': 'Encouragement sent!',
                'id': enc.pk,
            }, status=status.HTTP_201_CREATED)
        except ValueError as e:
            return Response(
                {'success': False, 'message': str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

    def list(self, request):
        """
        GET /api/social/encouragements/

        List encouragements received by the current user.
        """
        from .models import Encouragement
        encouragements = Encouragement.objects.filter(
            to_user=request.user,
        ).select_related(
            'from_user', 'to_user', 'habit',
        ).order_by('-created_at')[:50]
        data = EncouragementSerializer(encouragements, many=True).data
        return Response({'success': True, 'encouragements': data})


# ═══════════════════════════════════════════════════════════════════════════
#  ACTIVITY FEED
# ═══════════════════════════════════════════════════════════════════════════

class ActivityFeedViewSet(viewsets.ViewSet):
    """
    Unified activity feed combining encouragements, reactions, comments,
    and group challenge updates into a single chronological stream.
    """

    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        GET /api/social/activity/

        Return the unified activity feed for the current user.
        """
        limit = min(int(request.query_params.get('limit', 30)), 100)
        items = SocialService.get_activity_feed(request.user, limit=limit)
        serializer = ActivityFeedItemSerializer(items, many=True)
        return Response({'success': True, 'activity': serializer.data})
