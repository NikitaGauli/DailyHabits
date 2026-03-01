// =============================================================================
// notification_controller.dart — Notification State Management
// =============================================================================
// Business-logic controller for the notification feature.
//
// Exposes two data streams consumed by the notification screen:
//  • **Inbox** – user notifications with CRUD operations.
//  • **Smart Tips** – AI-generated insights, streak risks, suggestions,
//    and weekly nudges.
//
// All mutation methods apply **optimistic updates** to keep the UI
// responsive, reverting local state if the server call fails.
//
// Lightweight caching (30-second window) prevents redundant API calls
// during rapid tab switches.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/notification_model.dart';
import 'package:dailyhabits/services/notification_service.dart';

class NotificationController extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  // ── Inbox State ────────────────────────────────────────────────
  List<AppNotification> notifications = [];
  bool isInboxLoading = true;
  bool isInboxError = false;

  // ── Smart Tips State ───────────────────────────────────────────
  List<SmartTip> smartTips = [];
  List<dynamic> streakRisks = [];
  List<dynamic> suggestions = [];
  List<dynamic> nudges = [];
  bool isTipsLoading = true;
  bool isTipsError = false;

  // ── Badge ──────────────────────────────────────────────────────
  int unreadCount = 0;

  // ── Cache ──────────────────────────────────────────────────────
  DateTime? _lastInboxLoad;
  DateTime? _lastTipsLoad;
  static const _cacheWindow = Duration(seconds: 30);

  // ── Computed ───────────────────────────────────────────────────
  int get unreadInboxCount =>
      notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  // ═══════════════════════════════════════════════════════════════
  //  INBOX
  // ═══════════════════════════════════════════════════════════════

  /// Fetches the notification inbox and unread count from the API.
  ///
  /// Skips the fetch if the cached data is still within [_cacheWindow]
  /// unless [force] is `true` (e.g. pull-to-refresh).
  Future<void> loadInbox({bool force = false}) async {
    if (!force &&
        _lastInboxLoad != null &&
        DateTime.now().difference(_lastInboxLoad!) < _cacheWindow &&
        notifications.isNotEmpty) {
      return;
    }
    isInboxLoading = notifications.isEmpty;
    isInboxError = false;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getNotifications(),
        _service.getUnreadCount(),
      ]);
      notifications = results[0] as List<AppNotification>;
      unreadCount = results[1] as int;
      isInboxError = false;
      _lastInboxLoad = DateTime.now();
    } catch (_) {
      isInboxError = true;
    } finally {
      isInboxLoading = false;
      notifyListeners();
    }
  }

  /// Marks a single [notification] as read.
  ///
  /// Uses optimistic UI: the local list is updated immediately and
  /// reverted only if the server call fails.
  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    // Optimistic update – flip read flag and decrement badge locally
    final idx = notifications.indexWhere((n) => n.id == notification.id);
    if (idx != -1) {
      notifications[idx] = notification.copyWith(isRead: true);
      unreadCount = (unreadCount - 1).clamp(0, 99999);
      notifyListeners();
    }

    final success = await _service.markAsRead(notification.id);
    if (!success) {
      // Revert
      if (idx != -1) {
        notifications[idx] = notification;
        unreadCount += 1;
        notifyListeners();
      }
    }
  }

  /// Marks every notification in the inbox as read.
  ///
  /// Performs a bulk optimistic update, preserving a snapshot for
  /// rollback if the server request fails.
  Future<void> markAllAsRead() async {
    // Snapshot current state for potential rollback
    final old = List<AppNotification>.from(notifications);
    final oldCount = unreadCount;
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    unreadCount = 0;
    notifyListeners();

    final success = await _service.markAllAsRead();
    if (!success) {
      notifications = old;
      unreadCount = oldCount;
      notifyListeners();
    }
  }

  /// Permanently deletes a notification by [id].
  ///
  /// Removes the item optimistically and rolls back on failure.
  Future<void> deleteNotification(int id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final removed = notifications[idx];
    notifications.removeAt(idx);
    if (!removed.isRead) unreadCount = (unreadCount - 1).clamp(0, 99999);
    notifyListeners();

    final success = await _service.deleteNotification(id);
    if (!success) {
      notifications.insert(idx, removed);
      if (!removed.isRead) unreadCount += 1;
      notifyListeners();
    }
  }

  /// Dismisses (hides) a notification without permanently deleting it.
  ///
  /// Unlike [deleteNotification], this is fire-and-forget – no rollback
  /// on failure since the user explicitly swiped it away.
  Future<void> dismissNotification(int id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final removed = notifications[idx];
    notifications.removeAt(idx);
    if (!removed.isRead) unreadCount = (unreadCount - 1).clamp(0, 99999);
    notifyListeners();

    await _service.dismissNotification(id);
  }

  // ═══════════════════════════════════════════════════════════════
  //  SMART TIPS
  // ═══════════════════════════════════════════════════════════════

  /// Fetches all smart tip sections from the API.
  ///
  /// The response is de-structured into [smartTips], [streakRisks],
  /// [suggestions], and [nudges]. Respects [_cacheWindow] unless
  /// [force] is `true`.
  Future<void> loadSmartTips({bool force = false}) async {
    if (!force &&
        _lastTipsLoad != null &&
        DateTime.now().difference(_lastTipsLoad!) < _cacheWindow &&
        (smartTips.isNotEmpty || streakRisks.isNotEmpty || nudges.isNotEmpty)) {
      return;
    }
    isTipsLoading = smartTips.isEmpty && streakRisks.isEmpty;
    isTipsError = false;
    notifyListeners();

    try {
      final data = await _service.getSmartTipsData();
      if (data.isNotEmpty) {
        smartTips = (data['tips'] as List? ?? [])
            .map((json) => SmartTip.fromJson(json))
            .toList();
        streakRisks = data['streakRisks'] as List? ?? [];
        suggestions = data['suggestions'] as List? ?? [];
        nudges = data['nudges'] as List? ?? [];
      }
      isTipsError = false;
      _lastTipsLoad = DateTime.now();
    } catch (_) {
      isTipsError = true;
    } finally {
      isTipsLoading = false;
      notifyListeners();
    }
  }

  /// Toggles the "liked" state of a smart tip (optimistic).
  Future<void> toggleTipLike(int id) async {
    final idx = smartTips.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final tip = smartTips[idx];
    smartTips[idx] = tip.copyWith(isLiked: !tip.isLiked);
    notifyListeners();

    final success = await _service.toggleTipLike(id);
    if (!success) {
      smartTips[idx] = tip;
      notifyListeners();
    }
  }

  /// Toggles the "saved" state of a smart tip (optimistic).
  Future<void> toggleTipSave(int id) async {
    final idx = smartTips.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final tip = smartTips[idx];
    smartTips[idx] = tip.copyWith(isSaved: !tip.isSaved);
    notifyListeners();

    final success = await _service.toggleTipSave(id);
    if (!success) {
      smartTips[idx] = tip;
      notifyListeners();
    }
  }

  /// Dismisses a smart tip, removing it from the local list (optimistic).
  Future<void> dismissTip(int id) async {
    final idx = smartTips.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final removed = smartTips[idx];
    smartTips.removeAt(idx);
    notifyListeners();

    final success = await _service.dismissTip(id);
    if (!success) {
      smartTips.insert(idx, removed);
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  LOAD ALL
  // ═══════════════════════════════════════════════════════════════

  /// Loads both the inbox and smart tips concurrently.
  ///
  /// Used during initial screen load and global refresh actions.
  Future<void> loadAll({bool force = false}) async {
    await Future.wait([loadInbox(force: force), loadSmartTips(force: force)]);
  }

  /// Refresh just the badge count (lightweight, for bottom nav)
  Future<void> refreshBadge() async {
    try {
      unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  /// Reset state on logout
  void reset() {
    notifications = [];
    smartTips = [];
    streakRisks = [];
    suggestions = [];
    nudges = [];
    unreadCount = 0;
    isInboxLoading = true;
    isTipsLoading = true;
    isInboxError = false;
    isTipsError = false;
    _lastInboxLoad = null;
    _lastTipsLoad = null;
  }
}
