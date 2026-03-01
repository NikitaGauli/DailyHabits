// =============================================================================
// File: grow_together_service.dart
// Description: API service for the Grow Together collaborative habit sharing
//              system. Handles all HTTP communication with the backend
//              /api/grow-together/ endpoints.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailyhabits/services/auth_service.dart';
import 'package:dailyhabits/services/api_config.dart';

// =============================================================================
// Grow Together Service
// =============================================================================

/// HTTP service for all Grow Together collaborative habit sharing endpoints.
///
/// Sections:
/// 1. **Dashboard** — Aggregated overview of collaborative habits.
/// 2. **CRUD**      — Create, list, retrieve collaborative habits.
/// 3. **Invites**   — Send, accept, decline, and list invitations.
/// 4. **Progress**  — Log and retrieve daily progress.
/// 5. **Members**   — List members, join, leave, remove.
/// 6. **Social**    — Reactions, comments on progress.
/// 7. **Feed**      — Activity feed per habit and global.
/// 8. **Leaderboard & Milestones** — Weekly rankings and achievements.
/// 9. **Discover**  — Browse public habits.
/// 10. **Analytics & Moderation** — Stats and abuse reporting.
class GrowTogetherService {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final AuthService _auth = AuthService();
  String get _base => '${ApiConfig.baseUrl}/grow-together';

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  // ═══════════════════════════════════════════════════════════════
  //  1. DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  /// Fetches the full Grow Together dashboard.
  Future<Map<String, dynamic>> getDashboard() async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/dashboard/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Dashboard failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. CRUD
  // ═══════════════════════════════════════════════════════════════

  /// Lists all collaborative habits the user is a member of.
  Future<Map<String, dynamic>> listHabits() async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('List habits failed: ${r.statusCode}');
  }

  /// Retrieves a single collaborative habit by [id].
  Future<Map<String, dynamic>> getHabit(String id) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$id/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get habit failed: ${r.statusCode}');
  }

  /// Creates a new collaborative habit.
  Future<Map<String, dynamic>> createHabit({
    required String title,
    String description = '',
    String emoji = '🎯',
    String frequency = 'daily',
    List<int> customDays = const [],
    int targetCount = 1,
    String privacy = 'friends_only',
    int maxMembers = 50,
    int iconCode = 0xE87C,
    int colorValue = 0xFF4F46E5,
    int xpPerCompletion = 15,
    int bonusAllCompleteXp = 25,
    int? sourceHabitId,
  }) async {
    final h = await _headers();
    final body = {
      'title': title,
      'description': description,
      'emoji': emoji,
      'frequency': frequency,
      'customDays': customDays,
      'targetCount': targetCount,
      'privacy': privacy,
      'maxMembers': maxMembers,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'xpPerCompletion': xpPerCompletion,
      'bonusAllCompleteXp': bonusAllCompleteXp,
    };
    if (sourceHabitId != null) body['sourceHabitId'] = sourceHabitId;

    final r = await http
        .post(Uri.parse('$_base/create/'), headers: h, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Create habit failed: ${r.statusCode} ${r.body}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. INVITES
  // ═══════════════════════════════════════════════════════════════

  /// Sends invitations to friends for a collaborative habit.
  Future<Map<String, dynamic>> sendInvites({
    required String habitId,
    required List<int> friendIds,
    String message = '',
  }) async {
    final h = await _headers();
    final body = {'friendIds': friendIds, 'message': message};
    final r = await http
        .post(Uri.parse('$_base/$habitId/invite/'),
            headers: h, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Send invites failed: ${r.statusCode} ${r.body}');
  }

  /// Accepts an invitation by [inviteId].
  Future<Map<String, dynamic>> acceptInvite(String inviteId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/accept-invite/'),
            headers: h, body: jsonEncode({'inviteId': inviteId}))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Accept invite failed: ${r.statusCode}');
  }

  /// Declines an invitation by [inviteId].
  Future<Map<String, dynamic>> declineInvite(String inviteId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/decline-invite/'),
            headers: h, body: jsonEncode({'inviteId': inviteId}))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Decline invite failed: ${r.statusCode}');
  }

  /// Lists pending invites for the current user.
  Future<Map<String, dynamic>> getMyInvites() async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/my-invites/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get invites failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. PROGRESS
  // ═══════════════════════════════════════════════════════════════

  /// Logs progress for a collaborative habit.
  Future<Map<String, dynamic>> logProgress({
    required String habitId,
    String note = '',
    int completionCount = 1,
  }) async {
    final h = await _headers();
    final body = {'note': note, 'completionCount': completionCount};
    final r = await http
        .post(Uri.parse('$_base/$habitId/progress/'),
            headers: h, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Log progress failed: ${r.statusCode} ${r.body}');
  }

  /// Gets progress records for a collaborative habit on a specific [date].
  Future<Map<String, dynamic>> getProgress(String habitId,
      {String? date}) async {
    final h = await _headers();
    final query = date != null ? '?date=$date' : '';
    final r = await http
        .get(Uri.parse('$_base/$habitId/progress/$query'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get progress failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. MEMBERS
  // ═══════════════════════════════════════════════════════════════

  /// Lists all members of a collaborative habit.
  Future<Map<String, dynamic>> getMembers(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/members/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get members failed: ${r.statusCode}');
  }

  /// Joins a public collaborative habit.
  Future<Map<String, dynamic>> joinHabit(String habitId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/$habitId/join/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Join habit failed: ${r.statusCode}');
  }

  /// Leaves a collaborative habit.
  Future<Map<String, dynamic>> leaveHabit(String habitId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/$habitId/leave/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Leave habit failed: ${r.statusCode}');
  }

  /// Removes a member from a collaborative habit (owner/admin only).
  Future<Map<String, dynamic>> removeMember(
      String habitId, int userId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/$habitId/remove-member/'),
            headers: h, body: jsonEncode({'userId': userId}))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Remove member failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  6. SOCIAL — Reactions & Comments
  // ═══════════════════════════════════════════════════════════════

  /// Toggles an emoji reaction on a progress entry.
  Future<Map<String, dynamic>> toggleReaction(
      String progressId, String reactionType) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/progress/$progressId/react/'),
            headers: h, body: jsonEncode({'reactionType': reactionType}))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Toggle reaction failed: ${r.statusCode}');
  }

  /// Gets comments on a progress entry.
  Future<Map<String, dynamic>> getComments(String progressId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/progress/$progressId/comments/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get comments failed: ${r.statusCode}');
  }

  /// Posts a comment on a progress entry.
  Future<Map<String, dynamic>> addComment(
      String progressId, String content) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/progress/$progressId/comments/'),
            headers: h, body: jsonEncode({'content': content}))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Add comment failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  7. FEED
  // ═══════════════════════════════════════════════════════════════

  /// Gets the activity feed for a specific collaborative habit.
  Future<Map<String, dynamic>> getHabitFeed(String habitId,
      {int page = 1, int limit = 30}) async {
    final h = await _headers();
    final r = await http
        .get(
            Uri.parse(
                '$_base/$habitId/feed/?page=$page&limit=$limit'),
            headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get habit feed failed: ${r.statusCode}');
  }

  /// Gets the global activity feed across all collaborative habits.
  Future<Map<String, dynamic>> getGlobalFeed(
      {int page = 1, int limit = 30}) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/feed/?page=$page&limit=$limit'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get global feed failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  8. LEADERBOARD & MILESTONES
  // ═══════════════════════════════════════════════════════════════

  /// Gets the weekly leaderboard for a collaborative habit.
  Future<Map<String, dynamic>> getLeaderboard(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/leaderboard/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get leaderboard failed: ${r.statusCode}');
  }

  /// Gets group milestones for a collaborative habit.
  Future<Map<String, dynamic>> getMilestones(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/milestones/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get milestones failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  9. DISCOVER
  // ═══════════════════════════════════════════════════════════════

  /// Discovers public collaborative habits.
  Future<Map<String, dynamic>> discoverHabits({int limit = 20}) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/discover/?limit=$limit'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Discover habits failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  10. ANALYTICS & MODERATION
  // ═══════════════════════════════════════════════════════════════

  /// Gets engagement analytics for a collaborative habit.
  Future<Map<String, dynamic>> getAnalytics(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/analytics/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get analytics failed: ${r.statusCode}');
  }

  /// Reports abuse in a collaborative habit.
  Future<Map<String, dynamic>> reportAbuse({
    required String habitId,
    required int reportedUserId,
    required String reason,
    required String description,
  }) async {
    final h = await _headers();
    final body = {
      'reportedUserId': reportedUserId,
      'reason': reason,
      'description': description,
    };
    final r = await http
        .post(Uri.parse('$_base/$habitId/report/'),
            headers: h, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Report abuse failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  11. UNMARK PROGRESS (Undo completion)
  // ═══════════════════════════════════════════════════════════════

  /// Undo today's completed progress for a collaborative habit.
  Future<Map<String, dynamic>> unmarkProgress(String habitId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/$habitId/unmark-progress/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Unmark progress failed: ${r.statusCode} ${r.body}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  11b. TODAY STATUS
  // ═══════════════════════════════════════════════════════════════

  /// Gets the user's completion status for today.
  Future<Map<String, dynamic>> getTodayStatus(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/today-status/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get today status failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  11c. GROUP PROGRESS
  // ═══════════════════════════════════════════════════════════════

  /// Gets group-level progress (all members' completion status for a date).
  Future<Map<String, dynamic>> getGroupProgress(String habitId,
      {String? date}) async {
    final h = await _headers();
    final query = date != null ? '?date=$date' : '';
    final r = await http
        .get(Uri.parse('$_base/$habitId/group-progress/$query'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get group progress failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  12. STREAK CALENDAR
  // ═══════════════════════════════════════════════════════════════

  /// Gets the streak calendar (30-day history) for a collaborative habit.
  Future<Map<String, dynamic>> getStreakCalendar(String habitId,
      {int days = 30}) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/streak-calendar/?days=$days'),
            headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get streak calendar failed: ${r.statusCode}');
  }

  // ═══════════════════════════════════════════════════════════════
  //  13. STREAK FREEZES
  // ═══════════════════════════════════════════════════════════════

  /// Gets the user's streak freeze info for a collaborative habit.
  Future<Map<String, dynamic>> getStreakFreezes(String habitId) async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$_base/$habitId/streak-freezes/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Get streak freezes failed: ${r.statusCode}');
  }

  /// Purchases a streak freeze using XP.
  Future<Map<String, dynamic>> buyStreakFreeze(String habitId) async {
    final h = await _headers();
    final r = await http
        .post(Uri.parse('$_base/$habitId/buy-freeze/'), headers: h)
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 201) return _decode(r);
    throw Exception('Buy streak freeze failed: ${r.statusCode} ${r.body}');
  }

  /// Uses a streak freeze to protect a missed day.
  Future<Map<String, dynamic>> useStreakFreeze(String habitId,
      {String? date}) async {
    final h = await _headers();
    final body = <String, dynamic>{};
    if (date != null) body['date'] = date;
    final r = await http
        .post(Uri.parse('$_base/$habitId/use-freeze/'),
            headers: h, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    if (r.statusCode == 200) return _decode(r);
    throw Exception('Use streak freeze failed: ${r.statusCode} ${r.body}');
  }
}
