// =============================================================================
// File: community_controller.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: Centralised state management for the entire Community module.
//              Manages feed posts, friend relationships, group membership,
//              referral data, and the joined dashboard via [CommunityService].
//              Extends [ChangeNotifier] so all five community tabs can react
//              to data changes through Provider.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/services/community_service.dart';
import 'package:dailyhabits/models/shared_habit.dart';
import 'package:dailyhabits/models/community_models.dart';

/// Reactive state controller for all five Community tabs.
///
/// Orchestrates data loading, pagination, search, and CRUD operations
/// for the Feed, Friends, Groups, Invite, and Joined Dashboard sections.
/// Each public method follows a consistent pattern: call the service,
/// update local state, and invoke [notifyListeners].
class CommunityController extends ChangeNotifier {
  /// Backend service handling all community-related HTTP requests.
  final CommunityService _svc = CommunityService();

  // ── Global State ──────────────────────────────────────────────────────

  /// Whether the controller is performing its initial bulk load.
  bool isLoading = false;

  /// Human-readable error message from the most recent operation.
  String? error;

  // ── Feed State ────────────────────────────────────────────────────────

  /// All currently loaded feed posts (accumulated during pagination).
  List<Map<String, dynamic>> feedPosts = [];

  /// Internal cursor for feed pagination.
  int _feedPage = 1;

  /// Whether there may be more feed pages to load.
  bool hasMoreFeed = true;

  // ── Friends State ──────────────────────────────────────────────────────

  /// Accepted friends list.
  List<Map<String, dynamic>> friends = [];

  /// Pending friend requests received from other users.
  List<Map<String, dynamic>> incomingRequests = [];

  /// Pending friend requests sent by the current user.
  List<Map<String, dynamic>> outgoingRequests = [];

  /// User search results from the most recent query.
  List<Map<String, dynamic>> searchResults = [];

  /// Whether a user search request is in-flight.
  bool isSearching = false;

  /// Cached query string used by [_refreshSearch] after relationship changes.
  String _lastSearchQuery = '';

  /// Latest action feedback message (success or error). Consumed by UI.
  String? actionMessage;
  bool actionSuccess = false;

  // ── Groups State ──────────────────────────────────────────────────────

  /// Groups the user is currently a member of.
  List<Map<String, dynamic>> myGroups = [];

  /// Public groups available for the user to join.
  List<Map<String, dynamic>> discoverGroups = [];

  // ── Referral State ────────────────────────────────────────────────────

  /// The user's referral code, invite/join stats, and related metadata.
  Map<String, dynamic>? referralData;

  // ── Joined Dashboard State ────────────────────────────────────────────

  /// Aggregated overview data for the Joined tab (friends, groups, streak).
  Map<String, dynamic>? joinedData;

  // ── Shared Habits State ────────────────────────────────────────────

  /// Habits shared with the current user.
  List<SharedHabit> sharedHabits = [];

  /// Whether shared habits are currently being loaded.
  bool isLoadingShared = false;

  // ── Activity Feed State ────────────────────────────────────────────

  /// Unified activity feed items.
  List<ActivityFeedItem> activityFeed = [];

  /// Whether activity feed is loading.
  bool isLoadingActivity = false;

  // ── Encouragement State ────────────────────────────────────────────

  /// Encouragements received by the current user.
  List<Encouragement> encouragements = [];

  // ── Group Detail State ─────────────────────────────────────────────

  /// Currently viewed enriched group detail.
  EnrichedGroupDetail? selectedGroupDetail;

  /// Whether group detail is loading.
  bool isLoadingGroupDetail = false;

  // ═══════════════════════════════════════════════════════════════
  //  INIT — Bulk-loads all tab data in parallel
  // ═════════════════════════════════════════════════════════════

  /// Loads data for all five tabs concurrently.
  ///
  /// Toggles [isLoading] around the parallel requests so the UI can
  /// show a spinner during the initial load.
  Future<void> loadAll() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([
        loadFeed(reset: true),
        loadFriends(),
        loadGroups(),
        loadReferral(),
        loadJoined(),
        loadSharedHabits(),
      ]);
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  FEED — Paginated post loading, creation, and likes
  // ═════════════════════════════════════════════════════════════

  /// Fetches the next page of feed posts, or resets to page 1 if [reset].
  ///
  /// Appends new results to [feedPosts] and advances the internal page
  /// counter. Sets [hasMoreFeed] to `false` once an empty page returns.
  Future<void> loadFeed({bool reset = false}) async {
    if (reset) {
      _feedPage = 1;
      hasMoreFeed = true;
      feedPosts = [];
    }
    try {
      final data = await _svc.getFeed(page: _feedPage);
      final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
      if (results.isEmpty) {
        hasMoreFeed = false;
      } else {
        feedPosts.addAll(results);
        _feedPage++;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Creates a new feed post with [content] and optional [emoji],
  /// then refreshes the feed to show the new post.
  Future<void> createPost(String content, {String emoji = ''}) async {
    try {
      await _svc.createPost(content: content, emoji: emoji);
      await loadFeed(reset: true);
    } catch (_) {}
  }

  /// Toggles the like state on a post and optimistically updates the
  /// local model so the UI reacts immediately.
  Future<void> toggleLike(int postId) async {
    try {
      final result = await _svc.toggleLike(postId);
      final idx = feedPosts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        feedPosts[idx] = {
          ...feedPosts[idx],
          'isLiked': result['liked'],
          'likeCount': result['likeCount'],
        };
        notifyListeners();
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  FRIENDS — Search, requests, and relationship management
  // ═════════════════════════════════════════════════════════════

  /// Loads the accepted friends list and splits incoming / outgoing
  /// friend requests from the backend.
  Future<void> loadFriends() async {
    try {
      final data = await _svc.getFriends();
      friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);

      final reqData = await _svc.getFriendRequests();
      incomingRequests = List<Map<String, dynamic>>.from(
        reqData['incoming'] ?? [],
      );
      outgoingRequests = List<Map<String, dynamic>>.from(
        reqData['outgoing'] ?? [],
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Searches for users matching [query]. Clears results if query length
  /// is under 2 characters to avoid excessive API calls.
  Future<void> searchUsers(String query) async {
    _lastSearchQuery = query;
    if (query.length < 2) {
      searchResults = [];
      isSearching = false;
      notifyListeners();
      return;
    }
    isSearching = true;
    notifyListeners();
    try {
      final data = await _svc.searchUsers(query);
      searchResults = List<Map<String, dynamic>>.from(data['users'] ?? []);
    } catch (_) {
      searchResults = [];
    }
    isSearching = false;
    notifyListeners();
  }

  /// Re-run the last search to refresh relationship statuses.
  Future<void> _refreshSearch() async {
    if (_lastSearchQuery.length >= 2) {
      try {
        final data = await _svc.searchUsers(_lastSearchQuery);
        searchResults = List<Map<String, dynamic>>.from(data['users'] ?? []);
      } catch (_) {}
    }
  }

  /// Sets the one-shot action feedback message consumed by the UI’s
  /// post-frame-callback snackbar display.
  void _setAction(bool success, String msg) {
    actionSuccess = success;
    actionMessage = msg;
  }

  /// Sends a friend request to [userId] and optimistically updates the
  /// search results to show “Pending” immediately.
  Future<bool> sendFriendRequest(int userId) async {
    try {
      final result = await _svc.sendFriendRequest(userId);
      // Optimistically flip the relationship status in search results
      for (int i = 0; i < searchResults.length; i++) {
        if (searchResults[i]['id'] == userId) {
          searchResults[i] = {...searchResults[i], 'relationship': 'pending'};
        }
      }
      await loadFriends();
      _setAction(true, result['message'] ?? 'Friend request sent');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  /// Accepts a pending friend request identified by [friendshipId].
  Future<bool> acceptRequest(int friendshipId) async {
    try {
      await _svc.acceptRequest(friendshipId);
      await loadFriends();
      await _refreshSearch();
      _setAction(true, 'Friend request accepted!');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  /// Rejects a pending friend request identified by [friendshipId].
  Future<bool> rejectRequest(int friendshipId) async {
    try {
      await _svc.rejectRequest(friendshipId);
      await loadFriends();
      await _refreshSearch();
      _setAction(true, 'Request rejected');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  /// Removes an existing friend by [userId] and refreshes local state.
  Future<bool> removeFriend(int userId) async {
    try {
      await _svc.removeFriend(userId);
      await loadFriends();
      await _refreshSearch();
      _setAction(true, 'Friend removed');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  GROUPS — Create, join, leave, and discover groups
  // ═════════════════════════════════════════════════════════════

  /// Fetches the list of groups the current user belongs to.
  Future<void> loadGroups() async {
    try {
      final data = await _svc.getGroups();
      myGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  /// Creates a new group with the given [name] and [description],
  /// then refreshes [myGroups].
  Future<void> createGroup(String name, String description) async {
    try {
      await _svc.createGroup(name: name, description: description);
      await loadGroups();
    } catch (_) {}
  }

  /// Joins a group using its [inviteCode] and refreshes [myGroups].
  Future<void> joinGroup(String inviteCode) async {
    try {
      await _svc.joinGroup(inviteCode);
      await loadGroups();
    } catch (_) {}
  }

  /// Leaves the group identified by [groupId] and refreshes [myGroups].
  Future<void> leaveGroup(int groupId) async {
    try {
      await _svc.leaveGroup(groupId);
      await loadGroups();
    } catch (_) {}
  }

  /// Fetches publicly discoverable groups for the browse/discover view.
  Future<void> loadDiscoverGroups() async {
    try {
      final data = await _svc.discoverGroups();
      discoverGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  REFERRALS — Invite link management
  // ═════════════════════════════════════════════════════════════

  /// Fetches the current user’s referral code and invite statistics.
  Future<void> loadReferral() async {
    try {
      final data = await _svc.getMyReferralLink();
      referralData = data['referral'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  JOINED DASHBOARD — Aggregated social overview
  // ═════════════════════════════════════════════════════════════

  /// Loads the aggregated joined dashboard including friend count,
  /// group list, community streak, and recent friend activity.
  Future<void> loadJoined() async {
    try {
      final data = await _svc.getJoinedDashboard();
      joinedData = data['data'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED HABITS — Load, react, comment, join
  // ═══════════════════════════════════════════════════════════════

  /// Loads all habits shared with the current user.
  Future<void> loadSharedHabits() async {
    isLoadingShared = true;
    notifyListeners();
    try {
      final data = await _svc.getSharedWithMe();
      final raw = List<Map<String, dynamic>>.from(data['data'] ?? []);
      sharedHabits = raw.map((j) => SharedHabit.fromJson(j)).toList();
    } catch (_) {
      sharedHabits = [];
    }
    isLoadingShared = false;
    notifyListeners();
  }

  /// Toggles a reaction on a shared habit and refreshes the feed.
  Future<void> reactToHabit(int habitId, String reactionType) async {
    try {
      await _svc.reactToHabit(habitId, reactionType);
      await loadSharedHabits();
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
    }
  }

  /// Posts a comment on a shared habit and refreshes the feed.
  Future<void> commentOnHabit(int habitId, String content) async {
    try {
      await _svc.addHabitComment(habitId, content);
      await loadSharedHabits();
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
    }
  }

  /// Clones a shared habit into the user's own habit list.
  Future<void> joinHabit(int habitId) async {
    try {
      final result = await _svc.joinHabit(habitId);
      _setAction(true, result['message'] ?? 'Habit joined!');
      await loadSharedHabits();
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
    }
  }

  /// Shares a habit with selected friends.
  Future<void> shareHabit(
    int habitId, {
    required List<int> friendIds,
    bool canComment = true,
    bool canReact = true,
  }) async {
    try {
      final result = await _svc.shareHabit(
        habitId,
        friendIds: friendIds,
        canComment: canComment,
        canReact: canReact,
      );
      _setAction(true, result['message'] ?? 'Habit shared!');
      notifyListeners();
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIVITY FEED — Unified social stream
  // ═══════════════════════════════════════════════════════════════

  /// Loads the unified activity feed.
  Future<void> loadActivityFeed() async {
    isLoadingActivity = true;
    notifyListeners();
    try {
      final data = await _svc.getActivityFeed();
      final raw = List<Map<String, dynamic>>.from(data['activity'] ?? []);
      activityFeed = raw.map((j) => ActivityFeedItem.fromJson(j)).toList();
    } catch (_) {
      activityFeed = [];
    }
    isLoadingActivity = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  ENCOURAGEMENT — Send and receive motivational nudges
  // ═══════════════════════════════════════════════════════════════

  /// Loads encouragements received by the current user.
  Future<void> loadEncouragements() async {
    try {
      final data = await _svc.getEncouragements();
      final raw = List<Map<String, dynamic>>.from(
        data['encouragements'] ?? [],
      );
      encouragements = raw.map((j) => Encouragement.fromJson(j)).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Sends encouragement to a friend.
  Future<bool> sendEncouragement({
    required int toUserId,
    String encourageType = 'cheer',
    String message = '',
    int? habitId,
  }) async {
    try {
      await _svc.sendEncouragement(
        toUserId: toUserId,
        encourageType: encourageType,
        message: message,
        habitId: habitId,
      );
      _setAction(true, 'Encouragement sent!');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  GROUP CHALLENGES — Create and view group challenges
  // ═══════════════════════════════════════════════════════════════

  /// Fetches enriched group detail with challenges, leaderboard, and stats.
  Future<void> loadGroupDetail(int groupId) async {
    isLoadingGroupDetail = true;
    notifyListeners();
    try {
      final data = await _svc.getGroupDetail(groupId);
      final raw = data['data'] as Map<String, dynamic>? ?? {};
      selectedGroupDetail = EnrichedGroupDetail.fromJson(raw);
    } catch (_) {
      selectedGroupDetail = null;
    }
    isLoadingGroupDetail = false;
    notifyListeners();
  }

  /// Creates a new group challenge.
  Future<bool> createGroupChallenge(
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
    try {
      await _svc.createGroupChallenge(
        groupId,
        title: title,
        description: description,
        targetType: targetType,
        targetValue: targetValue,
        startDate: startDate,
        endDate: endDate,
        xpReward: xpReward,
        coinReward: coinReward,
      );
      _setAction(true, 'Challenge created!');
      await loadGroupDetail(groupId);
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }

  /// Shares a habit with a group.
  Future<bool> shareHabitToGroup(int groupId, int habitId) async {
    try {
      final result = await _svc.shareHabitToGroup(groupId, habitId);
      _setAction(true, result['message'] ?? 'Habit shared with group!');
      notifyListeners();
      return true;
    } catch (e) {
      _setAction(false, e.toString().replaceFirst('Exception: ', ''));
      notifyListeners();
      return false;
    }
  }
}
