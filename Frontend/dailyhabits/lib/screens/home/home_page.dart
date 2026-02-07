import 'package:flutter/material.dart';
import 'package:dailyhabits/models/habit.dart';
import 'package:dailyhabits/widgets/home/create_edit_habit_sheet.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/analytics/analytics_screen.dart';
import 'package:dailyhabits/screens/settings/settings_screen.dart';
import 'package:dailyhabits/screens/community/community_screen.dart';
import 'package:dailyhabits/screens/notifications/notification_screen.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';
import 'package:dailyhabits/screens/habits/habit_detail_screen.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _greetingAnim;
  late Animation<double> _greetingFade;

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
      context.read<NotificationController>().refreshBadge();
    });
  }

  @override
  void dispose() {
    _greetingAnim.dispose();
    super.dispose();
  }

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

  void _logout(HomeController controller) async {
    await controller.logout();
    if (mounted) {
      context.read<NotificationController>().reset();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
            body: Center(
              child: CircularProgressIndicator(color: tc.primary),
            ),
          );
        }

        return Scaffold(
          backgroundColor: tc.bg,
          body: IndexedStack(
            index: controller.selectedIndex,
            children: [
              _buildDashboard(controller),
              const CommunityScreen(),
              const NotificationScreen(),
              const AnalyticsScreen(),
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
  //  DASHBOARD (10/10 premium layout)
  // ═══════════════════════════════════════════════════════════════════════════

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

  Widget _buildQuickStatsRow(HomeController controller) {
    final tc = context.colors;

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Streak',
          value: '${controller.currentStreak}',
          color: AppColors.warning,
          tc: tc,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.emoji_events_rounded,
          label: 'Record',
          value: '${controller.bestStreak}',
          color: AppColors.secondary,
          tc: tc,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.check_circle_rounded,
          label: 'Done',
          value: '${controller.completedHabits}',
          color: AppColors.success,
          tc: tc,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.pending_actions_rounded,
          label: 'Remaining',
          value: '${controller.totalHabits - controller.completedHabits}',
          color: tc.textMuted,
          tc: tc,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeColors tc,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: tc.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. CATEGORY FILTER CHIPS ─────────────────────────────────────────────

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

  // ─── 6. HABIT CARD (premium) ──────────────────────────────────────────────

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(
                habit: habit,
                onToggle: () => controller.loadData(),
                onDelete: () => controller.loadData(),
              ),
            ),
          ).then((_) => controller.loadData());
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

  Widget _buildEmptyState() {
    final tc = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tc.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_task_rounded,
              size: 40,
              color: tc.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No habits yet',
            style: AppTextStyles.h3.copyWith(
              color: tc.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first habit\nand build a daily routine.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: tc.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════════════════

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
              _navItem(controller, Icons.people_rounded, 'Community', 1),
              _navItem(controller, Icons.notifications_rounded, 'Inbox', 2),
              _navItem(controller, Icons.bar_chart_rounded, 'Insights', 3),
              _navItem(controller, Icons.person_rounded, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

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
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tc.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wrap Inbox icon (index 2) with a badge
            if (index == 2)
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
            Text(
              label,
              style: TextStyle(
                color: active ? tc.primary : tc.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PROFILE TAB
  // ═══════════════════════════════════════════════════════════════════════════

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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _profileOption(Icons.palette_outlined, 'Appearance', 'Light, dark, or system theme', tc),
            _profileOption(Icons.shield_outlined, 'Privacy', 'Manage your data', tc),
            _profileOption(Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact', tc),
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
