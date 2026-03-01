// =============================================================================
// notification_screen.dart — Notifications Hub
// =============================================================================
// The primary notification centre for the DailyHabits application.
//
// This screen presents a dual-tab layout:
//  • **Inbox** – chronological list of user notifications (friend requests,
//    streak alerts, achievements, etc.) with swipe-to-dismiss, mark-all-read,
//    and deep-link navigation.
//  • **Smart Tips** – AI-generated personalised advice, streak risk warnings,
//    scheduling suggestions, and weekly nudges.
//
// State is managed via [NotificationController] (ChangeNotifier) and consumed
// with the Provider package.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';
import 'package:dailyhabits/screens/notifications/widgets/notification_tile.dart';
import 'package:dailyhabits/screens/notifications/widgets/smart_tip_card.dart';
import 'package:dailyhabits/models/notification_model.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';
import 'package:dailyhabits/screens/home/home_controller.dart';
import 'package:dailyhabits/screens/settings/settings_screen.dart';

/// The root widget for the notifications screen.
///
/// Creates the [_NotificationScreenState] which owns the [TabController]
/// driving the Inbox / Smart Tips tab bar.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

/// Internal state for [NotificationScreen].
///
/// Manages:
///  • A two-tab [TabController] (Inbox / Smart Tips).
///  • Initial data fetch via [NotificationController.loadAll] after the first
///    frame renders.
class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  /// Controls the Inbox ↔ Smart Tips tab bar.
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer data loading until the widget tree is fully built.
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

  /// Builds the screen header containing the title, the mark-all-read
  /// action button, and a glass-styled [TabBar] with an unread badge.
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

/// Displays the user's notification inbox with pull-to-refresh, swipe-to-delete
/// tiles, and deep-link navigation to relevant app sections.
///
/// Handles three visual states:
///  1. **Loading** – centred progress indicator.
///  2. **Error** – connection error card with retry.
///  3. **Empty** – motivational "all caught up" message.
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

  /// Handles a notification tap: marks it as read, then deep-links to
  /// the appropriate screen based on [AppNotification.actionType].
  void _handleTap(
    BuildContext context,
    AppNotification notification,
    NotificationController ctrl,
  ) {
    // Mark as read first
    ctrl.markAsRead(notification);

    // Deep-link navigation based on the notification's action type
    switch (notification.actionType) {
      case 'habit_detail':
        // Navigate to the habits tab so the user can find the relevant habit
        if (notification.habitId != null) {
          _switchToTab(context, 0);
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      default:
        break;
    }
  }

  /// Switches the main bottom navigation to the given [index].
  ///
  /// Wrapped in a try/catch because the [HomeController] may not be
  /// available in all navigation contexts (e.g. deep-linked screens).
  void _switchToTab(BuildContext context, int index) {
    try {
      Provider.of<HomeController>(context, listen: false)
          .changeNavigationIndex(index);
    } catch (_) {}
  }

  /// Empty-state widget shown when there are no notifications.
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

  /// Error-state widget with a retry button, shown when the inbox
  /// fetch fails (e.g. network issues).
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

/// Displays AI-generated personalised tips grouped into sections:
///  • **Streaks at Risk** – habits whose streaks may break soon.
///  • **Suggestions** – optimal scheduling recommendations.
///  • **This Week** – weekly motivational nudges.
///  • **For You** – persisted smart tip cards (likeable / saveable).
///
/// Supports pull-to-refresh, loading, error, and empty states.
class _SmartTipsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationController>(
      builder: (context, ctrl, _) {
        final tc = context.colors;

        if (ctrl.isTipsLoading) {
          return Center(
            child: CircularProgressIndicator(color: tc.primary),
          );
        }

        if (ctrl.isTipsError) {
          return _buildErrorState(context, ctrl.loadSmartTips);
        }

        final hasIntelligence = ctrl.streakRisks.isNotEmpty ||
            ctrl.suggestions.isNotEmpty ||
            ctrl.nudges.isNotEmpty;

        if (ctrl.smartTips.isEmpty && !hasIntelligence) {
          return _buildEmptyTips(context);
        }

        return RefreshIndicator(
          onRefresh: () => ctrl.loadSmartTips(force: true),
          color: tc.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildTipsHeader(context),

              // ── Streak Risks ─────────────────────────────
              if (ctrl.streakRisks.isNotEmpty) ...[
                _sectionHeader(context, 'Streaks at Risk',
                    Icons.warning_amber_rounded, tc.error),
                const SizedBox(height: 8),
                ...ctrl.streakRisks.map((r) => _riskCard(context, r)),
                const SizedBox(height: 20),
              ],

              // ── Smart Suggestions ────────────────────────
              if (ctrl.suggestions.isNotEmpty) ...[
                _sectionHeader(context, 'Suggestions',
                    Icons.lightbulb_outline, tc.accent),
                const SizedBox(height: 8),
                ...ctrl.suggestions.map((s) => _suggestionCard(context, s)),
                const SizedBox(height: 20),
              ],

              // ── Weekly Nudges ────────────────────────────
              if (ctrl.nudges.isNotEmpty) ...[
                _sectionHeader(context, 'This Week',
                    Icons.trending_up_rounded, tc.success),
                const SizedBox(height: 8),
                ...ctrl.nudges.map((n) => _nudgeCard(context, n)),
                const SizedBox(height: 20),
              ],

              // ── Persisted Tips ───────────────────────────
              if (ctrl.smartTips.isNotEmpty) ...[
                _sectionHeader(context, 'For You',
                    Icons.auto_awesome, tc.primary),
                const SizedBox(height: 8),
                ...ctrl.smartTips.map(
                  (tip) => SmartTipCard(
                    tip: tip,
                    onLike: () => ctrl.toggleTipLike(tip.id),
                    onSave: () => ctrl.toggleTipSave(tip.id),
                    onDismiss: () => ctrl.dismissTip(tip.id),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Builds a coloured section header row with an [icon] and [title].
  Widget _sectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(title,
              style: AppTextStyles.h3
                  .copyWith(fontSize: 17, color: tc.textPrimary)),
        ],
      ),
    );
  }

  /// Builds a streak-risk card showing habit name, streak count, and
  /// an urgency badge (high / medium).
  Widget _riskCard(BuildContext context, dynamic risk) {
    final tc = context.colors;
    final habitName =
        risk['habitTitle'] ?? risk['habit_title'] ?? risk['habit'] ?? 'Habit';
    final streak = risk['currentStreak'] ?? risk['current_streak'] ?? 0;
    final urgency = risk['urgency'] ?? risk['risk_level'] ?? 'medium';
    final message = risk['message'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tc.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.local_fire_department, color: tc.error, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habitName,
                    style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600, color: tc.textPrimary)),
                const SizedBox(height: 2),
                if (message.toString().isNotEmpty)
                  Text(message.toString(),
                      style: AppTextStyles.caption
                          .copyWith(color: tc.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)
                else
                  Text('$streak day streak · $urgency risk',
                      style: AppTextStyles.caption
                          .copyWith(color: tc.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: urgency == 'high'
                  ? tc.error.withValues(alpha: 0.15)
                  : tc.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              urgency.toString().toUpperCase(),
              style: TextStyle(
                color: urgency == 'high' ? tc.error : tc.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a scheduling suggestion card with an ideal time and reasoning.
  Widget _suggestionCard(BuildContext context, dynamic suggestion) {
    final tc = context.colors;
    final habitName =
        suggestion['habitTitle'] ?? suggestion['habit_title'] ?? '';
    final suggestedTime =
        suggestion['suggestedTime'] ?? suggestion['suggested_time'] ?? '';
    final reason = suggestion['reason'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tc.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule_rounded, color: tc.accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habitName.toString(),
                    style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600, color: tc.textPrimary)),
                if (suggestedTime.toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Ideal time: $suggestedTime',
                      style:
                          AppTextStyles.caption.copyWith(color: tc.accent)),
                ],
                if (reason.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reason.toString(),
                      style: AppTextStyles.caption
                          .copyWith(color: tc.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a weekly nudge card styled by its type (positive,
  /// encouragement, highlight, or neutral).
  Widget _nudgeCard(BuildContext context, dynamic nudge) {
    final tc = context.colors;
    final title = nudge['title'] ?? '';
    final message = nudge['message'] ?? '';
    final type = nudge['type'] ?? 'stable';

    Color accentColor;
    IconData icon;
    switch (type) {
      case 'positive':
        accentColor = tc.success;
        icon = Icons.celebration_rounded;
        break;
      case 'encouragement':
        accentColor = tc.warning;
        icon = Icons.fitness_center_rounded;
        break;
      case 'highlight':
        accentColor = tc.primary;
        icon = Icons.star_rounded;
        break;
      default:
        accentColor = tc.info;
        icon = Icons.trending_flat_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toString(),
                    style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600, color: tc.textPrimary)),
                const SizedBox(height: 4),
                Text(message.toString(),
                    style: AppTextStyles.bodyMd
                        .copyWith(color: tc.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the introductory header shown at the top of the tips list.
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

  /// Empty-state widget shown when no smart tips are available yet.
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
