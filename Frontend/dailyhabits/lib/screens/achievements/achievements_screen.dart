// =============================================================================
// File: achievements_screen.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: Displays the user’s gamification profile: current level, XP
//              progress bar, and a grid of badge-style achievement cards.
//              Badges glow and gain colour when unlocked. Data is sourced from
//              [AchievementsController] via Provider.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'achievements_controller.dart';
import '../../models/achievement.dart';

/// Top-level entry point for the Achievements feature.
///
/// Wraps the private [_AchievementsView] with a [ChangeNotifierProvider]
/// that creates an [AchievementsController] for data management.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AchievementsController(),
      child: const _AchievementsView(),
    );
  }
}

/// Internal scrollable view that displays the achievements UI.
///
/// Layout (top to bottom):
/// 1. **Header** — title and descriptive subtitle.
/// 2. **Level Card** — gradient card showing the user’s current level,
///    level name, XP progress bar, and XP-to-next-level label.
/// 3. **Badge Grid** — 3-column grid of [Achievement] items, each styled
///    with a glow effect when unlocked.
class _AchievementsView extends StatelessWidget {
  const _AchievementsView();

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final controller = Provider.of<AchievementsController>(context);

    if (controller.isLoading) {
      return Scaffold(
        backgroundColor: tc.bg,
        body: Center(
          child: CircularProgressIndicator(color: tc.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    if (controller.userLevel != null)
                      _buildLevelCard(context, controller.userLevel!),
                    const SizedBox(height: 32),
                    Text(
                      'Badges',
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _buildAchievementItem(
                      context,
                      controller,
                      controller.achievements[index],
                    );
                  }, childCount: controller.achievements.length),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the page header with title and motivational subtitle.
  Widget _buildHeader(BuildContext context) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete habits to unlock rewards',
          style: TextStyle(color: tc.textSecondary, fontSize: 16),
        ),
      ],
    );
  }

  /// Builds the gradient level card that shows the user’s current
  /// [level], XP progress bar, and XP needed for the next level.
  Widget _buildLevelCard(BuildContext context, UserLevel level) {
    final tc = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tc.surface, tc.surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tc.surface.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${level.currentLevel}',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    level.levelName,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tc.textPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: tc.textPrimary,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: level.xpProgressPercentage / 100,
              backgroundColor: tc.divider,
              color: tc.textPrimary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${level.currentXp} XP',
                style: TextStyle(color: tc.textSecondary, fontSize: 12),
              ),
              Text(
                '${level.xpForNextLevel} XP to Level ${level.currentLevel + 1}',
                style: TextStyle(color: tc.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders a single badge tile for an [achievement].
  ///
  /// Unlocked badges show a coloured circular icon with a glow shadow;
  /// locked badges appear dimmed with a transparent background.
  Widget _buildAchievementItem(
    BuildContext context,
    AchievementsController controller,
    Achievement achievement,
  ) {
    final tc = context.colors;
    final isUnlocked = achievement.isEarned;
    final iconColor = isUnlocked
        ? tc.textPrimary
        : tc.textPrimary.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked
            ? Border.all(
                color: achievement.color.withValues(alpha: 0.5),
                width: 1,
              )
            : Border.all(color: tc.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked ? achievement.color : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: achievement.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Icon(achievement.icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              achievement.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked
                    ? tc.textPrimary
                    : tc.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+${achievement.points} XP',
            style: TextStyle(color: tc.textMuted, fontSize: 10),
          ),
          if (isUnlocked) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showShareAchievementSheet(context, controller, achievement),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tc.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, size: 12, color: tc.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Share',
                      style: TextStyle(
                        color: tc.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showShareAchievementSheet(
    BuildContext context,
    AchievementsController controller,
    Achievement achievement,
  ) async {
    final tc = context.colors;
    await controller.loadGroupsForSharing();
    if (!context.mounted) return;

    final groups = controller.myGroups;
    showModalBottomSheet(
      context: context,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No groups available',
                    style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Join or create a group to share achievements.',
                    style: TextStyle(color: tc.textMuted)),
                const SizedBox(height: 14),
              ],
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            Text('Share "${achievement.name}"',
                style: TextStyle(color: tc.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...groups.map((g) {
              final gid = g['id'] is int ? g['id'] as int : int.tryParse('${g['id']}');
              return Card(
                color: tc.surface,
                child: ListTile(
                  leading: Icon(Icons.group_rounded, color: tc.primary),
                  title: Text('${g['name'] ?? 'Group'}', style: TextStyle(color: tc.textPrimary)),
                  subtitle: Text('${g['memberCount'] ?? 0} members', style: TextStyle(color: tc.textMuted)),
                  trailing: Icon(Icons.chevron_right_rounded, color: tc.textMuted),
                  onTap: gid == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final ok = await controller.shareAchievementToGroup(achievement, gid);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(controller.actionMessage ?? (ok ? 'Shared' : 'Failed to share')),
                            ),
                          );
                        },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
