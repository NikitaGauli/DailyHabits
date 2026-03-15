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
import 'package:dailyhabits/widgets/common/shimmer_loading.dart';
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
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 160, height: 26, borderRadius: 8),
                    const SizedBox(height: 20),
                    const ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const ShimmerBox(width: double.infinity, height: 120, borderRadius: 20),
                    const SizedBox(height: 16),
                    const ShimmerBox(width: double.infinity, height: 120, borderRadius: 20),
                  ],
                ),
              ),
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

  bool _challengesLoaded = false;

  Widget _buildChallengesTab(GamificationController ctrl) {
    final tc = context.colors;

    // Load challenges on first visit
    if (!_challengesLoaded) {
      _challengesLoaded = true;
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
          // Create challenge button
          _buildCreateChallengeButton(ctrl),
          const SizedBox(height: 20),

          // My challenges
          _sectionHeader('My Challenges', Icons.emoji_events_rounded),
          const SizedBox(height: 12),
          if (ctrl.myChallenges.isEmpty)
            _emptyStateWithIcon(
              Icons.flag_outlined,
              'No Active Challenges',
              'Create or join a challenge to start competing!',
            )
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
            _emptyStateWithIcon(
              Icons.people_outline_rounded,
              'No Community Challenges',
              'Check back later for new challenges!',
            )
          else
            ...ctrl.communityChallenges.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChallengeCard(
                  challenge: c,
                  showJoinButton: true,
                  onJoin: () async {
                    final success = await ctrl.joinChallenge(c.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Joined "${c.title}"!'
                                : 'Could not join "${c.title}". It may be full.',
                          ),
                          backgroundColor: success
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Button to create a new personal challenge.
  Widget _buildCreateChallengeButton(GamificationController ctrl) {
    final tc = context.colors;

    return GestureDetector(
      onTap: () => _showCreateChallengeSheet(ctrl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tc.primary.withValues(alpha: 0.08),
              tc.secondary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tc.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tc.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_rounded, color: tc.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Challenge',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Set a personal goal and track your progress',
                    style: TextStyle(
                      color: tc.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tc.textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet for creating a new challenge.
  void _showCreateChallengeSheet(GamificationController ctrl) {
    final tc = context.colors;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedDifficulty = 'medium';
    String selectedScope = 'personal';
    String selectedCriteriaType = 'completions';
    int target = 10;
    int days = 7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 20, 24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tc.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Create Challenge',
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title field
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: tc.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Challenge Title',
                        labelStyle: TextStyle(color: tc.textMuted),
                        filled: true,
                        fillColor: tc.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tc.border.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tc.border.withValues(alpha: 0.1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description field
                    TextField(
                      controller: descController,
                      style: TextStyle(color: tc.textPrimary),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(color: tc.textMuted),
                        filled: true,
                        fillColor: tc.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tc.border.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tc.border.withValues(alpha: 0.1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scope selector
                    Text('Challenge Type',
                        style: TextStyle(
                          color: tc.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chipOption('Personal', 'personal',
                            selectedScope, (v) {
                          setSheetState(() => selectedScope = v);
                        }),
                        _chipOption('Community', 'community',
                            selectedScope, (v) {
                          setSheetState(() => selectedScope = v);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Goal type selector
                    Text('Goal Type',
                        style: TextStyle(
                          color: tc.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chipOption('Completions', 'completions',
                            selectedCriteriaType, (v) {
                          setSheetState(() => selectedCriteriaType = v);
                        }),
                        _chipOption('Streak', 'streak',
                            selectedCriteriaType, (v) {
                          setSheetState(() => selectedCriteriaType = v);
                        }),
                        _chipOption('Perfect Days', 'all_done_days',
                            selectedCriteriaType, (v) {
                          setSheetState(() => selectedCriteriaType = v);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Target & Duration
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target',
                                  style: TextStyle(
                                    color: tc.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 8),
                              _numberSelector(target, 1, 200, (v) {
                                setSheetState(() => target = v);
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Duration (days)',
                                  style: TextStyle(
                                    color: tc.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 8),
                              _numberSelector(days, 1, 90, (v) {
                                setSheetState(() => days = v);
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Difficulty selector
                    Text('Difficulty',
                        style: TextStyle(
                          color: tc.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chipOption('Easy', 'easy', selectedDifficulty, (v) {
                          setSheetState(() => selectedDifficulty = v);
                        }),
                        _chipOption('Medium', 'medium', selectedDifficulty, (v) {
                          setSheetState(() => selectedDifficulty = v);
                        }),
                        _chipOption('Hard', 'hard', selectedDifficulty, (v) {
                          setSheetState(() => selectedDifficulty = v);
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Create button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: ctrl.isActioning
                            ? null
                            : () async {
                                if (titleController.text.trim().isEmpty) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final now = DateTime.now();
                                final challenge = await ctrl.createChallenge(
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  scope: selectedScope,
                                  difficulty: selectedDifficulty,
                                  startDate: now,
                                  endDate: now.add(Duration(days: days)),
                                  target: target,
                                  criteriaType: selectedCriteriaType,
                                  maxParticipants: selectedScope == 'community' ? 50 : 1,
                                );
                                if (challenge != null && ctx.mounted) {
                                  Navigator.pop(ctx);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Challenge created!'),
                                      backgroundColor: const Color(0xFF22C55E),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tc.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: ctrl.isActioning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create Challenge',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chipOption(
      String label, String value, String selected, ValueChanged<String> onTap) {
    final tc = context.colors;
    final isSelected = value == selected;

    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tc.primary.withValues(alpha: 0.12)
              : tc.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? tc.primary.withValues(alpha: 0.3)
                : tc.border.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? tc.primary : tc.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _numberSelector(
      int value, int min, int max, ValueChanged<int> onChange) {
    final tc = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove_rounded, color: tc.textMuted, size: 18),
            onPressed: value > min ? () => onChange(value - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: tc.textMuted, size: 18),
            onPressed: value < max ? () => onChange(value + 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 3 — LEADERBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  bool _leaderboardLoaded = false;

  Widget _buildLeaderboardTab(GamificationController ctrl) {
    final tc = context.colors;

    // Load leaderboard on first visit
    if (!_leaderboardLoaded) {
      _leaderboardLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.loadLeaderboard();
      });
    }

    final entries = ctrl.leaderboard?.entries ?? [];
    final top3 = entries.where((e) => e.rank <= 3).toList();
    final rest = entries.where((e) => e.rank > 3).toList();

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
          if (ctrl.leaderboard?.userRank != null) const SizedBox(height: 20),

          // Top 3 podium
          if (top3.isNotEmpty) ...[
            _buildPodium(top3),
            const SizedBox(height: 20),
          ],

          // Remaining leaderboard entries
          if (entries.isEmpty)
            _emptyStateWithIcon(
              Icons.leaderboard_outlined,
              'No Rankings Yet',
              'Complete habits to climb the leaderboard!',
            )
          else
            ...rest.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LeaderboardTile(
                  entry: e,
                  index: entries.indexOf(e),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a visual podium for the top 3 leaderboard entries.
  Widget _buildPodium(List<LeaderboardEntry> top3) {
    final tc = context.colors;

    // Arrange: 2nd place, 1st place, 3rd place
    LeaderboardEntry? first, second, third;
    for (final e in top3) {
      if (e.rank == 1) first = e;
      if (e.rank == 2) second = e;
      if (e.rank == 3) third = e;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.06),
            tc.card,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            _podiumColumn(second, '🥈', 60, const Color(0xFFC0C0C0))
          else
            const SizedBox(width: 90),
          const SizedBox(width: 8),
          if (first != null)
            _podiumColumn(first, '🥇', 80, const Color(0xFFFFD700))
          else
            const SizedBox(width: 90),
          const SizedBox(width: 8),
          if (third != null)
            _podiumColumn(third, '🥉', 48, const Color(0xFFCD7F32))
          else
            const SizedBox(width: 90),
        ],
      ),
    );
  }

  Widget _podiumColumn(
      LeaderboardEntry entry, String medal, double barHeight, Color color) {
    final tc = context.colors;

    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CircleAvatar(
            radius: entry.rank == 1 ? 28 : 22,
            backgroundColor: color.withValues(alpha: 0.2),
            backgroundImage: entry.profileImage != null
                ? NetworkImage(entry.profileImage!)
                : null,
            child: entry.profileImage == null
                ? Text(
                    entry.userName.isNotEmpty
                        ? entry.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: entry.rank == 1 ? 20 : 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            entry.userName,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Score
          Text(
            '${entry.score} pts',
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // Medal + podium bar
          Text(medal, style: TextStyle(fontSize: entry.rank == 1 ? 28 : 22)),
          Container(
            width: 60,
            height: barHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
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

  /// Enhanced empty state with icon, title, and subtitle.
  Widget _emptyStateWithIcon(IconData icon, String title, String subtitle) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tc.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: tc.primary.withValues(alpha: 0.5), size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tc.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
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
