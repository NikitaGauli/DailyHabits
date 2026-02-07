"""
Social / Community Views
Complete API for feed, friends, groups, referrals, share-cards, privacy, joined
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from django.db.models import Q

from .models import (
    Friendship, FeedPost, PostLike, PostComment,
    GroupHabit, GroupMember, ShareCard,
)
from .serializers import (
    FeedPostSerializer, FriendSerializer, FriendshipSerializer,
    PostCommentSerializer, GroupDetailSerializer, GroupMemberSerializer,
)
from .services import SocialService


# ═══════════════════════════════════════════════════════════════════════════
#  FEED
# ═══════════════════════════════════════════════════════════════════════════

class FeedViewSet(viewsets.ViewSet):
    """Community activity feed — paginated, friends + groups only."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/feed/"""
        user = request.user
        page = int(request.query_params.get('page', 1))
        per_page = min(int(request.query_params.get('limit', 20)), 50)
        offset = (page - 1) * per_page

        friend_ids = SocialService.get_friend_ids(user)
        group_ids = list(GroupMember.objects.filter(
            user=user, is_active=True
        ).values_list('group_id', flat=True))

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
        """POST /api/social/feed/"""
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
        """POST /api/social/feed/{id}/like/"""
        try:
            post = FeedPost.objects.get(pk=pk)
        except FeedPost.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Post not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        existing = PostLike.objects.filter(post=post, user=request.user)
        if existing.exists():
            existing.delete()
            post.like_count = max(0, post.like_count - 1)
            post.save(update_fields=['like_count'])
            return Response({'success': True, 'liked': False, 'likeCount': post.like_count})
        else:
            PostLike.objects.create(post=post, user=request.user)
            post.like_count += 1
            post.save(update_fields=['like_count'])
            return Response({'success': True, 'liked': True, 'likeCount': post.like_count})

    @action(detail=True, methods=['get', 'post'])
    def comments(self, request, pk=None):
        """GET/POST /api/social/feed/{id}/comments/"""
        try:
            post = FeedPost.objects.get(pk=pk)
        except FeedPost.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Post not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if request.method == 'GET':
            comments = post.comments.select_related('author').order_by('created_at')
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
        serializer = PostCommentSerializer(comment)
        return Response(
            {'success': True, 'comment': serializer.data},
            status=status.HTTP_201_CREATED,
        )


# ═══════════════════════════════════════════════════════════════════════════
#  FRIENDS
# ═══════════════════════════════════════════════════════════════════════════

class FriendViewSet(viewsets.ViewSet):
    """Friend management — list, search, request, accept, remove."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """GET /api/social/friends/"""
        friends = SocialService.get_friends(request.user)
        return Response({'success': True, 'friends': friends})

    @action(detail=False, methods=['get'])
    def search(self, request):
        """GET /api/social/friends/search/?q=..."""
        query = request.query_params.get('q', '').strip()
        if len(query) < 2:
            return Response({'success': True, 'users': []})

        from authentication.models import User
        users = User.objects.filter(
            Q(name__icontains=query) | Q(email__icontains=query),
            is_active=True,
        ).exclude(id=request.user.id)[:20]

        sent_map = dict(Friendship.objects.filter(
            from_user=request.user
        ).values_list('to_user_id', 'status'))
        received_map = dict(Friendship.objects.filter(
            to_user=request.user
        ).values_list('from_user_id', 'status'))

        results = []
        for u in users:
            rel = 'none'
            if u.id in sent_map:
                rel = sent_map[u.id]
            elif u.id in received_map:
                s = received_map[u.id]
                rel = 'incoming' if s == 'pending' else s
            results.append({
                'id': u.id,
                'name': u.name,
                'email': u.email,
                'profileImage': u.profile_image,
                'currentStreak': u.current_streak,
                'relationship': rel,
            })
        return Response({'success': True, 'users': results})

    @action(detail=False, methods=['get'])
    def requests(self, request):
        """GET /api/social/friends/requests/"""
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
            'incoming': [{'friendshipId': f.id, 'user': user_data(f.from_user), 'createdAt': f.created_at.isoformat()} for f in incoming],
            'outgoing': [{'friendshipId': f.id, 'user': user_data(f.to_user), 'createdAt': f.created_at.isoformat()} for f in outgoing],
        })

    @action(detail=False, methods=['post'], url_path='send-request')
    def send_request(self, request):
        """POST /api/social/friends/send-request/ {userId}"""
        user_id = request.data.get('userId')
        if not user_id:
            return Response({'success': False, 'message': 'userId is required'}, status=status.HTTP_400_BAD_REQUEST)
        if int(user_id) == request.user.id:
            return Response({'success': False, 'message': 'Cannot add yourself'}, status=status.HTTP_400_BAD_REQUEST)

        existing = Friendship.objects.filter(
            Q(from_user=request.user, to_user_id=user_id) |
            Q(from_user_id=user_id, to_user=request.user)
        ).first()

        if existing:
            if existing.status == 'accepted':
                return Response({'success': False, 'message': 'Already friends'})
            if existing.status == 'pending':
                return Response({'success': False, 'message': 'Request already pending'})
            existing.status = 'pending'
            existing.from_user = request.user
            existing.to_user_id = user_id
            existing.save()
            return Response({'success': True, 'message': 'Friend request sent'})

        Friendship.objects.create(from_user=request.user, to_user_id=user_id, status='pending')
        return Response({'success': True, 'message': 'Friend request sent'}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='accept-request')
    def accept_request(self, request):
        """POST /api/social/friends/accept-request/ {friendshipId}"""
        fid = request.data.get('friendshipId')
        try:
            friendship = Friendship.objects.get(id=fid, to_user=request.user, status='pending')
        except Friendship.DoesNotExist:
            return Response({'success': False, 'message': 'Request not found'}, status=status.HTTP_404_NOT_FOUND)
        friendship.status = 'accepted'
        friendship.save()
        return Response({'success': True, 'message': 'Friend request accepted'})

    @action(detail=False, methods=['post'], url_path='reject-request')
    def reject_request(self, request):
        """POST /api/social/friends/reject-request/ {friendshipId}"""
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
        """POST /api/social/friends/remove/ {userId}"""
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
    """Group habits — CRUD, join, leave, members, leaderboard, discover."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        memberships = GroupMember.objects.filter(
            user=request.user, is_active=True
        ).select_related('group', 'group__creator')
        groups = [m.group for m in memberships]
        serializer = GroupDetailSerializer(groups, many=True, context={'request': request})
        return Response({'success': True, 'groups': serializer.data})

    def create(self, request):
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
        invite_code = request.data.get('inviteCode')
        if not invite_code:
            return Response({'success': False, 'message': 'Invite code is required'}, status=status.HTTP_400_BAD_REQUEST)
        result = SocialService.join_group(request.user, invite_code)
        if result['success']:
            serializer = GroupDetailSerializer(result['group'], context={'request': request})
            return Response({'success': True, 'group': serializer.data})
        return Response({'success': False, 'message': result['message']}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        updated = GroupMember.objects.filter(group_id=pk, user=request.user, is_active=True).update(is_active=False)
        if updated:
            return Response({'success': True, 'message': 'Left group'})
        return Response({'success': False, 'message': 'Not a member'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        members = GroupMember.objects.filter(group_id=pk, is_active=True).select_related('user')
        data = [{'id': m.user.id, 'name': m.user.name, 'role': m.role, 'currentStreak': m.user.current_streak, 'joinedAt': m.joined_at.isoformat()} for m in members]
        return Response({'success': True, 'members': data})

    @action(detail=True, methods=['get'])
    def leaderboard(self, request, pk=None):
        leaderboard = SocialService.get_group_leaderboard(pk)
        return Response({'success': True, 'leaderboard': leaderboard})

    @action(detail=False, methods=['get'])
    def discover(self, request):
        my_groups = list(GroupMember.objects.filter(user=request.user, is_active=True).values_list('group_id', flat=True))
        groups = GroupHabit.objects.filter(is_active=True).exclude(id__in=my_groups).order_by('-created_at')[:20]
        serializer = GroupDetailSerializer(groups, many=True, context={'request': request})
        return Response({'success': True, 'groups': serializer.data})


# ═══════════════════════════════════════════════════════════════════════════
#  REFERRALS
# ═══════════════════════════════════════════════════════════════════════════

class ReferralViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='my-link')
    def my_link(self, request):
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
    permission_classes = [IsAuthenticated]

    def list(self, request):
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
        card = SocialService.generate_daily_share_card(request.user)
        return Response({'success': True, 'card': {'id': card.id, 'shareType': card.share_type, 'title': card.title, 'shareToken': str(card.share_token)}}, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='generate-weekly')
    def generate_weekly(self, request):
        card = SocialService.generate_weekly_share_card(request.user)
        return Response({'success': True, 'card': {'id': card.id, 'shareType': card.share_type, 'title': card.title, 'shareToken': str(card.share_token)}}, status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════════════
#  PRIVACY
# ═══════════════════════════════════════════════════════════════════════════

class PrivacyViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        data = SocialService.get_privacy_settings(request.user)
        return Response({'success': True, 'privacySettings': data})

    @action(detail=False, methods=['put', 'patch'], url_path='update')
    def update_privacy(self, request):
        habit_id = request.data.get('habitId')
        if not habit_id:
            return Response({'success': False, 'message': 'habitId is required'}, status=status.HTTP_400_BAD_REQUEST)
        mapping = {'allowInSummary': 'allow_in_summary', 'allowStreakShare': 'allow_streak_share', 'allowInGroup': 'allow_in_group', 'showDetails': 'show_details'}
        kwargs = {mapping[k]: v for k, v in request.data.items() if k in mapping}
        SocialService.update_privacy_setting(request.user, habit_id, **kwargs)
        return Response({'success': True, 'message': 'Privacy updated'})


# ═══════════════════════════════════════════════════════════════════════════
#  JOINED DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════

class JoinedDashboardViewSet(viewsets.ViewSet):
    """Aggregated community dashboard."""
    permission_classes = [IsAuthenticated]

    def list(self, request):
        user = request.user
        memberships = GroupMember.objects.filter(user=user, is_active=True).select_related('group', 'group__creator')
        groups = [m.group for m in memberships]
        group_data = GroupDetailSerializer(groups, many=True, context={'request': request}).data

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
