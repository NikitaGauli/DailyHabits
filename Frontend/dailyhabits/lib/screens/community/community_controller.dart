import 'package:flutter/material.dart';
import 'package:dailyhabits/services/community_service.dart';

/// State management for the Community module — all 5 tabs.
class CommunityController extends ChangeNotifier {
  final CommunityService _svc = CommunityService();

  // ── Global ─────────────────────────────────────────────────────
  bool isLoading = false;
  String? error;

  // ── Feed ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> feedPosts = [];
  int _feedPage = 1;
  bool hasMoreFeed = true;

  // ── Friends ────────────────────────────────────────────────────
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> incomingRequests = [];
  List<Map<String, dynamic>> outgoingRequests = [];
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  String _lastSearchQuery = '';

  /// Latest action feedback message (success or error). Consumed by UI.
  String? actionMessage;
  bool actionSuccess = false;

  // ── Groups ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> myGroups = [];
  List<Map<String, dynamic>> discoverGroups = [];

  // ── Referrals ──────────────────────────────────────────────────
  Map<String, dynamic>? referralData;

  // ── Joined Dashboard ───────────────────────────────────────────
  Map<String, dynamic>? joinedData;

  // ═══════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════

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
      ]);
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  FEED
  // ═══════════════════════════════════════════════════════════════

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

  Future<void> createPost(String content, {String emoji = ''}) async {
    try {
      await _svc.createPost(content: content, emoji: emoji);
      await loadFeed(reset: true);
    } catch (_) {}
  }

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
  //  FRIENDS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadFriends() async {
    try {
      final data = await _svc.getFriends();
      friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);

      final reqData = await _svc.getFriendRequests();
      incomingRequests =
          List<Map<String, dynamic>>.from(reqData['incoming'] ?? []);
      outgoingRequests =
          List<Map<String, dynamic>>.from(reqData['outgoing'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

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

  void _setAction(bool success, String msg) {
    actionSuccess = success;
    actionMessage = msg;
  }

  Future<bool> sendFriendRequest(int userId) async {
    try {
      final result = await _svc.sendFriendRequest(userId);
      // Locally update search results so Add → Pending instantly
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
  //  GROUPS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadGroups() async {
    try {
      final data = await _svc.getGroups();
      myGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createGroup(String name, String description) async {
    try {
      await _svc.createGroup(name: name, description: description);
      await loadGroups();
    } catch (_) {}
  }

  Future<void> joinGroup(String inviteCode) async {
    try {
      await _svc.joinGroup(inviteCode);
      await loadGroups();
    } catch (_) {}
  }

  Future<void> leaveGroup(int groupId) async {
    try {
      await _svc.leaveGroup(groupId);
      await loadGroups();
    } catch (_) {}
  }

  Future<void> loadDiscoverGroups() async {
    try {
      final data = await _svc.discoverGroups();
      discoverGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  REFERRALS
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadReferral() async {
    try {
      final data = await _svc.getMyReferralLink();
      referralData = data['referral'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  JOINED DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadJoined() async {
    try {
      final data = await _svc.getJoinedDashboard();
      joinedData = data['data'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }
}
