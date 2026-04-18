// =============================================================================
// habit_detail_screen.dart — Individual Habit Detail View
// =============================================================================
// Full-page detail screen for a single [Habit].
//
// Displays:
//  • Habit header (icon, title, description, category/frequency chips).
//  • Completion toggle button (mark as done / undo).
//  • Streak & progress statistics (current, best, completions, skips).
//  • Consistency bars for the last 7 / 30 / 90 days.
//  • Schedule information (time, frequency, reminders).
//  • Recent activity history timeline.
//
// Provides in-place editing via [CreateEditHabitSheet] and deletion
// with a confirmation dialog.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/habit.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';
import 'package:dailyhabits/widgets/common/shimmer_loading.dart';
import 'package:dailyhabits/widgets/common/animated_completion.dart';
import 'package:dailyhabits/services/habit_service.dart';
import 'package:dailyhabits/services/notification_service.dart';
import 'package:dailyhabits/widgets/home/create_edit_habit_sheet.dart';

/// Detailed view for a single habit — stats, streak, history, notes.
class HabitDetailScreen extends StatefulWidget {
  /// The habit to display.
  final Habit habit;

  /// Callback invoked after the habit’s completion state changes.
  final VoidCallback? onToggle;

  /// Callback invoked after the habit is permanently deleted.
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

/// Internal state for [HabitDetailScreen].
///
/// Owns the mutable [_habit] reference, server-fetched [_stats],
/// and the 30-day [_history] list.
class _HabitDetailScreenState extends State<HabitDetailScreen> {
  /// Service layer for habit CRUD and analytics calls.
  final HabitService _habitService = HabitService();
  final NotificationService _notificationService = NotificationService();

  /// Local mutable copy of the habit (updated after edits/toggles).
  late Habit _habit;

  /// Aggregated statistics returned by the stats endpoint.
  Map<String, dynamic>? _stats;

  /// Raw history entries for the last 30 days.
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _missedSummary;
  Map<String, dynamic>? _latestReflection;
  String _reminderMessagePreview = '';

  /// Whether the initial data load is in progress.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _loadData();
  }

  /// Fetches stats and 30-day history for the current habit.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _habitService.getStats(_habit.id);
      final historyResponse =
          await _habitService.getHistory(_habit.id, days: 30);
      final missedSummary = await _habitService.getMissedDaysSummary(days: 30);
      final reminder = await _notificationService.getReminderForHabit(
        int.tryParse(_habit.id) ?? 0,
      );

      final historyList = List<Map<String, dynamic>>.from(
        historyResponse['history'] ?? [],
      );
      Map<String, dynamic>? latestReflection;
      for (final entry in historyList) {
        final hasNotes = (entry['notes'] as String? ?? '').trim().isNotEmpty;
        final hasMood = entry['moodRating'] != null;
        final hasEnergy = entry['energyLevel'] != null;
        if (entry['status'] == 'completed' && (hasNotes || hasMood || hasEnergy)) {
          latestReflection = entry;
          break;
        }
      }

      setState(() {
        _stats = stats;
        _history = historyList;
        _missedSummary = missedSummary;
        _latestReflection = latestReflection;
        _reminderMessagePreview = reminder?['message']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('Error loading habit detail: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Opens the create/edit bottom sheet pre-populated with [_habit] data.
  ///
  /// On save, pushes the update to the server and refreshes local state.
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

  /// Shows a destructive confirmation dialog and, upon acceptance,
  /// deletes the habit from the server and pops the screen.
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: tc.textPrimary),
            onSelected: (action) async {
              final messenger = ScaffoldMessenger.of(context);
              if (action == 'archive') {
                final ok = await _habitService.archiveHabit(_habit.id);
                if (!mounted) return;
                if (ok) {
                  setState(() => _habit = _habit.copyWith(status: 'archived'));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Habit archived')),
                  );
                  widget.onToggle?.call();
                }
              }
              if (action == 'unarchive') {
                final ok = await _habitService.unarchiveHabit(_habit.id);
                if (!mounted) return;
                if (ok) {
                  setState(() => _habit = _habit.copyWith(status: 'active'));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Habit restored to active')),
                  );
                  widget.onToggle?.call();
                }
              }
              if (action == 'mark_missed') {
                final result = await _habitService.markMissed(
                  _habit.id,
                  notes: 'Marked as missed from habit detail.',
                );
                if (!mounted) return;
                if (result != null && result['success'] == true) {
                  setState(() {
                    _habit = _habit.copyWith(
                      isCompleted: false,
                      completionState: CompletionState.missed,
                    );
                  });
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Marked as missed for today')),
                  );
                  await _loadData();
                  widget.onToggle?.call();
                }
              }
            },
            itemBuilder: (_) => [
              if (_habit.status == 'archived')
                const PopupMenuItem(
                  value: 'unarchive',
                  child: Text('Unarchive Habit'),
                )
              else
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Archive Habit'),
                ),
              const PopupMenuItem(
                value: 'mark_missed',
                child: Text('Mark Today as Missed'),
              ),
            ],
          ),
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
          ? _buildShimmerSkeleton(tc)
          : RefreshIndicator(
              onRefresh: _loadData,
              color: tc.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBreadcrumbBar(tc),
                    const SizedBox(height: 16),
                    _buildHabitHeader(tc),
                    const SizedBox(height: 24),
                    _buildCompletionToggle(tc),
                    const SizedBox(height: 24),
                    _buildLatestReflection(tc),
                    const SizedBox(height: 24),
                    _buildStreakSection(tc),
                    const SizedBox(height: 24),
                    _buildConsistencySection(tc),
                    const SizedBox(height: 24),
                    _buildScheduleInfo(tc),
                    const SizedBox(height: 24),
                    _buildMissedSummary(tc),
                    const SizedBox(height: 24),
                    _buildRecentHistory(tc),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMissedSummary(ThemeColors tc) {
    final summary = _missedSummary ?? const <String, dynamic>{};
    final habits = (summary['habits'] as List?) ?? const [];
    final habitEntry = habits.cast<Map<String, dynamic>>().where((h) {
      return '${h['habitId']}' == _habit.id;
    }).cast<Map<String, dynamic>>().toList();
    final missedCount = habitEntry.isNotEmpty
        ? (habitEntry.first['missedCount'] as num?)?.toInt() ?? 0
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, color: tc.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missed Days (Last 30 Days)',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$missedCount missed day${missedCount == 1 ? '' : 's'}',
                  style: AppTextStyles.caption.copyWith(color: tc.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbBar(ThemeColors tc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You are here: Profile > Quick Access > Reminder Customizer > Habit Details',
              style: AppTextStyles.caption.copyWith(
                color: tc.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_rounded, size: 16),
            label: const Text('Dashboard'),
          ),
        ],
      ),
    );
  }

  // ─── SHIMMER SKELETON ──────────────────────────────────────────────────
  /// Displays a shimmer loading skeleton that mirrors the detail layout
  /// while data is being fetched from the API.
  Widget _buildShimmerSkeleton(ThemeColors tc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              const ShimmerBox(width: 56, height: 56, borderRadius: 16),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 160, height: 20, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 100, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 200, height: 24, borderRadius: 8),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Toggle skeleton
          const ShimmerBox(width: double.infinity, height: 56, borderRadius: 18),
          const SizedBox(height: 24),
          // Stats skeleton
          const ShimmerBox(width: 140, height: 18, borderRadius: 6),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 24),
          // Consistency skeleton
          const ShimmerBox(width: 120, height: 18, borderRadius: 6),
          const SizedBox(height: 14),
          for (int i = 0; i < 3; i++) ...[
            const ShimmerBox(width: double.infinity, height: 44, borderRadius: 14),
            if (i < 2) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────
  /// Builds the habit header card with icon, title, description, and
  /// metadata chips (category, frequency, priority).
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
                if (_habit.status == 'archived') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tc.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Archived',
                      style: AppTextStyles.caption.copyWith(
                        color: tc.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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

  /// Reusable small chip with a tinted background.
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
  /// Animated toggle button that marks the habit as done/undone for today.
  ///
  /// On tap, calls the toggle API and updates local state from the
  /// server response (completion status and streak count). Shows a
  /// celebration animation when marking as complete.
  Widget _buildCompletionToggle(ThemeColors tc) {
    final isDone = _habit.isCompleted;

    return GestureDetector(
      onTap: () async {
        try {
          Map<String, dynamic>? reflectionPayload;
          if (!isDone) {
            reflectionPayload = await _showCompletionReflectionDialog(tc);
            if (reflectionPayload == null) return;
          }

          final result = await _habitService.toggleHabit(
            _habit.id,
            payload: reflectionPayload,
          );
          if (result['success'] == true) {
            final nowCompleted = result['isCompleted'] == true;
            setState(() {
              _habit = _habit.copyWith(
                isCompleted: nowCompleted,
                completionState:
                    nowCompleted ? CompletionState.completed : CompletionState.pending,
                currentStreak: result['currentStreak'] ?? _habit.currentStreak,
              );
              if (nowCompleted && reflectionPayload != null) {
                _latestReflection = {
                  'status': 'completed',
                  'date': DateTime.now().toIso8601String().split('T').first,
                  'notes': reflectionPayload['notes'] ?? '',
                  'moodRating': reflectionPayload['moodRating'],
                  'energyLevel': reflectionPayload['energyLevel'],
                };
              }
            });
            // Show celebration animation on completion
            if (nowCompleted && mounted) {
              CompletionCelebration.show(context, color: _habit.color);
            }
            widget.onToggle?.call();
            await _loadData();
          }
        } catch (e) {
          debugPrint('Toggle error: $e');
        }
      },
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: AppCurves.smooth,
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

  Future<Map<String, dynamic>?> _showCompletionReflectionDialog(
    ThemeColors tc,
  ) async {
    final notesCtrl = TextEditingController();
    int mood = 3;
    int energy = 3;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: tc.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Complete With Reflection',
                style: TextStyle(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'How did this completion feel today?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Mood: $mood', style: TextStyle(color: tc.textSecondary)),
                    Slider(
                      value: mood.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (v) => setLocalState(() => mood = v.round()),
                    ),
                    Text(
                      'Energy: $energy',
                      style: TextStyle(color: tc.textSecondary),
                    ),
                    Slider(
                      value: energy.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (v) => setLocalState(() => energy = v.round()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Cancel', style: TextStyle(color: tc.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'notes': notesCtrl.text.trim(),
                    'moodRating': mood,
                    'energyLevel': energy,
                    'count': 1,
                  }),
                  child: const Text('Complete Habit'),
                ),
              ],
            );
          },
        );
      },
    );

    notesCtrl.dispose();
    return result;
  }

  // ─── STREAK ────────────────────────────────────────────────────────────
  /// Builds the "Streak & Progress" section with a 2×2 grid of stat cards
  /// (current streak, best streak, total completions, total skips).
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

  /// Builds a single stat card with an icon, value, and label.
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
  /// Builds the "Consistency" section showing animated progress bars
  /// for the 7-day, 30-day, and 90-day completion percentages.
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

  /// Renders a single animated consistency progress bar.
  ///
  /// Bar colour is determined by the percentage: green (≥80%), teal (≥50%),
  /// or amber (<50%).
  Widget _buildConsistencyBar(String label, double pct, ThemeColors tc) {
    final fraction = (pct / 100).clamp(0.0, 1.0);
    // Choose colour based on consistency level
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
  /// Displays the habit’s scheduling metadata: preferred time, frequency
  /// pattern (daily / custom days), and reminder configuration.
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
            if (_reminderMessagePreview.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: tc.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _reminderMessagePreview,
                      style:
                          AppTextStyles.bodyMd.copyWith(color: tc.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openReminderCustomizer,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Customize Reminder Notification'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReminderCustomizer() async {
    final tc = context.colors;
    final habitId = int.tryParse(_habit.id);
    if (habitId == null) return;

    final existing = await _notificationService.getReminderForHabit(habitId);
    bool isEnabled = existing?['isEnabled'] as bool? ?? _habit.reminderEnabled;
    TimeOfDay selectedTime = _habit.reminderTime ?? const TimeOfDay(hour: 8, minute: 0);
    String repeatType = existing?['repeatType']?.toString() ?? 'daily';
    final messageCtrl = TextEditingController(
      text: existing?['message']?.toString() ?? _reminderMessagePreview,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: tc.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Customize Reminder',
                  style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Enable reminder'),
                      value: isEnabled,
                      onChanged: (v) => setLocal(() => isEnabled = v),
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time_rounded),
                      title: const Text('Reminder time'),
                      subtitle: Text(selectedTime.format(ctx)),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (t != null) {
                          setLocal(() => selectedTime = t);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: repeatType,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Days')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => repeatType = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Custom message',
                        hintText: 'Example: Your 10-minute walk starts now',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final ok = await _notificationService.upsertHabitReminderForHabit(
        habitId: habitId,
        reminderTime: selectedTime,
        repeatType: repeatType,
        isEnabled: isEnabled,
        message: messageCtrl.text.trim(),
      );
      if (ok) {
        setState(() {
          _habit = _habit.copyWith(
            reminderEnabled: isEnabled,
            reminderTime: isEnabled ? selectedTime : null,
          );
          _reminderMessagePreview = messageCtrl.text.trim();
        });

        await _habitService.updateHabit(
          _habit.copyWith(
            reminderEnabled: isEnabled,
            reminderTime: isEnabled ? selectedTime : null,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder customization saved')),
          );
        }
      }
    }
    messageCtrl.dispose();
  }

  Widget _buildLatestReflection(ThemeColors tc) {
    final reflection = _latestReflection;
    if (reflection == null) {
      return const SizedBox.shrink();
    }

    final notes = reflection['notes']?.toString() ?? '';
    final mood = reflection['moodRating'];
    final energy = reflection['energyLevel'];
    final date = reflection['date']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Completion Reflection',
            style: AppTextStyles.bodyMd.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: AppTextStyles.caption.copyWith(color: tc.textMuted)),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: AppTextStyles.bodyMd.copyWith(color: tc.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _metricChip(tc, 'Mood', mood),
              const SizedBox(width: 8),
              _metricChip(tc, 'Energy', energy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(ThemeColors tc, String label, dynamic value) {
    final text = value == null ? '$label: -' : '$label: $value/5';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tc.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: tc.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── RECENT HISTORY ────────────────────────────────────────────────────
  /// Renders the "Recent Activity" section showing the last 10 history
  /// entries (completed, skipped, or missed), or an empty-state message.
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

  /// Renders a single history entry row with a status icon, label,
  /// optional notes, and the date string.
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
