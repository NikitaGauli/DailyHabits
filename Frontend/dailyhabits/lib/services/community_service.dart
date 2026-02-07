import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';

/// Full-featured community service — feed, friends, groups, referrals, joined.
class CommunityService {
  final AuthService _auth = AuthService();
  String get _base => ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── helper ──────────────────────────────────────────────────────
  Map<String, dynamic> _decode(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  // ═══════════════════════════════════════════════════════════════
  //  FEED
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20}) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/feed/?page=$page&limit=$limit'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Feed failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/feed/$postId/like/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Like failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> getComments(int postId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/feed/$postId/comments/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Comments failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> getFriends() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/friends/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Friends failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/friends/search/?q=$query'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Search failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> getFriendRequests() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/friends/requests/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Requests failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> getGroups() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Groups failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/'),
      headers: h,
      body: jsonEncode({'name': name, 'description': description}),
    );
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Create group failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/social/groups/$groupId/leave/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Leave failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> getGroupMembers(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/members/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Members failed: ${r.statusCode}');
  }

  Future<Map<String, dynamic>> getLeaderboard(int groupId) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/groups/$groupId/leaderboard/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Leaderboard failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> getMyReferralLink() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/referrals/my-link/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Referral link failed: ${r.statusCode}');
  }

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

  Future<Map<String, dynamic>> getJoinedDashboard() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/social/joined/'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Joined dashboard failed: ${r.statusCode}');
  }
}
