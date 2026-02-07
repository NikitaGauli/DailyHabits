import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';
import 'package:dailyhabits/screens/notifications/widgets/notification_tile.dart';
import 'package:dailyhabits/screens/notifications/widgets/smart_tip_card.dart';
import 'package:dailyhabits/models/notification_model.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';
import 'package:dailyhabits/screens/home/home_controller.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InboxTab(),
                  _SmartTipsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HEADER + TAB BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notifications',
                  style: AppTextStyles.h2.copyWith(color: tc.textPrimary),
                ),
              ),
              Consumer<NotificationController>(
                builder: (context, ctrl, _) {
                  final hasUnread = ctrl.notifications.any((n) => !n.isRead);
                  if (!hasUnread) return const SizedBox.shrink();
                  return IconButton(
                    onPressed: ctrl.markAllAsRead,
                    tooltip: 'Mark all read',
                    icon: Icon(Icons.done_all_rounded, color: tc.textMuted),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassContainer(
            padding: const EdgeInsets.all(4),
            borderRadius: BorderRadius.circular(30),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: tc.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: tc.textSecondary,
              labelStyle: AppTextStyles.button.copyWith(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Inbox'),
                      Consumer<NotificationController>(
                        builder: (context, ctrl, _) {
                          if (ctrl.unreadCount <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: tc.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              ctrl.unreadCount > 99
                                  ? '99+'
                                  : '${ctrl.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Tab(text: 'Smart Tips'),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  INBOX TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _InboxTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationController>(
      builder: (context, ctrl, _) {
        if (ctrl.isInboxLoading) {
          return Center(
            child: CircularProgressIndicator(
                color: context.colors.primary),
          );
        }

        if (ctrl.isInboxError) {
          return _buildErrorState(context, ctrl.loadInbox);
        }

        if (ctrl.notifications.isEmpty) {
          return _buildEmptyInbox(context);
        }

        return RefreshIndicator(
          onRefresh: () => ctrl.loadInbox(force: true),
          color: context.colors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: ctrl.notifications.length,
            itemBuilder: (context, index) {
              final notification = ctrl.notifications[index];
              return NotificationTile(
                notification: notification,
                onTap: () => _handleTap(context, notification, ctrl),
                onDismiss: () => ctrl.deleteNotification(notification.id),
              );
            },
          ),
        );
      },
    );
  }

  void _handleTap(
    BuildContext context,
    AppNotification notification,
    NotificationController ctrl,
  ) {
    // Mark as read first
    ctrl.markAsRead(notification);

    // Deep-link navigation
    switch (notification.actionType) {
      case 'habit_detail':
        // Navigate to habit detail if habitId exists
        if (notification.habitId != null) {
          // TODO: Navigate to habit detail screen
        }
        break;
      case 'community':
        // Switch to community tab
        _switchToTab(context, 1);
        break;
      case 'group_detail':
        // Switch to community and open group
        _switchToTab(context, 1);
        break;
      case 'friend_requests':
        _switchToTab(context, 1);
        break;
      case 'achievements':
        _switchToTab(context, 4); // Profile has achievements
        break;
      case 'settings':
        // TODO: Navigate to settings
        break;
      default:
        break;
    }
  }

  void _switchToTab(BuildContext context, int index) {
    try {
      Provider.of<HomeController>(context, listen: false)
          .changeNavigationIndex(index);
    } catch (_) {}
  }

  Widget _buildEmptyInbox(BuildContext context) {
    final tc = context.colors;
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: tc.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'No new notifications.\nKeep building great habits!',
              style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, VoidCallback onRetry) {
    final tc = context.colors;
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: tc.textMuted),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: tc.primary),
              label: Text('Retry',
                  style: TextStyle(color: tc.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SMART TIPS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SmartTipsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationController>(
      builder: (context, ctrl, _) {
        if (ctrl.isTipsLoading) {
          return Center(
            child: CircularProgressIndicator(
                color: context.colors.primary),
          );
        }

        if (ctrl.isTipsError) {
          return _buildErrorState(context, ctrl.loadSmartTips);
        }

        if (ctrl.smartTips.isEmpty) {
          return _buildEmptyTips(context);
        }

        return RefreshIndicator(
          onRefresh: () => ctrl.loadSmartTips(force: true),
          color: context.colors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: ctrl.smartTips.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) return _buildTipsHeader(context);
              final tip = ctrl.smartTips[index - 1];
              return SmartTipCard(
                tip: tip,
                onLike: () => ctrl.toggleTipLike(tip.id),
                onSave: () => ctrl.toggleTipSave(tip.id),
                onDismiss: () => ctrl.dismissTip(tip.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTipsHeader(BuildContext context) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: tc.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Personalized tips based on your habit patterns',
              style: AppTextStyles.caption.copyWith(
                color: tc.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTips(BuildContext context) {
    final tc = context.colors;
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: tc.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tips yet',
              style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete more habits to unlock\npersonalized smart tips!',
              style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, VoidCallback onRetry) {
    final tc = context.colors;
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: tc.textMuted),
            const SizedBox(height: 16),
            Text(
              'Could not load tips',
              style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: tc.accent),
              label: Text('Retry',
                  style: TextStyle(color: tc.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
