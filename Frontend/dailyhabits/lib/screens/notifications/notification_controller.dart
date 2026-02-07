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

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    // Optimistic update
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

  Future<void> markAllAsRead() async {
    // Optimistic
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

  Future<void> loadSmartTips({bool force = false}) async {
    if (!force &&
        _lastTipsLoad != null &&
        DateTime.now().difference(_lastTipsLoad!) < _cacheWindow &&
        smartTips.isNotEmpty) {
      return;
    }
    isTipsLoading = smartTips.isEmpty;
    isTipsError = false;
    notifyListeners();

    try {
      smartTips = await _service.getSmartTips();
      isTipsError = false;
      _lastTipsLoad = DateTime.now();
    } catch (_) {
      isTipsError = true;
    } finally {
      isTipsLoading = false;
      notifyListeners();
    }
  }

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
    unreadCount = 0;
    isInboxLoading = true;
    isTipsLoading = true;
    isInboxError = false;
    isTipsError = false;
    _lastInboxLoad = null;
    _lastTipsLoad = null;
  }
}
