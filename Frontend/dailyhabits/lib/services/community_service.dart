// =============================================================================
// File: community_service.dart
// Description: Social and community service for the DailyHabits application.
//              Provides full-featured interactions for the social feed, friend
//              management, group challenges, referral programs, and the joined
//              community dashboard through the backend social API.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';

// =============================================================================
// Community Service
// =============================================================================

/// Full-featured community service — feed, friends, groups, referrals, and
/// the joined community dashboard.
///
/// Organises all social interactions into five logical sections:
/// 1. **Feed** — Create/read posts, toggle likes, and manage comments.
/// 2. **Friends** — Search users, send/accept/reject requests, remove friends.
/// 3. **Groups** — CRUD for challenge groups, join/leave, leaderboards.
/// 4. **Referrals** — Retrieve referral links and track referral statistics.
/// 5. **Joined Dashboard** — Aggregated view of the user’s social activity.
///
/// All requests are authenticated via JWT tokens from [AuthService].
class CommunityService {
  // ---------------------------------------------------------------------------
  // Dependencies & Configuration
  // ---------------------------------------------------------------------------

  /// Shared [AuthService] instance for retrieving the JWT token.
  final AuthService _auth = AuthService();

  /// Root API base URL from [ApiConfig].
  String get _base => ApiConfig.baseUrl;

  /// Builds authenticated HTTP headers with JSON content type.
  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Convenience decoder — parses the HTTP response body into a JSON map.
  Map<String, dynamic> _decode(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  // ═══════════════════════════════════════════════════════════════
  //  FEED
  // ═══════════════════════════════════════════════════════════════

  /// Fetches the social feed with pagination.
  ///
  /// [page] and [limit] control pagination. Returns the raw feed payload
  /// including posts, like counts, and comment previews.
  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20}) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/feed/?page=$page&limit=$limit'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Feed failed: ${r.statusCode}');
  }

  /// Creates a new post in the social feed.
  ///
  /// Required: [content] text. Optional: [postType] (defaults to `motivation`),
  /// [emoji], associated [habitId] or [groupId], and [isPublic] visibility flag.
  Future<Map<String, dynamic>> createPost({
    required String content,
    String postType = 'motivation',
    String emoji = '',
    int? habitId,
    int? groupId,
    bool isPublic = true,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/feed/'),
      headers: h,
      body: jsonEncode({
        'content': content,
        'postType': postType,
        'emoji': emoji,
        if (habitId != null) 'habitId': habitId,
        if (groupId != null) 'groupId': groupId,
        'isPublic': isPublic,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Create post failed: ${r.statusCode}');
  }

  /// Toggles the like status on a post identified by [postId].
  ///
  /// Returns the updated like state and count.
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/feed/$postId/like/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Like failed: ${r.statusCode}');
  }

  /// Retrieves all comments for the post with the given [postId].
  Future<Map<String, dynamic>> getComments(int postId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/feed/$postId/comments/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Comments failed: ${r.statusCode}');
  }

  /// Adds a new comment with [content] to the post identified by [postId].
  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/feed/$postId/comments/'),
      headers: h,
      body: jsonEncode({'content': content}),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Add comment failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  FRIENDS
  // ═══════════════════════════════════════════════════════════════

  /// Retrieves the authenticated user’s friends list.
  Future<Map<String, dynamic>> getFriends() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$_base/social/friends/'), headers: h);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Friends failed: ${r.statusCode}');
  }

  /// Searches for users matching the given [query] string.
  ///
  /// Used for finding new friends by name or email.
  Future<Map<String, dynamic>> searchUsers(String query) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/friends/search/?q=$query'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Search failed: ${r.statusCode}');
  }

  /// Fetches pending incoming friend requests for the current user.
  Future<Map<String, dynamic>> getFriendRequests() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/friends/requests/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Requests failed: ${r.statusCode}');
  }

  /// Sends a friend request to the user identified by [userId].
  Future<Map<String, dynamic>> sendFriendRequest(int userId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/friends/send-request/'),
      headers: h,
      body: jsonEncode({'userId': userId}),
    );
    final data = _decode(r);
    if (r.statusCode == 200 || r.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Send request failed');
  }

  /// Accepts a pending friend request identified by [friendshipId].
  Future<Map<String, dynamic>> acceptRequest(int friendshipId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/friends/accept-request/'),
      headers: h,
      body: jsonEncode({'friendshipId': friendshipId}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Accept failed: ${r.statusCode}');
  }

  /// Rejects (declines) a pending friend request identified by [friendshipId].
  Future<Map<String, dynamic>> rejectRequest(int friendshipId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/friends/reject-request/'),
      headers: h,
      body: jsonEncode({'friendshipId': friendshipId}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Reject failed: ${r.statusCode}');
  }

  /// Removes an existing friend identified by [userId].
  Future<Map<String, dynamic>> removeFriend(int userId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/friends/remove/'),
      headers: h,
      body: jsonEncode({'userId': userId}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Remove failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  GROUPS
  // ═══════════════════════════════════════════════════════════════

  /// Retrieves all groups the authenticated user belongs to.
  Future<Map<String, dynamic>> getGroups() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$_base/social/groups/'), headers: h);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Groups failed: ${r.statusCode}');
  }

  /// Creates a new challenge group with the given [name] and [description].
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
    List<String> members = const [],
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/'),
      headers: h,
      body: jsonEncode({
        'name': name,
        'description': description,
        'members': members,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Create group failed: ${r.statusCode}');
  }

  /// Joins a group using the provided [inviteCode].
  Future<Map<String, dynamic>> joinGroup(String inviteCode) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/join/'),
      headers: h,
      body: jsonEncode({'inviteCode': inviteCode}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Join group failed: ${r.statusCode}');
  }

  /// Leaves the group identified by [groupId].
  Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/$groupId/leave/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Leave failed: ${r.statusCode}');
  }

  /// Retrieves the member list for the group identified by [groupId].
  Future<Map<String, dynamic>> getGroupMembers(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/members/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Members failed: ${r.statusCode}');
  }

  /// Adds a member to a group by [email] or [userId] (admin only).
  Future<Map<String, dynamic>> addMemberToGroup(
    int groupId, {
    String? email,
    int? userId,
  }) async {
    final h = await _headers();
    final payload = <String, dynamic>{
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (userId != null) 'userId': userId,
    };
    final r = await http.post(
      Uri.parse('$_base/social/groups/$groupId/members/add/'),
      headers: h,
      body: jsonEncode(payload),
    );
    final data = _decode(r);
    if (r.statusCode == 200 || r.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Add member failed');
  }

  /// Deletes a group (soft delete, admin only).
  Future<Map<String, dynamic>> deleteGroup(int groupId) async {
    final h = await _headers();
    final r = await http.delete(
      Uri.parse('$_base/social/groups/$groupId/delete/'),
      headers: h,
    );
    final data = _decode(r);
    if (r.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Delete group failed');
  }

  /// Fetches the leaderboard rankings for the group identified by [groupId].
  Future<Map<String, dynamic>> getLeaderboard(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/leaderboard/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Leaderboard failed: ${r.statusCode}');
  }

  /// Discovers public groups available for the user to join.
  Future<Map<String, dynamic>> discoverGroups() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/discover/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Discover failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  REFERRALS
  // ═══════════════════════════════════════════════════════════════

  /// Retrieves the authenticated user’s unique referral link.
  Future<Map<String, dynamic>> getMyReferralLink() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/referrals/my-link/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Referral link failed: ${r.statusCode}');
  }

  /// Fetches referral statistics (total invited, accepted, rewards earned).
  Future<Map<String, dynamic>> getReferralStats() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/referrals/stats/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Referral stats failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  JOINED DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  /// Fetches the aggregated “joined” community dashboard.
  ///
  /// Provides a unified overview of the user’s social activity including
  /// friends count, group memberships, and recent community highlights.
  Future<Map<String, dynamic>> getJoinedDashboard() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$_base/social/joined/'), headers: h);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Joined dashboard failed: ${r.statusCode}');
  }
  // ═══════════════════════════════════════════════════════════════
  //  SHARED HABITS
  // ═══════════════════════════════════════════════════════════════

  /// Shares a habit with one or more friends.
  Future<Map<String, dynamic>> shareHabit(
    int habitId, {
    required List<int> friendIds,
    bool canComment = true,
    bool canReact = true,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/share/'),
      headers: h,
      body: jsonEncode({
        'friendIds': friendIds,
        'canComment': canComment,
        'canReact': canReact,
      }),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Share habit failed: ${r.statusCode}');
  }

  /// Stops sharing a habit with a specific friend.
  Future<Map<String, dynamic>> unshareHabit(int habitId, int friendId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/unshare/'),
      headers: h,
      body: jsonEncode({'friendId': friendId}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Unshare habit failed: ${r.statusCode}');
  }

  /// Fetches all habits shared with the authenticated user.
  Future<Map<String, dynamic>> getSharedWithMe() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/shared-habits/shared-with-me/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Shared with me failed: ${r.statusCode}');
  }

  /// Toggles a reaction on a shared habit.
  Future<Map<String, dynamic>> reactToHabit(
    int habitId,
    String reactionType,
  ) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/react/'),
      headers: h,
      body: jsonEncode({'reactionType': reactionType}),
    );
    if (r.statusCode == 200 || r.statusCode == 201) return _decode(r);
    throw Exception('React failed: ${r.statusCode}');
  }

  /// Retrieves comments for a shared habit.
  Future<Map<String, dynamic>> getHabitComments(int habitId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/shared-habits/$habitId/comments/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get comments failed: ${r.statusCode}');
  }

  /// Adds a comment to a shared habit.
  Future<Map<String, dynamic>> addHabitComment(
    int habitId,
    String content,
  ) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/comments/'),
      headers: h,
      body: jsonEncode({'content': content}),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Add comment failed: ${r.statusCode}');
  }

  /// Clones a shared habit into the user's own habit list.
  Future<Map<String, dynamic>> joinHabit(int habitId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/join-habit/'),
      headers: h,
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Join habit failed: ${r.statusCode}');
  }

  /// Updates the visibility level of a habit.
  Future<Map<String, dynamic>> updateVisibility(
    int habitId,
    String visibility,
  ) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/shared-habits/$habitId/visibility/'),
      headers: h,
      body: jsonEncode({'visibility': visibility}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Visibility update failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  GROUP CHALLENGES
  // ═══════════════════════════════════════════════════════════════

  /// Fetches all challenges for a group.
  Future<Map<String, dynamic>> getGroupChallenges(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/challenges/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Group challenges failed: ${r.statusCode}');
  }

  /// Creates a new group challenge.
  Future<Map<String, dynamic>> createGroupChallenge(
    int groupId, {
    required String title,
    String description = '',
    String targetType = 'completions',
    int targetValue = 50,
    DateTime? startDate,
    DateTime? endDate,
    int xpReward = 50,
    int coinReward = 10,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/$groupId/challenges/'),
      headers: h,
      body: jsonEncode({
        'title': title,
        'description': description,
        'targetType': targetType,
        'targetValue': targetValue,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        'xpReward': xpReward,
        'coinReward': coinReward,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Create challenge failed: ${r.statusCode}');
  }

  /// Shares a habit with a group.
  Future<Map<String, dynamic>> shareHabitToGroup(
    int groupId,
    int habitId,
  ) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/$groupId/share-habit/'),
      headers: h,
      body: jsonEncode({'habitId': habitId}),
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Share to group failed: ${r.statusCode}');
  }

  /// Fetches enriched group detail with challenges, leaderboard, and stats.
  Future<Map<String, dynamic>> getGroupDetail(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/detail/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Group detail failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  ENCOURAGEMENT
  // ═══════════════════════════════════════════════════════════════

  /// Sends encouragement to a friend.
  Future<Map<String, dynamic>> sendEncouragement({
    required int toUserId,
    String encourageType = 'cheer',
    String message = '',
    int? habitId,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/encouragements/'),
      headers: h,
      body: jsonEncode({
        'toUserId': toUserId,
        'encourageType': encourageType,
        'message': message,
        if (habitId != null) 'habitId': habitId,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Send encouragement failed: ${r.statusCode}');
  }

  /// Fetches encouragements received by the current user.
  Future<Map<String, dynamic>> getEncouragements() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/encouragements/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Encouragements failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIVITY FEED
  // ═══════════════════════════════════════════════════════════════

  /// Fetches the unified activity feed combining encouragements,
  /// reactions, comments, and group challenge updates.
  Future<Map<String, dynamic>> getActivityFeed({int limit = 30}) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/activity/?limit=$limit'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Activity feed failed: ${r.statusCode}');
  }
}
