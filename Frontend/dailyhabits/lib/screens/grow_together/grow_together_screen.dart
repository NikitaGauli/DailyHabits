// =============================================================================
// File: grow_together_screen.dart
// Description: Main Grow Together screen — a tabbed hub for collaborative
//              habit sharing. Tabs: Dashboard, My Habits, Discover, Invites.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/grow_together_models.dart';
import 'grow_together_controller.dart';
import 'grow_together_detail_screen.dart';
import 'create_collaborative_habit_screen.dart';
import 'widgets/collaborative_habit_card.dart';
import 'widgets/invite_card.dart';
import 'widgets/gt_stat_card.dart';

/// Top-level entry point for the Grow Together feature.
class GrowTogetherScreen extends StatefulWidget {
  const GrowTogetherScreen({super.key});

  @override
  State<GrowTogetherScreen> createState() => _GrowTogetherScreenState();
}

class _GrowTogetherScreenState extends State<GrowTogetherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late GrowTogetherController _ctrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _ctrl = GrowTogetherController();
    _ctrl.loadDashboard();
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text('Grow Together'),
          bottom: TabBar(
            controller: _tab,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: colors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.group_work), text: 'My Habits'),
              Tab(icon: Icon(Icons.explore), text: 'Discover'),
              Tab(icon: Icon(Icons.mail), text: 'Invites'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: _ctrl,
                child: const CreateCollaborativeHabitScreen(),
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Create'),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _DashboardTab(),
            _MyHabitsTab(),
            _DiscoverTab(),
            _InvitesTab(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Dashboard Tab
// =============================================================================

class _DashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;

    if (ctrl.isLoading && ctrl.dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.error != null && ctrl.dashboard == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(ctrl.error!, style: TextStyle(color: colors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ctrl.loadDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final dash = ctrl.dashboard;

    return RefreshIndicator(
      onRefresh: () => ctrl.loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stats Row ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: GTStatCard(
                  icon: Icons.group_work,
                  label: 'Active',
                  value: '${dash?.totalActiveHabits ?? 0}',
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GTStatCard(
                  icon: Icons.check_circle,
                  label: 'Today',
                  value: '${dash?.totalCompletionsToday ?? 0}',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GTStatCard(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '${dash?.overallGroupStreak ?? 0}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Pending Invites ─────────────────────────────────────
          if (ctrl.pendingInvites.isNotEmpty) ...[
            _SectionHeader(
              title: 'Pending Invites',
              count: ctrl.pendingInvites.length,
              icon: Icons.mail,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ctrl.pendingInvites.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final invite = ctrl.pendingInvites[i];
                  return SizedBox(
                    width: 280,
                    child: InviteCard(
                      invite: invite,
                      onAccept: () => ctrl.acceptInvite(invite.id),
                      onDecline: () => ctrl.declineInvite(invite.id),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── My Habits ────────────────────────────────────────
          _SectionHeader(
            title: 'My Collaborative Habits',
            count: ctrl.myHabits.length,
            icon: Icons.group_work,
          ),
          const SizedBox(height: 8),
          if (ctrl.myHabits.isEmpty)
            _EmptyState(
              icon: Icons.group_add,
              title: 'No collaborative habits yet',
              subtitle: 'Create one or accept an invite to get started!',
            )
          else
            ...ctrl.myHabits.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CollaborativeHabitCard(
                    habit: h,
                    onTap: () => _openDetail(context, h, ctrl),
                  ),
                )),

          const SizedBox(height: 24),

          // ── Recent Activity ──────────────────────────────────
          if (dash != null && dash.recentActivity.isNotEmpty) ...[
            _SectionHeader(
              title: 'Recent Activity',
              count: dash.recentActivity.length,
              icon: Icons.timeline,
            ),
            const SizedBox(height: 8),
            ...dash.recentActivity.take(5).map((a) => _ActivityTile(log: a)),
          ],
        ],
      ),
    );
  }

  void _openDetail(
      BuildContext context, CollaborativeHabit h, GrowTogetherController ctrl) {
    ctrl.loadHabitDetail(h.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: GrowTogetherDetailScreen(habitId: h.id),
        ),
      ),
    );
  }
}

// =============================================================================
// My Habits Tab
// =============================================================================

class _MyHabitsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();

    if (ctrl.isLoading && ctrl.myHabits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.myHabits.isEmpty) {
      return _EmptyState(
        icon: Icons.group_add,
        title: 'No collaborative habits',
        subtitle: 'Tap + to create your first collaborative habit!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadMyHabits(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.myHabits.length,
        itemBuilder: (ctx, i) {
          final h = ctrl.myHabits[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CollaborativeHabitCard(
              habit: h,
              onTap: () {
                ctrl.loadHabitDetail(h.id);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: ctrl,
                      child: GrowTogetherDetailScreen(habitId: h.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Discover Tab
// =============================================================================

class _DiscoverTab extends StatefulWidget {
  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<GrowTogetherController>();
      if (ctrl.discoverableHabits.isEmpty) ctrl.loadDiscoverHabits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();
    final colors = Theme.of(context).colorScheme;

    if (ctrl.isLoadingDiscover && ctrl.discoverableHabits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.discoverableHabits.isEmpty) {
      return _EmptyState(
        icon: Icons.explore_off,
        title: 'Nothing to discover',
        subtitle: 'Check back later for public habits to join!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadDiscoverHabits(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.discoverableHabits.length,
        itemBuilder: (ctx, i) {
          final h = ctrl.discoverableHabits[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: h.color.withValues(alpha: 0.15),
                  child: Text(h.emoji, style: const TextStyle(fontSize: 20)),
                ),
                title: Text(h.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${h.memberCount} members • ${h.frequency}',
                  style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: ElevatedButton(
                  onPressed: () => ctrl.joinHabit(h.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Join'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Invites Tab
// =============================================================================

class _InvitesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GrowTogetherController>();

    if (ctrl.pendingInvites.isEmpty) {
      return _EmptyState(
        icon: Icons.mail_outline,
        title: 'No pending invites',
        subtitle: 'When friends invite you to grow together, they\'ll appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadPendingInvites(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.pendingInvites.length,
        itemBuilder: (ctx, i) {
          final invite = ctrl.pendingInvites[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InviteCard(
              invite: invite,
              onAccept: () => ctrl.acceptInvite(invite.id),
              onDecline: () => ctrl.declineInvite(invite.id),
              expanded: true,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Shared Helper Widgets
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final GTActivityLog log;
  const _ActivityTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      subtitle: Text(
        _timeAgo(log.createdAt),
        style: TextStyle(
            fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
