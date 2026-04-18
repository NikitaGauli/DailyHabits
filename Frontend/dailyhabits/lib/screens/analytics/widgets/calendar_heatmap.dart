// =============================================================================
// File: calendar_heatmap.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: A monthly calendar grid where each day cell is colour-coded to
//              indicate the number of habits completed on that date. Supports
//              Monday-start weeks and renders a legend for intensity levels.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// A monthly progress calendar showing daily habit completion counts
/// for a single month.
///
/// Each cell is shaded according to the number of habits completed:
/// - 0 completions → surface variant (muted)
/// - 1–2 completions → medium accent shades
/// - 3+ completions → full accent colour
///
/// The grid starts on Monday and pads empty cells for the offset days
/// before the first day of [monthDate].
class CalendarHeatmap extends StatelessWidget {
  /// Daily completion data from the backend. Each entry contains
  /// a `'date'` key (yyyy-MM-dd) and `'completed'` / `'count'` values.
  final List<Map<String, dynamic>> data;

  /// The month and year to display in the heatmap.
  final DateTime monthDate;

  const CalendarHeatmap({super.key, required this.data, required this.monthDate});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final daysInMonth = DateUtils.getDaysInMonth(
      monthDate.year,
      monthDate.month,
    );
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    // Calculate the number of leading empty cells so the first day
    // aligns correctly under its weekday column (Monday = 0 offset).
    final offset = firstWeekday - 1;
    final totalCells = daysInMonth + offset;
    final summary = _buildPatternSummary(daysInMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(monthDate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem(_IntensityLevel.none, '0', tc),
                  const SizedBox(width: 4),
                  _buildLegendItem(_IntensityLevel.low, '1-2', tc),
                  const SizedBox(width: 4),
                  _buildLegendItem(_IntensityLevel.medium, '3-4', tc),
                  const SizedBox(width: 4),
                  _buildLegendItem(_IntensityLevel.high, '5+', tc),
                ],
              ),
            ],
          ),
        ),
        // Days Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (d) => SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        color: tc.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < offset) {
              return const SizedBox.shrink();
            }
            final day = index - offset + 1;
            final dateStr = DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime(monthDate.year, monthDate.month, day));
            final count = _getCountForDate(dateStr);

            return _buildDayCell(context, day, dateStr, count, tc);
          },
        ),
        const SizedBox(height: 12),
        _buildPatternFooter(summary, tc),
      ],
    );
  }

  /// Looks up the completion count for a given ISO [date] string
  /// from the [data] list. Supports both `'completed'` and `'count'`
  /// field names for backwards compatibility with older API versions.
  int _getCountForDate(String date) {
    // Backend returns { 'date': 'yyyy-MM-dd', 'completed': int, 'count': int }
    final entry = data.firstWhere(
      (e) => e['date'] == date,
      orElse: () => {'completed': 0, 'count': 0},
    );
    // Support both field names
    return entry['completed'] ?? entry['count'] ?? 0;
  }

  _MonthPatternSummary _buildPatternSummary(int daysInMonth) {
    final countsByDate = <String, int>{};
    for (final item in data) {
      final date = (item['date'] ?? '').toString();
      if (date.isEmpty) continue;
      countsByDate[date] = (item['completed'] ?? item['count'] ?? 0) as int;
    }

    int completionDays = 0;
    int longestRun = 0;
    int currentRun = 0;
    int totalCount = 0;
    final weekdayTotals = <int, int>{
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(monthDate.year, monthDate.month, day);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      final count = countsByDate[key] ?? 0;
      totalCount += count;
      weekdayTotals[dt.weekday] = (weekdayTotals[dt.weekday] ?? 0) + count;

      if (count > 0) {
        completionDays += 1;
        currentRun += 1;
        if (currentRun > longestRun) longestRun = currentRun;
      } else {
        currentRun = 0;
      }
    }

    int bestWeekday = 1;
    int bestScore = -1;
    weekdayTotals.forEach((weekday, score) {
      if (score > bestScore) {
        bestScore = score;
        bestWeekday = weekday;
      }
    });

    return _MonthPatternSummary(
      completionDays: completionDays,
      longestRun: longestRun,
      totalCompletions: totalCount,
      bestWeekday: bestWeekday,
    );
  }

  /// Renders a single day cell with a background colour determined by [count].
  ///
  /// Higher counts yield progressively stronger accent colouring.
  Widget _buildDayCell(
    BuildContext context,
    int day,
    String dateStr,
    int count,
    ThemeColors tc,
  ) {
    final level = _levelForCount(count);
    final color = _cellColor(tc, level);
    final textColor = level == _IntensityLevel.none ? tc.textSecondary : tc.textPrimary;

    return GestureDetector(
      onTap: () {
        final humanDate = DateFormat('EEE, MMM d').format(
          DateTime(monthDate.year, monthDate.month, day),
        );
        final label = count == 0
            ? 'No completions recorded'
            : '$count completion${count == 1 ? '' : 's'} recorded';

        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(humanDate),
            content: Text(label),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Tooltip(
        message: '$dateStr: $count completion${count == 1 ? '' : 's'}',
        child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tc.border.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
        ),
      ),
    );
  }

  /// Builds a small legend swatch and label for the given intensity [level].
  Widget _buildLegendItem(_IntensityLevel level, String label, ThemeColors tc) {
    final color = _cellColor(tc, level);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, color: tc.textMuted)),
      ],
    );
  }

  _IntensityLevel _levelForCount(int count) {
    if (count <= 0) return _IntensityLevel.none;
    if (count <= 2) return _IntensityLevel.low;
    if (count <= 4) return _IntensityLevel.medium;
    return _IntensityLevel.high;
  }

  Color _cellColor(ThemeColors tc, _IntensityLevel level) {
    switch (level) {
      case _IntensityLevel.none:
        return tc.surfaceVariant;
      case _IntensityLevel.low:
        return tc.primary.withValues(alpha: 0.28);
      case _IntensityLevel.medium:
        return tc.primary.withValues(alpha: 0.58);
      case _IntensityLevel.high:
        return tc.primary;
    }
  }

  Widget _buildPatternFooter(_MonthPatternSummary summary, ThemeColors tc) {
    const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _summaryChip(tc, 'Completion Days', '${summary.completionDays}'),
          _summaryChip(tc, 'Longest Run', '${summary.longestRun} days'),
          _summaryChip(tc, 'Total Completions', '${summary.totalCompletions}'),
          _summaryChip(tc, 'Best Day', weekday[summary.bestWeekday - 1]),
        ],
      ),
    );
  }

  Widget _summaryChip(ThemeColors tc, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tc.border.withValues(alpha: 0.22)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: tc.textSecondary, fontSize: 11),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

enum _IntensityLevel { none, low, medium, high }

class _MonthPatternSummary {
  final int completionDays;
  final int longestRun;
  final int totalCompletions;
  final int bestWeekday;

  const _MonthPatternSummary({
    required this.completionDays,
    required this.longestRun,
    required this.totalCompletions,
    required this.bestWeekday,
  });
}
