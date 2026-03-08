// =============================================================================
// File: streak_calendar_widget.dart
// Description: A premium visual streak calendar showing the last 30 days of
//              habit completion, freeze usage, and streak statistics. Includes
//              streak freeze management (purchase & use).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/models/grow_together_models.dart';

// =============================================================================
// Streak Calendar Widget
// =============================================================================

/// A beautiful 30-day streak calendar with stats and freeze management.
class StreakCalendarWidget extends StatelessWidget {
  final StreakCalendar calendar;
  final StreakFreezeInfo? freezeInfo;
  final bool isLoadingFreezes;
  final VoidCallback? onPurchaseFreeze;
  final Function(String? date)? onUseFreeze;

  const StreakCalendarWidget({
    super.key,
    required this.calendar,
    this.freezeInfo,
    this.isLoadingFreezes = false,
    this.onPurchaseFreeze,
    this.onUseFreeze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats Row ──────────────────────────────────────────────
        _StreakStatsRow(calendar: calendar),
        const SizedBox(height: 16),

        // ── Calendar Grid ──────────────────────────────────────────
        _CalendarGrid(calendar: calendar.calendar),
        const SizedBox(height: 12),

        // ── Legend ─────────────────────────────────────────────────
        _CalendarLegend(),
        const SizedBox(height: 16),

        // ── Streak Freeze Section ──────────────────────────────────
        if (freezeInfo != null)
          _StreakFreezeSection(
            freezeInfo: freezeInfo!,
            isLoading: isLoadingFreezes,
            onPurchase: onPurchaseFreeze,
            onUse: onUseFreeze,
          ),
      ],
    );
  }
}

// =============================================================================
// Stats Row
// =============================================================================

class _StreakStatsRow extends StatelessWidget {
  final StreakCalendar calendar;
  const _StreakStatsRow({required this.calendar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.local_fire_department,
          iconColor: Colors.orange,
          label: 'Streak',
          value: '${calendar.currentStreak}',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.emoji_events,
          iconColor: Colors.amber,
          label: 'Best',
          value: '${calendar.bestStreak}',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.bolt,
          iconColor: AppColors.primary,
          label: 'XP',
          value: '${calendar.totalXpEarned}',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.ac_unit,
          iconColor: Colors.lightBlue,
          label: 'Freezes',
          value: '${calendar.availableFreezes}',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Calendar Grid — 30 days displayed in rows of 7
// =============================================================================

class _CalendarGrid extends StatelessWidget {
  final List<StreakCalendarDay> calendar;
  const _CalendarGrid({required this.calendar});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar cells
          _buildCalendarRows(context, today),
        ],
      ),
    );
  }

  Widget _buildCalendarRows(BuildContext context, String today) {
    if (calendar.isEmpty) {
      return const Center(child: Text('No calendar data'));
    }

    // Align to weekday grid — find the first day's weekday
    final firstDate = calendar.first.date;
    // Monday=1, Sunday=7 → offset is weekday-1 for Monday-start grid
    final startOffset = firstDate.weekday - 1;

    // Build full cell list with possible leading blanks
    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox(width: 36, height: 36));
    }
    for (final day in calendar) {
      cells.add(_DayCell(day: day, isToday: DateFormat('yyyy-MM-dd').format(day.date) == today));
    }

    // Chunk into rows of 7
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7 > cells.length) ? cells.length : i + 7;
      final rowCells = cells.sublist(i, end);
      // Pad row if less than 7
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 36, height: 36));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowCells,
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class _DayCell extends StatelessWidget {
  final StreakCalendarDay day;
  final bool isToday;
  const _DayCell({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = day.date;
    final dayNum = date.day;

    Color bgColor;
    Color textColor;
    IconData? overlayIcon;

    if (day.completed) {
      bgColor = AppColors.success.withValues(alpha: 0.8);
      textColor = Colors.white;
    } else if (day.freezeUsed) {
      bgColor = Colors.lightBlue.withValues(alpha: 0.7);
      textColor = Colors.white;
      overlayIcon = Icons.ac_unit;
    } else if (day.date.isBefore(
        DateTime.now().subtract(const Duration(hours: 12)))) {
      // Past day, missed
      bgColor = colors.onSurface.withValues(alpha: 0.06);
      textColor = colors.onSurface.withValues(alpha: 0.3);
    } else {
      // Today or future
      bgColor = Colors.transparent;
      textColor = colors.onSurface.withValues(alpha: 0.7);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
              boxShadow: day.completed
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: overlayIcon != null
                ? Icon(overlayIcon, size: 14, color: Colors.white)
                : Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
          ),
          if (day.completed && day.xpEarned > 0)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${day.xpEarned}',
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Calendar Legend
// =============================================================================

class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: AppColors.success.withValues(alpha: 0.8),
          label: 'Completed',
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: Colors.lightBlue.withValues(alpha: 0.7),
          label: 'Freeze',
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: colors.onSurface.withValues(alpha: 0.06),
          label: 'Missed',
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: Colors.transparent,
          label: 'Today',
          isBorder: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBorder;
  const _LegendItem({
    required this.color,
    required this.label,
    this.isBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isBorder ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: isBorder
                ? Border.all(color: AppColors.primary, width: 1.5)
                : (color == Colors.transparent
                    ? Border.all(
                        color: colors.onSurface.withValues(alpha: 0.2))
                    : null),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Streak Freeze Section
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.lightBlue.withValues(alpha: 0.05),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.lightBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.ac_unit,
                    size: 20, color: Colors.lightBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Streak Freezes',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Protect your streak when you miss a day',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Available count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: freezeInfo.availableCount > 0
                      ? Colors.lightBlue.withValues(alpha: 0.15)
                      : colors.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${freezeInfo.availableCount} / ${freezeInfo.maxFreezes}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: freezeInfo.availableCount > 0
                        ? Colors.lightBlue
                        : colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Freeze tokens visual
          Row(
            children: List.generate(
              freezeInfo.maxFreezes,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i < freezeInfo.availableCount
                        ? Colors.lightBlue.withValues(alpha: 0.15)
                        : colors.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i < freezeInfo.availableCount
                          ? Colors.lightBlue.withValues(alpha: 0.3)
                          : colors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.ac_unit,
                    size: 20,
                    color: i < freezeInfo.availableCount
                        ? Colors.lightBlue
                        : colors.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              // Purchase Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: freezeInfo.canPurchase && !isLoading
                      ? onPurchase
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: Text(
                    'Buy (${freezeInfo.freezeCostXp} XP)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color:
                          Colors.lightBlue.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),  
              const SizedBox(width: 10),
              // Use Freeze Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      freezeInfo.availableCount > 0 && !isLoading
                          ? () => onUse?.call(null)
                          : null,
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text(
                    'Use Freeze',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Recently used freezes
          if (freezeInfo.used.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recently Used',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            ...freezeInfo.used.take(3).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.ac_unit,
                          size: 12,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(width: 6),
                      Text(
                        'Used on ${_formatDate(f.usedOnDate ?? '')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        f.source,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '--';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
