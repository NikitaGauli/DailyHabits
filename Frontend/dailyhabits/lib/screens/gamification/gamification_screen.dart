// =============================================================================
// File: gamification_screen.dart
// Description: Main gamification hub screen for the DailyHabits app.
//              Displays XP/level progress, coin wallet, streak info, daily
//              bonus, active challenges, leaderboard preview, and recent
//              activity. Uses a tabbed layout with Dashboard, Challenges,
//              and Leaderboard sub-views.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/gamification_models.dart';
import 'gamification_controller.dart';
import 'widgets/xp_progress_ring.dart';
import 'widgets/streak_card.dart';
import 'widgets/challenge_card.dart';
import 'widgets/leaderboard_tile.dart';
import 'widgets/daily_bonus_card.dart';
import 'widgets/coin_wallet_chip.dart';
import 'widgets/xp_activity_tile.dart';

// =============================================================================
// Gamification Screen — Entry Point
// =============================================================================

/// Wraps the private view with a [ChangeNotifierProvider] that creates
/// the [GamificationController]. Data is loaded in initState so that
/// the controller can access the JWT token.
class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GamificationController(),
      child: const _GamificationView(),
    );
  }
}

// =============================================================================
// Internal View
// =============================================================================

class _GamificationView extends StatefulWidget {
  const _GamificationView();

  @override
  State<_GamificationView> createState() => _GamificationViewState();
}

class _GamificationViewState extends State<_GamificationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load data after the widget is ready (auth token available).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationController>().loadData();
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

    return Consumer<GamificationController>(
      builder: (context, ctrl, _) {
        if (ctrl.isLoading && ctrl.dashboard == null) {
          return Scaffold(
            backgroundColor: tc.bg,
            body: Center(
              child: CircularProgressIndicator(color: tc.primary),
            ),
          );
        }

        return Scaffold(
          backgroundColor: tc.bg,
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // ── Header ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildHeader(ctrl),
                  ),
                  // ── Tab Bar ─────────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      tabBar: _buildTabBar(),
                      color: tc.bg,
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(ctrl),
                  _buildChallengesTab(ctrl),
                  _buildLeaderboardTab(ctrl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER — Level ring, XP bar, coin balance
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(GamificationController ctrl) {
    final tc = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: tc.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                'Gamification',
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              CoinWalletChip(balance: ctrl.coinBalance),
            ],
          ),
          const SizedBox(height: 20),

          // Level ring + XP info
          Row(
            children: [
              // Animated XP progress ring
              XPProgressRing(
                level: ctrl.currentLevel,
                progress: ctrl.xpProgress / 100,
                size: 80,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctrl.levelName,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ctrl.currentXp} / ${ctrl.xpForNextLevel} XP',
                      style: TextStyle(
                        color: tc.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // XP progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (ctrl.xpProgress / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: tc.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(tc.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Quick stats row
                    Row(
                      children: [
                        _miniStat(
                          Icons.bolt_rounded,
                          '+${ctrl.todayXp} today',
                          const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 16),
                        _miniStat(
                          Icons.trending_up_rounded,
                          '${ctrl.streakMultiplier}x mult',
                          tc.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    final tc = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: tc.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    final tc = context.colors;

    return TabBar(
      controller: _tabController,
      indicatorColor: tc.primary,
      indicatorWeight: 3,
      labelColor: tc.primary,
      unselectedLabelColor: tc.textMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      tabs: const [
        Tab(text: 'Dashboard'),
        Tab(text: 'Challenges'),
        Tab(text: 'Leaderboard'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 1 — DASHBOARD (Daily bonus, streaks, recent XP)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab(GamificationController ctrl) {
    final tc = context.colors;

    return RefreshIndicator(
      onRefresh: ctrl.loadData,
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Daily Bonus Card
          DailyBonusCard(
            loginClaimed: ctrl.loginBonusClaimed,
            onClaimLogin: ctrl.claimDailyLogin,
            isActioning: ctrl.isActioning,
          ),
          const SizedBox(height: 16),

          // Streak & Freezes Card
          StreakCard(
            currentStreak: ctrl.currentStreak,
            bestStreak: ctrl.bestStreak,
            freezes: ctrl.freezes,
            multiplier: ctrl.streakMultiplier,
            onBuyFreeze: ctrl.buyStreakFreeze,
            isActioning: ctrl.isActioning,
          ),
          const SizedBox(height: 24),

          // Quick stats tiles
          _buildQuickStats(ctrl),
          const SizedBox(height: 24),

          // Active challenges preview
          if (ctrl.activeChallenges.isNotEmpty) ...[
            _sectionHeader('Active Challenges', Icons.flag_rounded),
            const SizedBox(height: 12),
            ...ctrl.activeChallenges.take(3).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChallengeCard(challenge: c, compact: true),
                  ),
                ),
            const SizedBox(height: 8),
          ],

          // Recent XP Activity
          _sectionHeader('Recent Activity', Icons.history_rounded),
          const SizedBox(height: 12),
          if (ctrl.recentActivity.isEmpty)
            _emptyState('Complete habits to start earning XP!')
          else
            ...ctrl.recentActivity.take(8).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: XPActivityTile(event: e),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(GamificationController ctrl) {
    final tc = context.colors;
    final dash = ctrl.dashboard;
    if (dash == null) return const SizedBox.shrink();

    return Row(
      children: [
        _statTile(
          'Total XP',
          '${dash.totalXp}',
          Icons.stars_rounded,
          const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 12),
        _statTile(
          'Week XP',
          '${dash.weekXp}',
          Icons.trending_up_rounded,
          tc.secondary,
        ),
        const SizedBox(width: 12),
        _statTile(
          'Days Active',
          '${dash.daysActive}',
          Icons.calendar_today_rounded,
          tc.primary,
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    final tc = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 18,
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 2 — CHALLENGES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChallengesTab(GamificationController ctrl) {
    final tc = context.colors;

    // Load challenges on first visit
    if (ctrl.myChallenges.isEmpty && ctrl.communityChallenges.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.loadChallenges();
      });
    }

    return RefreshIndicator(
      onRefresh: ctrl.loadChallenges,
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // My challenges
          _sectionHeader('My Challenges', Icons.emoji_events_rounded),
          const SizedBox(height: 12),
          if (ctrl.myChallenges.isEmpty)
            _emptyState('No active challenges.\nCreate one to get started!')
          else
            ...ctrl.myChallenges.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChallengeCard(challenge: c),
              ),
            ),

          const SizedBox(height: 24),

          // Community challenges
          _sectionHeader('Community Challenges', Icons.groups_rounded),
          const SizedBox(height: 12),
          if (ctrl.communityChallenges.isEmpty)
            _emptyState('No community challenges available right now.')
          else
            ...ctrl.communityChallenges.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChallengeCard(
                  challenge: c,
                  showJoinButton: true,
                  onJoin: () => ctrl.joinChallenge(c.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 3 — LEADERBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLeaderboardTab(GamificationController ctrl) {
    final tc = context.colors;

    // Load leaderboard on first visit
    if (ctrl.leaderboard == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.loadLeaderboard();
      });
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadLeaderboard(type: ctrl.leaderboardType),
      color: tc.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Period selector chips
          _buildLeaderboardPeriodSelector(ctrl),
          const SizedBox(height: 20),

          // User rank card
          if (ctrl.leaderboard?.userRank != null)
            _buildUserRankCard(ctrl.leaderboard!.userRank!),
          const SizedBox(height: 16),

          // Leaderboard entries
          if (ctrl.leaderboard == null || ctrl.leaderboard!.entries.isEmpty)
            _emptyState('No leaderboard data yet.\nComplete habits to rank up!')
          else
            ...ctrl.leaderboard!.entries.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LeaderboardTile(
                      entry: entry.value,
                      index: entry.key,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardPeriodSelector(GamificationController ctrl) {
    final tc = context.colors;
    final periods = ['weekly', 'monthly', 'alltime'];
    final labels = ['Weekly', 'Monthly', 'All Time'];

    return Row(
      children: List.generate(3, (i) {
        final selected = ctrl.leaderboardType == periods[i];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(labels[i]),
            selected: selected,
            onSelected: (_) => ctrl.loadLeaderboard(type: periods[i]),
            selectedColor: tc.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? tc.primary : tc.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            backgroundColor: tc.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected ? tc.primary.withValues(alpha: 0.3) : tc.border.withValues(alpha: 0.1),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUserRankCard(LeaderboardUserRank userRank) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tc.primary, tc.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: tc.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  userRank.rank != null ? '#${userRank.rank}' : 'Unranked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${userRank.score} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (userRank.rankChange != 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      userRank.rankChange > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: userRank.rankChange > 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      size: 14,
                    ),
                    Text(
                      '${userRank.rankChange.abs()}',
                      style: TextStyle(
                        color: userRank.rankChange > 0
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REUSABLE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    final tc = context.colors;
    return Row(
      children: [
        Icon(icon, color: tc.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tc.textMuted,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

// =============================================================================
// Tab Bar Persistent Header Delegate
// =============================================================================

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  final Color color;

  const _TabBarDelegate({required this.tabBar, required this.color});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || color != oldDelegate.color;
  }
}
