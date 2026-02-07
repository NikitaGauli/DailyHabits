import 'package:flutter/material.dart';
import 'package:dailyhabits/models/habit.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/services/habit_service.dart';
import 'package:dailyhabits/widgets/home/create_edit_habit_sheet.dart';

/// Detailed view for a single habit — stats, streak, history, notes.
class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const HabitDetailScreen({
    super.key,
    required this.habit,
    this.onToggle,
    this.onDelete,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final HabitService _habitService = HabitService();

  late Habit _habit;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _habitService.getStats(_habit.id);
      final historyResponse =
          await _habitService.getHistory(_habit.id, days: 30);
      setState(() {
        _stats = stats;
        _history = List<Map<String, dynamic>>.from(
          historyResponse['history'] ?? [],
        );
      });
    } catch (e) {
      debugPrint('Error loading habit detail: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateEditHabitSheet(
        habit: _habit,
        onSave: (updated) async {
          final h = await _habitService.updateHabit(
            updated.copyWith(id: _habit.id),
          );
          setState(() => _habit = h);
          await _loadData();
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tc = ctx.colors;
        return AlertDialog(
          backgroundColor: tc.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text('Remove habit?', style: TextStyle(color: tc.textPrimary)),
          content: Text(
            'Delete "${_habit.title}" and all its history? This can\'t be undone.',
            style: TextStyle(color: tc.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: TextStyle(color: tc.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove', style: TextStyle(color: tc.error)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _habitService.deleteHabit(_habit.id);
      widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Details',
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: tc.primary),
            onPressed: _showEditSheet,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: tc.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tc.secondary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: tc.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHabitHeader(tc),
                    const SizedBox(height: 24),
                    _buildCompletionToggle(tc),
                    const SizedBox(height: 24),
                    _buildStreakSection(tc),
                    const SizedBox(height: 24),
                    _buildConsistencySection(tc),
                    const SizedBox(height: 24),
                    _buildScheduleInfo(tc),
                    const SizedBox(height: 24),
                    _buildRecentHistory(tc),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────

  Widget _buildHabitHeader(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        boxShadow: AppShadows.card(context),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _habit.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_habit.icon, color: _habit.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _habit.title,
                  style: AppTextStyles.h2.copyWith(color: tc.textPrimary),
                ),
                if (_habit.description != null &&
                    _habit.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _habit.description!,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip(_habit.category, tc.primary, tc),
                    const SizedBox(width: 8),
                    _buildChip(
                      _habit.frequency[0].toUpperCase() +
                          _habit.frequency.substring(1),
                      tc.secondary,
                      tc,
                    ),
                    if (_habit.priority == 'high') ...[
                      const SizedBox(width: 8),
                      _buildChip('High', tc.error, tc),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color, ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── COMPLETION TOGGLE ─────────────────────────────────────────────────

  Widget _buildCompletionToggle(ThemeColors tc) {
    final isDone = _habit.isCompleted;

    return GestureDetector(
      onTap: () async {
        try {
          final result = await _habitService.toggleHabit(_habit.id);
          if (result['success'] == true) {
            setState(() {
              _habit = _habit.copyWith(
                isCompleted: result['isCompleted'],
                currentStreak: result['currentStreak'] ?? _habit.currentStreak,
              );
            });
            widget.onToggle?.call();
            await _loadData();
          }
        } catch (e) {
          debugPrint('Toggle error: $e');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: isDone
              ? tc.success.withValues(alpha: 0.1)
              : tc.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDone ? tc.success : tc.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isDone ? tc.success : tc.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              isDone ? 'Done for today' : 'Mark as done',
              style: TextStyle(
                color: isDone ? tc.success : tc.primary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STREAK ────────────────────────────────────────────────────────────

  Widget _buildStreakSection(ThemeColors tc) {
    final streakData = _stats?['streak'] ?? {};
    final current = streakData['currentStreak'] ?? _habit.currentStreak;
    final best = streakData['bestStreak'] ?? _habit.bestStreak;
    final totalDone = streakData['totalCompletions'] ?? 0;
    final totalSkips = streakData['totalSkips'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Streak & Progress',
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Current',
                value: '$current days',
                color: tc.success,
                tc: tc,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.emoji_events_rounded,
                label: 'Best',
                value: '$best days',
                color: tc.warning,
                tc: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed',
                value: '$totalDone',
                color: tc.primary,
                tc: tc,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.skip_next_rounded,
                label: 'Skips',
                value: '$totalSkips',
                color: tc.textMuted,
                tc: tc,
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tc.textMuted),
          ),
        ],
      ),
    );
  }

  // ─── CONSISTENCY ───────────────────────────────────────────────────────

  Widget _buildConsistencySection(ThemeColors tc) {
    final consistency = _stats?['consistency'] ?? {};
    final d7 = (consistency['7days'] ?? 0).toDouble();
    final d30 = (consistency['30days'] ?? 0).toDouble();
    final d90 = (consistency['90days'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consistency',
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
        ),
        const SizedBox(height: 14),
        _buildConsistencyBar('7 days', d7, tc),
        const SizedBox(height: 12),
        _buildConsistencyBar('30 days', d30, tc),
        const SizedBox(height: 12),
        _buildConsistencyBar('90 days', d90, tc),
      ],
    );
  }

  Widget _buildConsistencyBar(String label, double pct, ThemeColors tc) {
    final fraction = (pct / 100).clamp(0.0, 1.0);
    // Use secondary (teal) for progress bar per spec
    final barColor = pct >= 80
        ? tc.success
        : pct >= 50
            ? tc.secondary
            : tc.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: tc.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 800),
                builder: (_, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: tc.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${pct.toInt()}%',
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SCHEDULE INFO ─────────────────────────────────────────────────────

  Widget _buildScheduleInfo(ThemeColors tc) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: AppTextStyles.bodyLg.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: tc.textMuted),
              const SizedBox(width: 8),
              Text(
                _habit.time.isNotEmpty ? _habit.time : 'Any time',
                style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 18, color: tc.textMuted),
              const SizedBox(width: 8),
              Text(
                _habit.frequency == 'custom' && _habit.customDays.isNotEmpty
                    ? _habit.customDays.map((d) => dayNames[d]).join(', ')
                    : _habit.frequency[0].toUpperCase() +
                        _habit.frequency.substring(1),
                style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
              ),
            ],
          ),
          if (_habit.reminderEnabled && _habit.reminderTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: 18, color: tc.secondary),
                const SizedBox(width: 8),
                Text(
                  'Reminder at ${_habit.reminderTime!.format(context)}',
                  style:
                      AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── RECENT HISTORY ────────────────────────────────────────────────────

  Widget _buildRecentHistory(ThemeColors tc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
        ),
        const SizedBox(height: 14),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.border.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                'No activity yet. Complete this habit to start tracking.',
                style: AppTextStyles.bodyMd.copyWith(color: tc.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...(_history.take(10).map((entry) => _buildHistoryTile(entry, tc))),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> entry, ThemeColors tc) {
    final status = entry['status'] ?? 'unknown';
    final date = entry['date'] ?? '';
    final notes = entry['notes'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'completed':
        statusColor = tc.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Completed';
        break;
      case 'skipped':
        statusColor = tc.warning;
        statusIcon = Icons.skip_next_rounded;
        statusLabel = 'Skipped';
        break;
      case 'missed':
        statusColor = tc.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Missed';
        break;
      default:
        statusColor = tc.textMuted;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (notes.isNotEmpty)
                  Text(
                    notes,
                    style: AppTextStyles.caption.copyWith(
                      color: tc.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            date,
            style: AppTextStyles.caption.copyWith(color: tc.textMuted),
          ),
        ],
      ),
    );
  }
}
