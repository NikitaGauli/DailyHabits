// =============================================================================
// File: grow_together_detail_screen.dart
// Description: Detail screen for a single collaborative habit — shows progress,
//              members, leaderboard, milestones, and activity feed.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/grow_together_models.dart';
import 'grow_together_controller.dart';
import 'widgets/member_list_tile.dart';
import 'widgets/progress_card.dart';
import 'widgets/leaderboard_tile.dart';
import 'widgets/milestone_card.dart';
import 'widgets/streak_calendar_widget.dart';
import 'dart:math' as math;

/// Detail screen for a single collaborative habit.
class GrowTogetherDetailScreen extends StatefulWidget {
  final String habitId;
  const GrowTogetherDetailScreen({super.key, required this.habitId});

  @override
  State<GrowTogetherDetailScreen> createState() =>
      _GrowTogetherDetailScreenState();
}

class _GrowTogetherDetailScreenState extends State<GrowTogetherDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<GrowTogetherController>();
      ctrl.loadHabitDetail(widget.habitId);
      ctrl.loadTodayProgress(widget.habitId);
      ctrl.loadMembers(widget.habitId);
      ctrl.loadStreakCalendar(widget.habitId);
      ctrl.loadStreakFreezes(widget.habitId);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;
    final habit = ctrl.selectedHabit;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(habit?.title ?? 'Loading...'),
        actions: [
          if (habit != null) ...[
            // ── Mark / Unmark Toggle ───────────────────────────
            if (!habit.todayCompleted)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Log Progress',
                onPressed: () => _showLogProgressDialog(context, ctrl, habit),
              )
            else
              IconButton(
                icon: Icon(Icons.check_circle,
                    color: AppColors.success),
                tooltip: 'Undo Progress',
                onPressed: () => _showUnmarkDialog(context, ctrl, habit),
              ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleMenuAction(context, ctrl, habit, v),
              itemBuilder: (_) => [
                if (habit.isAdmin)
                  const PopupMenuItem(
                      value: 'invite', child: Text('Invite Friends')),
                const PopupMenuItem(
                    value: 'streakFreezes', child: Text('Streak Freezes ❄️')),
                const PopupMenuItem(
                    value: 'analytics', child: Text('Analytics')),
                const PopupMenuItem(value: 'leave', child: Text('Leave')),
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
          indicatorColor: colors.primary,
          tabs: const [
            Tab(text: 'Progress'),
            Tab(text: 'Members'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Milestones'),
            Tab(text: 'Feed'),
          ],
        ),
      ),
      body: ctrl.isLoading && habit == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (habit != null) _HabitHeader(habit: habit),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _ProgressTab(habitId: widget.habitId),
                      _MembersTab(habitId: widget.habitId),
                      _LeaderboardTab(habitId: widget.habitId),
                      _MilestonesTab(habitId: widget.habitId),
                      _FeedTab(habitId: widget.habitId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showLogProgressDialog(
      BuildContext context, GrowTogetherController ctrl, CollaborativeHabit h) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Progress'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ctrl.logProgress(
                habitId: h.id,
                note: noteCtrl.text,
              );
              if (ok && context.mounted) {
                // Show celebration overlay
                final result = ctrl.lastProgressResult;
                if (result != null) {
                  _showCelebrationOverlay(context, result);
                }
                // Auto-refresh all related data
                ctrl.loadTodayProgress(h.id);
                ctrl.loadStreakCalendar(h.id);
                ctrl.loadStreakFreezes(h.id);
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showCelebrationOverlay(BuildContext context, ProgressResult result) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationOverlay(
        result: result,
        onDone: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _handleMenuAction(BuildContext context, GrowTogetherController ctrl,
      CollaborativeHabit h, String action) {
    switch (action) {
      case 'invite':
        _showInviteDialog(context, ctrl, h);
        break;
      case 'streakFreezes':
        _showStreakFreezeSheet(context, ctrl, h);
        break;
      case 'analytics':
        // Could navigate to analytics screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics coming soon!')),
        );
        break;
      case 'leave':
        _showLeaveDialog(context, ctrl, h);
        break;
      case 'report':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report feature coming soon.')),
        );
        break;
    }
  }

  /// Shows confirmation dialog to undo today's progress.
  void _showUnmarkDialog(
      BuildContext context, GrowTogetherController ctrl, CollaborativeHabit h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Progress?'),
        content: const Text(
            'This will remove today\'s completion and may affect your streak. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ctrl.unmarkProgress(habitId: h.id);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Progress unmarked.')),
                );
                ctrl.loadTodayProgress(h.id);
                ctrl.loadStreakCalendar(h.id);
              }
            },
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }

  /// Shows a bottom sheet for streak freeze management.
  void _showStreakFreezeSheet(
      BuildContext context, GrowTogetherController ctrl, CollaborativeHabit h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<GrowTogetherController>(
          builder: (_, c, _) {
            final info = c.freezeInfo;
            if (info == null) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StreakFreezeSection(
                    freezeInfo: info,
                    isLoading: c.isLoadingFreezes,
                    onPurchase: () async {
                      final ok = await c.purchaseStreakFreeze(h.id);
                      if (ok && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Streak freeze purchased! ❄️')),
                        );
                      }
                    },
                    onUse: (date) async {
                      final ok = await c.useStreakFreeze(h.id, date: date);
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Streak protected! 🛡️')),
                        );
                        c.loadStreakCalendar(h.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteDialog(
      BuildContext context, GrowTogetherController ctrl, CollaborativeHabit h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Friends'),
        content: const Text(
            'Enter friend IDs to invite (this will be replaced with a friend picker in a future update).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(
      BuildContext context, GrowTogetherController ctrl, CollaborativeHabit h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Habit?'),
        content: Text(
            'Are you sure you want to leave "${h.title}"? Your progress will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ctrl.leaveHabit(h.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Habit Header
// =============================================================================

class _HabitHeader extends StatelessWidget {
  final CollaborativeHabit habit;
  const _HabitHeader({required this.habit});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: habit.color.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: habit.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(habit.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${habit.memberCount} members • ${habit.frequency} • ${habit.privacy}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Group progress ring + Streak
          Column(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(44, 44),
                      painter: _GroupProgressRingPainter(
                        percentage: habit.groupCompletionPercent,
                        color: habit.groupCompletionPercent >= 100
                            ? AppColors.success
                            : habit.color,
                        backgroundColor:
                            colors.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    if (habit.todayCompleted)
                      Icon(Icons.check, size: 18, color: AppColors.success)
                    else
                      Text(
                        '${habit.groupCompletionPercent.round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 2),
                  Text(
                    '${habit.myStreak}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Group Progress Ring Painter
// =============================================================================

class _GroupProgressRingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  _GroupProgressRingPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeWidth = 4.0;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (percentage / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GroupProgressRingPainter old) =>
      old.percentage != percentage || old.color != color;
}

// =============================================================================
// Celebration Overlay (confetti animation)
// =============================================================================

class _CelebrationOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final ProgressResult result;

  const _CelebrationOverlay({required this.onDone, required this.result});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    _animCtrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (ctx, _) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            alignment: Alignment.center,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎉',
                          style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      const Text(
                        'Habit Complete!',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // XP earned
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '+${result.xpBreakdown.earned} XP',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.amber,
                              ),
                            ),
                            if (result.xpBreakdown.streakBonus) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${result.xpBreakdown.multiplier}x)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Streak
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${result.streak.current} day streak',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if (result.streak.increased) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_upward,
                                color: Colors.green, size: 16),
                          ],
                        ],
                      ),
                      // Group status
                      if (result.groupStatus.totalMembers > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${result.groupStatus.completedMembers}/${result.groupStatus.totalMembers} members done '
                          '(${result.groupStatus.percentage.round()}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (result.groupStatus.allComplete) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '🎊 All members completed! Team bonus!',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                      // Milestones
                      if (result.milestonesUnlocked.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final m in result.milestonesUnlocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${m.badgeEmoji} ${m.title} unlocked!',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Mark as Done Hero Button
// =============================================================================

class _MarkAsDoneButton extends StatelessWidget {
  final String habitId;

  const _MarkAsDoneButton({required this.habitId});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final habit = ctrl.selectedHabit;
    final colors = Theme.of(context).colorScheme;

    if (habit == null) return const SizedBox.shrink();
    if (habit.todayCompleted) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            Text(
              'Completed Today!',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: ctrl.isActionLoading
            ? null
            : () async {
                final ok = await ctrl.logProgress(habitId: habitId);
                if (ok && context.mounted) {
                  // Show celebration overlay
                  final result = ctrl.lastProgressResult;
                  if (result != null) {
                    _showCelebration(context, result);
                  }
                  // Auto-refresh progress + calendar
                  ctrl.loadTodayProgress(habitId);
                  ctrl.loadStreakCalendar(habitId);
                }
              },
        icon: ctrl.isActionLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_outline, size: 22),
        label: Text(
          ctrl.isActionLoading ? 'Logging...' : 'Mark as Done',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _showCelebration(BuildContext context, ProgressResult result) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationOverlay(
        result: result,
        onDone: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }
}

// =============================================================================
// Progress Tab
// =============================================================================

class _ProgressTab extends StatelessWidget {
  final String habitId;
  const _ProgressTab({required this.habitId});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ctrl.loadTodayProgress(habitId),
          ctrl.loadStreakCalendar(habitId),
          ctrl.loadStreakFreezes(habitId),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          // ── Mark as Done Button ──────────────────────────────
          SliverToBoxAdapter(
            child: _MarkAsDoneButton(habitId: habitId),
          ),

          // ── Streak Calendar Section ──────────────────────────
          if (ctrl.isLoadingCalendar && ctrl.streakCalendar == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (ctrl.streakCalendar != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: StreakCalendarWidget(
                  calendar: ctrl.streakCalendar!,
                  freezeInfo: ctrl.freezeInfo,
                  isLoadingFreezes: ctrl.isLoadingFreezes,
                  onPurchaseFreeze: () =>
                      ctrl.purchaseStreakFreeze(habitId),
                  onUseFreeze: (date) =>
                      ctrl.useStreakFreeze(habitId, date: date),
                ),
              ),
            ),

          // ── Section Divider ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  if (ctrl.todayProgress.isNotEmpty)
                    Text(
                      '${ctrl.todayProgress.where((p) => p.completed).length}/${ctrl.todayProgress.length} completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Progress List ────────────────────────────────────
          if (ctrl.isLoadingProgress && ctrl.todayProgress.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (ctrl.todayProgress.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_actions,
                        size: 48,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No progress logged today',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the check icon to mark your habit done!',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProgressCard(
                      progress: ctrl.todayProgress[i],
                      onReact: (type) =>
                          ctrl.toggleReaction(ctrl.todayProgress[i].id, type),
                    ),
                  ),
                  childCount: ctrl.todayProgress.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Members Tab
// =============================================================================

class _MembersTab extends StatelessWidget {
  final String habitId;
  const _MembersTab({required this.habitId});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();

    if (ctrl.isLoadingMembers && ctrl.members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadMembers(habitId),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.members.length,
        itemBuilder: (ctx, i) {
          return MemberListTile(member: ctrl.members[i]);
        },
      ),
    );
  }
}

// =============================================================================
// Leaderboard Tab
// =============================================================================

class _LeaderboardTab extends StatefulWidget {
  final String habitId;
  const _LeaderboardTab({required this.habitId});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowTogetherController>().loadLeaderboard(widget.habitId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();

    if (ctrl.isLoadingLeaderboard && ctrl.leaderboard.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.leaderboard.isEmpty) {
      return const Center(child: Text('No leaderboard data yet.'));
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadLeaderboard(widget.habitId),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.leaderboard.length,
        itemBuilder: (ctx, i) {
          return LeaderboardTile(entry: ctrl.leaderboard[i]);
        },
      ),
    );
  }
}

// =============================================================================
// Milestones Tab
// =============================================================================

class _MilestonesTab extends StatefulWidget {
  final String habitId;
  const _MilestonesTab({required this.habitId});

  @override
  State<_MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<_MilestonesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowTogetherController>().loadMilestones(widget.habitId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();

    if (ctrl.isLoadingMilestones && ctrl.milestones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.milestones.isEmpty) {
      return const Center(child: Text('No milestones unlocked yet.'));
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadMilestones(widget.habitId),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.milestones.length,
        itemBuilder: (ctx, i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MilestoneCard(milestone: ctrl.milestones[i]),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Feed Tab
// =============================================================================

class _FeedTab extends StatefulWidget {
  final String habitId;
  const _FeedTab({required this.habitId});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<GrowTogetherController>()
          .loadHabitFeed(widget.habitId, refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;

    if (ctrl.isLoadingFeed && ctrl.activityFeed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.activityFeed.isEmpty) {
      return const Center(child: Text('No activity yet.'));
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadHabitFeed(widget.habitId, refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.activityFeed.length,
        itemBuilder: (ctx, i) {
          final log = ctrl.activityFeed[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              child: Icon(log.actionIcon, size: 16, color: colors.primary),
            ),
            title: Text(
              '${log.actor?.displayName ?? 'Someone'} ${log.actionLabel}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: log.description.isNotEmpty
                ? Text(log.description,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)
                : null,
          );
        },
      ),
    );
  }
}

// =============================================================================
// Streak Freeze Section (for bottom sheet)
// =============================================================================

class _StreakFreezeSection extends StatelessWidget {
  final StreakFreezeInfo freezeInfo;
  final bool isLoading;
  final VoidCallback? onPurchase;
  final Function(String? date)? onUse;

  const _StreakFreezeSection({
    required this.freezeInfo,
    this.isLoading = false,
    this.onPurchase,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.lightBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.ac_unit, size: 22, color: Colors.lightBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Streak Freezes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  Text(
                    'Protect your streak when you miss a day',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: freezeInfo.availableCount > 0
                    ? Colors.lightBlue.withValues(alpha: 0.12)
                    : colors.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${freezeInfo.availableCount} / ${freezeInfo.maxFreezes}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: freezeInfo.availableCount > 0
                      ? Colors.lightBlue
                      : colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Freeze tokens visual
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            freezeInfo.maxFreezes,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: i < freezeInfo.availableCount
                      ? Colors.lightBlue.withValues(alpha: 0.15)
                      : colors.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i < freezeInfo.availableCount
                        ? Colors.lightBlue.withValues(alpha: 0.3)
                        : colors.onSurface.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.ac_unit,
                  size: 24,
                  color: i < freezeInfo.availableCount
                      ? Colors.lightBlue
                      : colors.onSurface.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    freezeInfo.canPurchase && !isLoading ? onPurchase : null,
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text('Buy (${freezeInfo.freezeCostXp} XP)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                      color: Colors.lightBlue.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: freezeInfo.availableCount > 0 && !isLoading
                    ? () => onUse?.call(null)
                    : null,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Use Freeze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),

        // Used freezes history
        if (freezeInfo.used.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recently Used',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          ...freezeInfo.used.take(5).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.ac_unit,
                        size: 14,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 8),
                    Text(
                      'Used on ${f.usedOnDate ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f.source,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}