import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// CalendarWidget
/// ---------------------------------------------------------------------------
/// A lightweight, non-interactive calendar widget used within the onboarding
/// flow to visually demonstrate progress tracking.
///
/// Purpose:
///  • Illustrates habit consistency visually
///  • Enhances onboarding storytelling
///  • Matches the design prototype exactly
///
/// Notes:
///  • This widget is intentionally static
///  • Highlighted dates are illustrative only
/// ---------------------------------------------------------------------------
class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTopHandle(tc),

          const SizedBox(height: 16),

          _buildMonthLabel(tc),

          const SizedBox(height: 16),

          _buildCalendarGrid(tc),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Components
  // ---------------------------------------------------------------------------

  /// Top handle indicator commonly used in modern card layouts.
  /// Provides subtle visual hierarchy and realism.
  Widget _buildTopHandle(ThemeColors tc) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: tc.textPrimary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Displays the month label.
  /// Static by design to match prototype visuals.
  Widget _buildMonthLabel(ThemeColors tc) {
    return Text(
      'Jun',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: tc.textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }

  /// Builds the complete calendar layout including
  /// weekday headers and date cells.
  Widget _buildCalendarGrid(ThemeColors tc) {
    return Column(
      children: [
        _buildWeekdayHeader(tc),

        const SizedBox(height: 8),

        _buildDateRows(tc),
      ],
    );
  }

  /// Weekday labels (Sun – Sat)
  Widget _buildWeekdayHeader(ThemeColors tc) {
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays
          .map(
            (day) => Expanded(
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tc.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Calendar date rows (5 weeks).
  /// Generates a realistic month layout.
  Widget _buildDateRows(ThemeColors tc) {
    return Column(
      children: List.generate(
        5,
        (weekIndex) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final day = weekIndex * 7 + dayIndex - 2;

              // Empty cells for alignment
              if (day < 1 || day > 30) {
                return const SizedBox(width: 28, height: 28);
              }

              // Highlight sample completed days
              final bool isHighlighted = day == 15 || day == 22;

              return _CalendarDayCell(day: day, isHighlighted: isHighlighted, tc: tc);
            }),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Calendar Day Cell
/// ---------------------------------------------------------------------------
/// Represents a single day in the calendar grid.
/// Highlighted days visually represent habit completion.
/// ---------------------------------------------------------------------------
class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day, required this.isHighlighted, required this.tc});

  /// Day number displayed in the cell
  final int day;

  /// Whether this day is visually highlighted
  final bool isHighlighted;

  /// Theme colors
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isHighlighted ? tc.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            color: isHighlighted ? tc.card : tc.textPrimary,
          ),
        ),
      ),
    );
  }
}
