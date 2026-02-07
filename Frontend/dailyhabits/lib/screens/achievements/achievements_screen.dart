import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'achievements_controller.dart';
import '../../models/achievement.dart';

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

  Widget _buildAchievementItem(BuildContext context, Achievement achievement) {
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
        ],
      ),
    );
  }
}
