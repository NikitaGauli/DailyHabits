// **home_page.dart** — Main Home Screen for DailyHabits
//
// This file serves as the primary entry point for the authenticated user
// experience. It orchestrates the top-level navigation between six main
// tabs (Dashboard, Gamification, Community, Notifications, Insights, Profile) via an
// [IndexedStack] and a custom bottom navigation bar.
//
// The **Dashboard** tab is the default view. It renders the user's daily
// habit list, a hero progress card, quick-stat tiles, category filter chips,
// upcoming reminders, and a floating action button for creating new habits.
//
// The **Profile** tab is built inline with settings shortcuts for
// Appearance, Privacy, Help & Support, and a secure logout flow.
//
// State is managed through [HomeController] (a [ChangeNotifier] provided
// via the `provider` package). Data is eagerly refreshed in [initState] to
// guarantee the current user's context after login/signup/logout.
//
// See also:
//   - [HomeController] for business logic and data loading.
//   - [CreateEditHabitSheet] for the modal habit creation/edit form.
//   - [HabitDetailScreen] for individual habit drill-down.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dailyhabits/models/habit.dart';
import 'package:dailyhabits/widgets/home/create_edit_habit_sheet.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/analytics/analytics_controller.dart';
import 'package:dailyhabits/screens/settings/settings_screen.dart';
import 'package:dailyhabits/screens/settings/settings_controller.dart';
import 'package:dailyhabits/screens/settings/pages/appearance_page.dart';
import 'package:dailyhabits/screens/settings/pages/privacy_policy_page.dart';
import 'package:dailyhabits/screens/settings/pages/help_support_page.dart';
import 'package:dailyhabits/screens/community/community_screen.dart';
import 'package:dailyhabits/screens/notifications/notification_screen.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';
import 'package:dailyhabits/screens/notifications/widgets/notification_banner.dart';
import 'package:dailyhabits/screens/insights/insight_screen.dart';
import 'package:dailyhabits/screens/habits/habit_detail_screen.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';
import 'package:dailyhabits/widgets/common/animated_completion.dart';
import 'package:dailyhabits/widgets/common/shimmer_loading.dart';
import 'package:dailyhabits/widgets/common/ui_components.dart';
import 'package:provider/provider.dart';
import 'home_controller.dart';
import 'package:dailyhabits/screens/gamification/gamification_screen.dart';
import 'package:dailyhabits/screens/gamification/gamification_controller.dart';
import 'package:dailyhabits/screens/gamification/widgets/xp_celebration_overlay.dart';
import 'package:dailyhabits/models/gamification_models.dart';

// =============================================================================
// HomePage Widget
// =============================================================================

/// The root screen of the authenticated app experience.
///
/// [HomePage] manages five tabs through an [IndexedStack] and a custom
/// bottom navigation bar. On first build it triggers a full data reload
/// via [HomeController.loadData] to ensure user-specific freshness.
///
/// The widget uses [TickerProviderStateMixin] to drive an entrance
/// animation on the greeting header.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  /// Controller for the greeting header fade-in animation.
  late AnimationController _greetingAnim;

  /// Curved fade animation derived from [_greetingAnim].
  late Animation<double> _greetingFade;

  /// Timer that periodically refreshes the notification badge count.
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _greetingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _greetingFade = CurvedAnimation(parent: _greetingAnim, curve: Curves.easeOut);
    _greetingAnim.forward();

    // Always reload data with the CURRENT user's token.
    // This is critical for multi-user correctness: the HomeController is a
    // singleton, so after login/signup/logout its in-memory state may belong
    // to the previous user.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().loadData();
      final notifCtrl = context.read<NotificationController>();
      notifCtrl.refreshBadge();
      notifCtrl.connectWebSocket();  // Establish real-time WebSocket connection

      // Show an in-app banner whenever a real-time notification arrives
      notifCtrl.onNewRealtimeNotification = (notification) {
        if (mounted) {
          NotificationBanner.show(context, notification: notification);
        }
      };

      context.read<GamificationController>().loadData();
    });

    // Refresh the notification badge every 60 seconds so the count stays
    // current even when the user doesn't visit the Inbox tab.
    _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context.read<NotificationController>().refreshBadge();
      }
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _greetingAnim.dispose();
    // Clear the banner callback to avoid stale references
    try {
      context.read<NotificationController>().onNewRealtimeNotification = null;
    } catch (_) {}
    super.dispose();
  }

  /// Opens a modal bottom sheet for creating a new habit or editing an
  /// existing one.
  ///
  /// When [habit] is `null`, the sheet operates in creation mode and calls
  /// [HomeController.addNewHabit]. Otherwise it updates via
  /// [HomeController.updateExistingHabit].
  void _showForm({Habit? habit, required HomeController controller}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEditHabitSheet(
        habit: habit,
        onSave: (h) async {
          if (habit == null) {
            await controller.addNewHabit(h);
          } else {
            await controller.updateExistingHabit(h.copyWith(id: habit.id));
          }
        },
      ),
    );
  }

  /// Performs a full logout flow.
  ///
  /// Clears in-memory state via [HomeController.logout], resets the
  /// notification badge, and navigates to [LoginScreen] while removing
  /// the entire navigation stack.
  void _logout(HomeController controller) async {
    await controller.logout();
    if (mounted) {
      context.read<NotificationController>().reset();
      Navigator.pushAndRemoveUntil(
        context,
        AppPageRoute.fade(const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Consumer<HomeController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return Scaffold(
            backgroundColor: tc.bg,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shimmer greeting header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              ShimmerBox(width: 100, height: 14),
                              SizedBox(height: 8),
                              ShimmerBox(width: 160, height: 24),
                            ],
                          ),
                        ),
                        const ShimmerBox.circle(radius: 22),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Shimmer progress card
                    const ShimmerBox(
                      height: 120,
                      borderRadius: 24,
                    ),
                    const SizedBox(height: 20),
                    // Shimmer stats row
                    Row(
                      children: List.generate(4, (_) => const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: ShimmerBox(
                            height: 80,
                            borderRadius: 16,
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 24),
                    // Shimmer habit cards
                    const ShimmerHabitList(count: 4),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: tc.bg,
          body: IndexedStack(
            index: controller.selectedIndex,
            children: [
              _buildDashboard(controller),
              const GamificationScreen(),
              const CommunityScreen(),
              const NotificationScreen(),
              const InsightScreen(),
              _buildProfile(controller),
            ],
          ),
          floatingActionButton: controller.selectedIndex == 0
              ? FloatingActionButton(
                  onPressed: () => _showForm(controller: controller),
                  backgroundColor: tc.primary,
                  elevation: 4,
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                )
              : null,
          bottomNavigationBar: _buildBottomNav(controller),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DASHBOARD — Primary tab with habits, progress, and reminders
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the main dashboard view (tab index 0).
  ///
  /// Composed of seven vertical sections inside a pull-to-refresh wrapper:
  ///   1. Greeting header with user avatar
  ///   2. Hero progress card (gradient ring + bar)
  ///   3. Quick stats row (Streak / Record / Done / Remaining)
  ///   4. Category filter chips (only when >1 habit exists)
  ///   5. "Today" section header with habit count badge
  ///   6. Habit cards list (or empty-state placeholder)
  ///   7. Upcoming reminders list
  Widget _buildDashboard(HomeController controller) {
    final tc = context.colors;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.loadData,
        color: tc.primary,
        backgroundColor: tc.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Header ──────────────────────────────
              _buildGreetingHeader(controller),
              const SizedBox(height: 20),

              // ── 2. Hero Progress Card ──────────────────
              _buildHeroProgressCard(controller),
              const SizedBox(height: 16),

              // ── 2b. Motivational Message ───────────────
              _buildMotivationalMessage(controller),
              const SizedBox(height: 20),

              // ── 3. Quick Stats Row ─────────────────────
              _buildQuickStatsRow(controller),
              const SizedBox(height: 24),

              // ── 4. Category Filter Chips ───────────────
              if (controller.todayHabits.length > 1)
                _buildCategoryChips(controller),
              if (controller.todayHabits.length > 1)
                const SizedBox(height: 20),

              // ── 5. Section Header ──────────────────────
              _buildSectionHeader(
                title: 'Today',
                count: controller.filteredHabits.length,
                onAdd: () => _showForm(controller: controller),
              ),
              const SizedBox(height: 12),

              // ── 6. Habit Cards ─────────────────────────
              if (controller.filteredHabits.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.filteredHabits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final habit = controller.filteredHabits[index];
                    return _buildHabitCard(habit, controller);
                  },
                ),

              // ── 7. Upcoming Reminders ──────────────────
              if (controller.upcomingReminders.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildSectionHeader(title: 'Coming Up'),
                const SizedBox(height: 12),
                _buildRemindersList(controller),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. GREETING HEADER ───────────────────────────────────────────────────

  /// Builds the top greeting row with a time-of-day-aware salutation,
  /// the user's display name, and a tappable avatar that navigates to
  /// the Profile tab.
  Widget _buildGreetingHeader(HomeController controller) {
    final tc = context.colors;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Morning'
        : (hour < 17 ? 'Afternoon' : 'Evening');

    return FadeTransition(
      opacity: _greetingFade,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: tc.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.userName,
                  style: AppTextStyles.h1.copyWith(
                    color: tc.textPrimary,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.changeNavigationIndex(4),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tc.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: tc.primary.withValues(alpha: 0.1),
                child: Text(
                  controller.userName.isNotEmpty
                      ? controller.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: tc.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. HERO PROGRESS CARD ───────────────────────────────────────────────

  /// Renders the hero-style gradient progress card.
  ///
  /// Displays a circular progress ring (animated via [TweenAnimationBuilder]),
  /// a textual summary ("X of Y completed"), and a linear progress bar.
  /// The gradient shifts to a success colour when all habits are done.
  Widget _buildHeroProgressCard(HomeController controller) {
    final tc = context.colors;
    final pct = (controller.todayProgress * 100).toInt();
    final allDone = controller.completedHabits == controller.totalHabits &&
        controller.totalHabits > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: allDone
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.85)]
              : [tc.primary, tc.primary.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (allDone ? AppColors.success : tc.primary)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: controller.todayProgress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    );
                  },
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? 'All done for today! 🎉' : 'Your progress today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.completedHabits} of ${controller.totalHabits} completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // Mini progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: controller.todayProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. QUICK STATS ROW ──────────────────────────────────────────────────

  /// Builds a horizontal row of four compact stat cards with gradient
  /// accent backgrounds: **Streak**, **Record**, **Done**, and **Remaining**.
  Widget _buildQuickStatsRow(HomeController controller) {
    return Row(
      children: [
        Expanded(
          child: GradientStatChip(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '${controller.currentStreak}',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientStatChip(
            icon: Icons.emoji_events_rounded,
            label: 'Record',
            value: '${controller.bestStreak}',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientStatChip(
            icon: Icons.check_circle_rounded,
            label: 'Done',
            value: '${controller.completedHabits}',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientStatChip(
            icon: Icons.pending_actions_rounded,
            label: 'Left',
            value: '${controller.totalHabits - controller.completedHabits}',
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }

  // ─── 3b. MOTIVATIONAL MESSAGE ──────────────────────────────────────────

  /// Context-aware motivational message based on today's progress.
  ///
  /// Shows different messages based on completion percentage, streak,
  /// and time of day — making the app feel alive and encouraging.
  Widget _buildMotivationalMessage(HomeController controller) {
    final tc = context.colors;
    final pct = controller.todayProgress;
    final streak = controller.currentStreak;

    // Pick message and icon based on progress state
    String message;
    IconData icon;
    Color accentColor;

    if (controller.totalHabits == 0) {
      message = 'Start building habits today! Add your first one below.';
      icon = Icons.tips_and_updates_rounded;
      accentColor = tc.info;
    } else if (pct >= 1.0) {
      final celebrations = [
        'Perfect day! You\'re crushing it! 🎉',
        'All done! Your consistency is incredible! 🌟',
        'Every habit completed — you\'re unstoppable! 💪',
        'Flawless! Keep this momentum going! 🔥',
      ];
      message = celebrations[DateTime.now().day % celebrations.length];
      icon = Icons.celebration_rounded;
      accentColor = AppColors.success;
    } else if (pct >= 0.75) {
      message = 'Almost there! Just a few more habits to go!';
      icon = Icons.trending_up_rounded;
      accentColor = AppColors.secondary;
    } else if (pct >= 0.5) {
      message = 'Halfway done — keep the momentum going!';
      icon = Icons.speed_rounded;
      accentColor = tc.primary;
    } else if (streak > 7) {
      message = '$streak-day streak! Don\'t break the chain!';
      icon = Icons.local_fire_department_rounded;
      accentColor = AppColors.warning;
    } else {
      final tips = [
        'Small steps lead to big changes. Start now!',
        'The best time to start is right now.',
        'Every habit completed is a vote for your future self.',
        'Consistency beats perfection. Keep showing up!',
      ];
      message = tips[DateTime.now().hour % tips.length];
      icon = Icons.lightbulb_outline_rounded;
      accentColor = tc.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: tc.isDark ? 0.12 : 0.06),
            accentColor.withValues(alpha: tc.isDark ? 0.06 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. CATEGORY FILTER CHIPS ─────────────────────────────────────────────

  /// Builds a horizontally scrollable row of category filter chips.
  ///
  /// Tapping a chip calls [HomeController.selectCategory], which updates
  /// [HomeController.filteredHabits] and triggers a UI rebuild.
  Widget _buildCategoryChips(HomeController controller) {
    final tc = context.colors;
    final cats = controller.categories;
    final selected = controller.selectedCategory ?? 'All';

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final isActive = cat == selected;

          return GestureDetector(
            onTap: () => controller.selectCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? tc.primary : tc.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? tc.primary : tc.border.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isActive ? Colors.white : tc.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── 5. SECTION HEADER ────────────────────────────────────────────────────

  /// A reusable section heading with an optional count badge and add button.
  ///
  /// - [title] — the section label (e.g. "Today", "Coming Up").
  /// - [count] — if provided, displayed as a small pill badge.
  /// - [onAdd] — if provided, a ⊕ icon button is shown on the trailing edge.
  Widget _buildSectionHeader({
    required String title,
    int? count,
    VoidCallback? onAdd,
  }) {
    final tc = context.colors;

    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.h3.copyWith(
            color: tc.textPrimary,
            fontSize: 18,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tc.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: tc.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tc.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_rounded, color: tc.primary, size: 20),
            ),
          ),
      ],
    );
  }

  // ─── 6. HABIT CARD ────────────────────────────────────────────────────────

  /// Builds a single habit card row inside a [Dismissible] wrapper.
  ///
  /// Features:
  ///   - Swipe-to-delete with a confirmation dialog.
  ///   - Tap navigates to [HabitDetailScreen] and refreshes on pop.
  ///   - Circular toggle button for marking completion, with a snackbar.
  ///   - Visual metadata: category pill, scheduled time, streak flame icon.
  ///   - Strike-through styling when the habit is already completed.
  Widget _buildHabitCard(Habit habit, HomeController controller) {
    final tc = context.colors;
    final isDone = habit.isCompleted;
    final streakCount = habit.currentStreak;

    return Dismissible(
      key: Key(habit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Habit?'),
            content: Text('Remove "${habit.title}" permanently?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => controller.removeHabit(habit.id),
      child: GestureDetector(
        onTap: () {
          final analyticsCtrl = context.read<AnalyticsController>();
          Navigator.push(
            context,
            AppPageRoute.slideRight(HabitDetailScreen(
              habit: habit,
              onToggle: () {
                controller.loadData();
                analyticsCtrl.refresh();
              },
              onDelete: () => controller.loadData(),
            )),
          ).then((_) {
            controller.loadData();
            analyticsCtrl.refresh();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDone
                  ? AppColors.success.withValues(alpha: 0.4)
                  : tc.border.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Habit icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: habit.color.withValues(alpha: isDone ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  habit.icon,
                  color: isDone
                      ? habit.color.withValues(alpha: 0.5)
                      : habit.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // ── Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        color: isDone ? tc.textMuted : tc.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: tc.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: habit.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            habit.category,
                            style: TextStyle(
                              color: habit.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (habit.time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.schedule_rounded, size: 12, color: tc.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            habit.time,
                            style: TextStyle(color: tc.textMuted, fontSize: 11),
                          ),
                        ],
                        if (streakCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 12,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$streakCount',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Completion toggle
              GestureDetector(
                onTap: () async {
                  final result = await controller.toggleHabitAsync(habit);
                  if (result != null && mounted) {
                    final isNowDone = result['isCompleted'] == true;

                    // Show XP celebration overlay if gamification data is present
                    if (isNowDone && result['gamification'] != null) {
                      final gamResult = GamificationResult.fromJson(
                        result['gamification'] as Map<String, dynamic>,
                      );
                      if (mounted) {
                        XPCelebrationOverlay.show(context, gamResult);
                        // Refresh gamification dashboard in background
                        context.read<GamificationController>().loadData();
                        // Refresh analytics so data reflects the completion
                        context.read<AnalyticsController>().refresh();
                      }
                    } else {
                      // Show completion celebration for non-gamification completions
                      if (isNowDone) {
                        CompletionCelebration.show(context, color: habit.color);
                      }
                      // Refresh analytics for uncomplete or non-gamification toggle
                      if (mounted) {
                        context.read<AnalyticsController>().refresh();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isNowDone
                                ? '${habit.title} — done ✓'
                                : '${habit.title} — unmarked',
                          ),
                          backgroundColor: isNowDone ? AppColors.success : tc.textMuted,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? AppColors.success : Colors.transparent,
                    border: Border.all(
                      color: isDone ? AppColors.success : tc.border,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 7. REMINDERS LIST ────────────────────────────────────────────────────

  /// Renders the list of upcoming (future-time) reminders for incomplete
  /// habits, sorted chronologically. Each item shows a notification icon,
  /// the habit title, and the scheduled time in a pill badge.
  Widget _buildRemindersList(HomeController controller) {
    final tc = context.colors;

    return Column(
      children: controller.upcomingReminders.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tc.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.border.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: tc.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tc.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.time,
                  style: TextStyle(
                    color: tc.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────────────────────

  /// Displays a friendly empty-state illustration when the user has no
  /// habits configured for today, prompting them to tap the FAB.
  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.add_task_rounded,
      title: 'No habits yet',
      subtitle: 'Tap + to add your first habit\nand build a daily routine.',
      actionLabel: 'Create Habit',
      onAction: () {
        final controller = context.read<HomeController>();
        _showForm(controller: controller);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the custom five-tab bottom navigation bar.
  ///
  /// Tabs: Home · Community · Inbox (with unread badge) · Insights · Profile.
  /// The Inbox item wraps its icon in a [Badge] widget driven by
  /// [NotificationController.unreadCount].
  Widget _buildBottomNav(HomeController controller) {
    final tc = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        border: Border(
          top: BorderSide(color: tc.border.withValues(alpha: 0.15), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(controller, Icons.home_rounded, 'Home', 0),
              _navItem(controller, Icons.rocket_launch_rounded, 'Gamify', 1),
              _navItem(controller, Icons.people_rounded, 'Community', 2),
              _navItem(controller, Icons.notifications_rounded, 'Inbox', 3),
              _navItem(controller, Icons.bar_chart_rounded, 'Insights', 4),
              _navItem(controller, Icons.person_rounded, 'Profile', 5),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single bottom-nav item with active/inactive styling, an
  /// animated indicator dot, and an optional notification badge (for the
  /// Inbox tab at index 3).
  Widget _navItem(
    HomeController controller,
    IconData icon,
    String label,
    int index,
  ) {
    final tc = context.colors;
    final active = controller.selectedIndex == index;

    return GestureDetector(
      onTap: () => controller.changeNavigationIndex(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.short,
        curve: AppCurves.smooth,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? tc.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wrap Inbox icon (index 3) with a badge
            if (index == 3)
              Consumer<NotificationController>(
                builder: (context, notifCtrl, child) {
                  final count = notifCtrl.unreadCount;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: tc.error,
                    child: child!,
                  );
                },
                child: Icon(
                  icon,
                  color: active ? tc.primary : tc.textMuted,
                  size: 22,
                ),
              )
            else
              Icon(
                icon,
                color: active ? tc.primary : tc.textMuted,
                size: 22,
              ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppDurations.short,
              style: TextStyle(
                color: active ? tc.primary : tc.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
            // Active indicator dot
            AnimatedContainer(
              duration: AppDurations.short,
              curve: AppCurves.smooth,
              margin: const EdgeInsets.only(top: 3),
              width: active ? 4 : 0,
              height: active ? 4 : 0,
              decoration: BoxDecoration(
                color: tc.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PROFILE TAB — User info, stats, settings shortcuts, and logout
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the Profile tab (tab index 4).
  ///
  /// Displays the user avatar, name, tagline, a stats row (Habits / Streak /
  /// Record), quick-access settings options, and a logout button.
  Widget _buildProfile(HomeController controller) {
    final tc = context.colors;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tc.primary, width: 2.5),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: tc.primary.withValues(alpha: 0.1),
                child: Text(
                  controller.userName.isNotEmpty
                      ? controller.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 40,
                    color: tc.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              controller.userName,
              style: AppTextStyles.h2.copyWith(color: tc.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'One habit at a time.',
              style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
            ),
            const SizedBox(height: 24),

            // Profile stats row
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tc.border.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _profileStat('${controller.totalHabits}', 'Habits', tc),
                  Container(width: 1, height: 30, color: tc.border.withValues(alpha: 0.2)),
                  _profileStat('${controller.currentStreak}', 'Streak', tc),
                  Container(width: 1, height: 30, color: tc.border.withValues(alpha: 0.2)),
                  _profileStat('${controller.bestStreak}', 'Record', tc),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _profileOption(Icons.settings_rounded, 'Settings', 'Alerts, reminders, quiet hours', tc, onTap: () {
              Navigator.push(context, AppPageRoute.slideRight(
                ChangeNotifierProvider(
                  create: (_) => SettingsController(),
                  child: const SettingsScreen(),
                ),
              ));
            }),
            _profileOption(Icons.palette_outlined, 'Appearance', 'Light, dark, or system theme', tc, onTap: () {
              Navigator.push(context, AppPageRoute.slideRight(
                ChangeNotifierProvider(
                  create: (_) => SettingsController(),
                  child: const AppearancePage(),
                ),
              ));
            }),
            _profileOption(Icons.shield_outlined, 'Privacy', 'Manage your data', tc, onTap: () {
              Navigator.push(context, AppPageRoute.slideRight(
                ChangeNotifierProvider(
                  create: (_) => SettingsController(),
                  child: const PrivacyPolicyPage(),
                ),
              ));
            }),
            _profileOption(Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact', tc, onTap: () {
              Navigator.push(context, AppPageRoute.slideRight(
                ChangeNotifierProvider(
                  create: (_) => SettingsController(),
                  child: const HelpSupportPage(),
                ),
              ));
            }),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _logout(controller),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a single numeric stat with a label inside the profile stats row.
  Widget _profileStat(String value, String label, ThemeColors tc) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: tc.textMuted, fontSize: 12)),
      ],
    );
  }

  /// Builds a tappable settings/option row with an icon, title, subtitle,
  /// and a trailing chevron. Used for Settings, Appearance, Privacy, etc.
  Widget _profileOption(
    IconData icon,
    String title,
    String subtitle,
    ThemeColors tc, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tc.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tc.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: tc.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tc.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
