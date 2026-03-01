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

/// A GitHub-style calendar heatmap showing daily habit completion counts
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
                  _buildLegendItem(0, '0', tc),
                  const SizedBox(width: 4),
                  _buildLegendItem(1, '1-2', tc),
                  const SizedBox(width: 4),
                  _buildLegendItem(3, '3+', tc),
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

            return _buildDayCell(day, count, tc);
          },
        ),
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

  /// Renders a single day cell with a background colour determined by [count].
  ///
  /// Higher counts yield progressively stronger accent colouring.
  Widget _buildDayCell(int day, int count, ThemeColors tc) {
    Color color = tc.surfaceVariant;
    Color textColor = tc.textSecondary;

    if (count > 0) {
      textColor = tc.textPrimary;
      if (count == 1) {
        color = tc.surface;
      } else if (count == 2) {
        color = tc.accent;
      } else if (count >= 3) {
        color = tc.accent.withValues(alpha: 0.8);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
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
    );
  }

  /// Builds a small legend swatch and label for the given intensity [level].
  Widget _buildLegendItem(int level, String label, ThemeColors tc) {
    Color color = tc.surfaceVariant;
    if (level == 1) {
      color = tc.surface;
    } else if (level == 3) {
      color = tc.accent;
    }

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
}
