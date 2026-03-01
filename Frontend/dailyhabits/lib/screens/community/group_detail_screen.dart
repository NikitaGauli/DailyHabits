// =============================================================================
// File: group_detail_screen.dart
// Description: Full-featured group detail screen with challenges, leaderboard,
//              member list, and encourage/share-to-group actions.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/widgets/common/glass_container.dart';
import 'package:dailyhabits/models/community_models.dart';
import 'package:dailyhabits/screens/community/community_controller.dart';

/// Detailed group view with 4 sub-sections displayed in a scrollable layout:
/// Header, Active Challenges, Leaderboard, and Members.
class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityController>().loadGroupDetail(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        elevation: 0,
        title: Text(widget.groupName,
            style: AppTextStyles.h3.copyWith(color: tc.textPrimary)),
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tc.textMuted),
            onPressed: () => context
                .read<CommunityController>()
                .loadGroupDetail(widget.groupId),
          ),
        ],
      ),
      body: Consumer<CommunityController>(
        builder: (context, ctrl, _) {
          if (ctrl.isLoadingGroupDetail) {
            return Center(
              child: CircularProgressIndicator(color: tc.primary),
            );
          }
          final detail = ctrl.selectedGroupDetail;
          if (detail == null) {
            return Center(
              child: Text('Failed to load group',
                  style: TextStyle(color: tc.textMuted)),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ctrl.loadGroupDetail(widget.groupId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _buildStatsHeader(context, detail),
                const SizedBox(height: 20),
                if (detail.isAdmin) ...[
                  _buildAdminActions(context, ctrl, detail),
                  const SizedBox(height: 20),
                ],
                _buildChallengesSection(context, detail),
                const SizedBox(height: 20),
                _buildLeaderboardSection(context, detail),
                const SizedBox(height: 20),
                _buildMembersSection(context, ctrl, detail),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Stats Header
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatsHeader(BuildContext context, EnrichedGroupDetail detail) {
    final tc = context.colors;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: detail.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(detail.icon, color: detail.color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.name,
                        style: AppTextStyles.h3
                            .copyWith(color: tc.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Created by ${detail.creatorName}',
                      style:
                          AppTextStyles.caption.copyWith(color: tc.textMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: detail.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied!')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: tc.primary),
                      const SizedBox(width: 4),
                      Text(detail.inviteCode,
                          style: AppTextStyles.caption.copyWith(
                            color: tc.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(detail.description,
                style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip(context, Icons.people, '${detail.memberCount}',
                  'Members', tc.primary),
              const SizedBox(width: 12),
              _statChip(context, Icons.check_circle, '${detail.totalCompletions}',
                  'Completions', const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _statChip(context, Icons.local_fire_department,
                  '${detail.totalStreaks}', 'Streaks', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String value,
      String label, Color color) {
    final tc = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tc.textPrimary,
                )),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Admin Actions
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAdminActions(BuildContext context, CommunityController ctrl,
      EnrichedGroupDetail detail) {
    final tc = context.colors;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () =>
                _showCreateChallengeSheet(context, ctrl, detail.id),
            icon: const Icon(Icons.emoji_events_rounded, size: 18),
            label: const Text('New Challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                _showShareToGroupSheet(context, ctrl, detail.id),
            icon: Icon(Icons.share_rounded, size: 18, color: tc.primary),
            label: Text('Share Habit',
                style: TextStyle(color: tc.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: tc.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Challenges Section
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChallengesSection(
      BuildContext context, EnrichedGroupDetail detail) {
    final tc = context.colors;
    final challenges = detail.challenges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_rounded,
                size: 20, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text('Challenges',
                style: AppTextStyles.h3.copyWith(
                    color: tc.textPrimary, fontSize: 16)),
            const Spacer(),
            Text('${challenges.length}',
                style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        if (challenges.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 40, color: tc.border),
                  const SizedBox(height: 8),
                  Text('No challenges yet',
                      style: TextStyle(color: tc.textMuted)),
                ],
              ),
            ),
          )
        else
          ...challenges.map((ch) => _challengeCard(context, ch)),
      ],
    );
  }

  Widget _challengeCard(BuildContext context, GroupChallenge ch) {
    final tc = context.colors;
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ch.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ch.status == 'completed'
                      ? Icons.check_circle
                      : Icons.emoji_events_rounded,
                  color: ch.statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.title,
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tc.textPrimary,
                        )),
                    Text(ch.targetTypeLabel,
                        style: AppTextStyles.caption
                            .copyWith(color: tc.textMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ch.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ch.status.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: ch.statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (ch.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ch.description,
                style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary)),
          ],
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ch.progressPercentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: tc.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(ch.statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ch.currentProgress} / ${ch.targetValue}',
                style: AppTextStyles.caption.copyWith(
                  color: tc.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (ch.xpReward > 0)
                    _rewardBadge(context, '${ch.xpReward} XP',
                        const Color(0xFF6366F1)),
                  if (ch.coinReward > 0) ...[
                    const SizedBox(width: 6),
                    _rewardBadge(context, '${ch.coinReward} 🪙',
                        const Color(0xFFF59E0B)),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    ch.isActive ? '${ch.daysRemaining}d left' : '',
                    style:
                        AppTextStyles.caption.copyWith(color: tc.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          )),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Leaderboard Section
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLeaderboardSection(
      BuildContext context, EnrichedGroupDetail detail) {
    final tc = context.colors;
    final lb = detail.leaderboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.leaderboard_rounded,
                size: 20, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text('Leaderboard',
                style: AppTextStyles.h3.copyWith(
                    color: tc.textPrimary, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),
        if (lb.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('No data yet',
                  style: TextStyle(color: tc.textMuted)),
            ),
          )
        else
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < lb.length; i++)
                  _leaderboardRow(context, lb[i], i),
              ],
            ),
          ),
      ],
    );
  }

  Widget _leaderboardRow(
      BuildContext context, Map<String, dynamic> entry, int index) {
    final tc = context.colors;
    final medal = index == 0
        ? '🥇'
        : index == 1
            ? '🥈'
            : index == 2
                ? '🥉'
                : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(medal,
                style: TextStyle(
                  fontSize: index < 3 ? 20 : 14,
                  color: tc.textSecondary,
                ),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(entry['name'] ?? 'User',
                style: AppTextStyles.bodyMd.copyWith(
                  color: tc.textPrimary,
                  fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          Text('${entry['completions'] ?? 0}',
              style: AppTextStyles.bodyMd.copyWith(
                color: tc.primary,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(width: 4),
          Icon(Icons.check_circle, size: 14, color: tc.primary),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Members Section
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMembersSection(BuildContext context, CommunityController ctrl,
      EnrichedGroupDetail detail) {
    final tc = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_rounded, size: 20, color: tc.primary),
            const SizedBox(width: 8),
            Text('Members',
                style: AppTextStyles.h3.copyWith(
                    color: tc.textPrimary, fontSize: 16)),
            const SizedBox(width: 6),
            Text('${detail.members.length}',
                style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        ...detail.members.map((m) => _memberTile(context, ctrl, m)),
      ],
    );
  }

  Widget _memberTile(
      BuildContext context, CommunityController ctrl, GroupMemberInfo member) {
    final tc = context.colors;
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tc.primary.withValues(alpha: 0.12),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: tc.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                Row(
                  children: [
                    Text(member.role,
                        style: AppTextStyles.caption
                            .copyWith(color: tc.textMuted)),
                    const SizedBox(width: 8),
                    Icon(Icons.local_fire_department,
                        size: 14, color: const Color(0xFFF59E0B)),
                    Text(' ${member.currentStreak}',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ],
            ),
          ),
          // Encourage button
          IconButton(
            onPressed: () =>
                _showEncourageSheet(context, ctrl, member.id, member.name),
            icon: const Text('📣', style: TextStyle(fontSize: 20)),
            tooltip: 'Encourage',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Encourage Bottom Sheet
  // ═══════════════════════════════════════════════════════════════

  void _showEncourageSheet(
    BuildContext context,
    CommunityController ctrl,
    int userId,
    String userName,
  ) {
    final tc = context.colors;
    final msgCtrl = TextEditingController();
    String selectedType = 'cheer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tc.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Encourage $userName',
                    style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  // Type selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _encourageTypeChip(ctx, '📣', 'cheer', selectedType,
                          (t) => setSheetState(() => selectedType = t)),
                      _encourageTypeChip(ctx, '💪', 'motivate', selectedType,
                          (t) => setSheetState(() => selectedType = t)),
                      _encourageTypeChip(ctx, '🎉', 'celebrate', selectedType,
                          (t) => setSheetState(() => selectedType = t)),
                      _encourageTypeChip(ctx, '⏰', 'remind', selectedType,
                          (t) => setSheetState(() => selectedType = t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: msgCtrl,
                    style: TextStyle(color: tc.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a message (optional)',
                      hintStyle: TextStyle(color: tc.textMuted),
                      filled: true,
                      fillColor: tc.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ctrl.sendEncouragement(
                          toUserId: userId,
                          encourageType: selectedType,
                          message: msgCtrl.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Send Encouragement',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _encourageTypeChip(BuildContext context, String emoji, String type,
      String selectedType, ValueChanged<String> onSelect) {
    final tc = context.colors;
    final isSelected = type == selectedType;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? tc.primary.withValues(alpha: 0.15)
              : tc.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: tc.primary, width: 2) : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(type,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? tc.primary : tc.textMuted,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Create Challenge Sheet
  // ═══════════════════════════════════════════════════════════════

  void _showCreateChallengeSheet(
    BuildContext context,
    CommunityController ctrl,
    int groupId,
  ) {
    final tc = context.colors;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '50');
    String targetType = 'completions';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tc.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('New Challenge',
                        style:
                            AppTextStyles.h3.copyWith(color: tc.textPrimary)),
                    const SizedBox(height: 16),
                    _sheetField(tc, titleCtrl, 'Challenge Title'),
                    const SizedBox(height: 12),
                    _sheetField(tc, descCtrl, 'Description (optional)'),
                    const SizedBox(height: 12),
                    // Target type selector
                    Row(
                      children: [
                        Text('Target: ',
                            style: TextStyle(color: tc.textSecondary)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Completions'),
                          selected: targetType == 'completions',
                          selectedColor: tc.primary.withValues(alpha: 0.15),
                          onSelected: (_) =>
                              setSheetState(() => targetType = 'completions'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Streak'),
                          selected: targetType == 'streak',
                          selectedColor: tc.primary.withValues(alpha: 0.15),
                          onSelected: (_) =>
                              setSheetState(() => targetType = 'streak'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sheetField(tc, targetCtrl, 'Target Value',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          ctrl.createGroupChallenge(
                            groupId,
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            targetType: targetType,
                            targetValue:
                                int.tryParse(targetCtrl.text) ?? 50,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Create Challenge',
                            style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _sheetField(
    dynamic tc,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: tc.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tc.textMuted),
        filled: true,
        fillColor: tc.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Share Habit to Group Sheet
  // ═══════════════════════════════════════════════════════════════

  void _showShareToGroupSheet(
    BuildContext context,
    CommunityController ctrl,
    int groupId,
  ) {
    final tc = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: tc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Share a Habit',
                  style: AppTextStyles.h3.copyWith(color: tc.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Enter the habit ID to share with this group.',
                style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
              ),
              const SizedBox(height: 16),
              Builder(builder: (ctx) {
                final idCtrl = TextEditingController();
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: tc.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Habit ID',
                          hintStyle: TextStyle(color: tc.textMuted),
                          filled: true,
                          fillColor: tc.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final id = int.tryParse(idCtrl.text);
                        if (id != null) {
                          Navigator.pop(ctx);
                          ctrl.shareHabitToGroup(groupId, id);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Share'),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
