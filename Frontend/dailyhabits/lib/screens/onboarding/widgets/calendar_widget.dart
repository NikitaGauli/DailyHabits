// =============================================================================
// calendar_widget.dart — Onboarding Calendar Illustration
// =============================================================================
// A purely decorative, non-interactive calendar grid used on the second
// onboarding page to visually demonstrate habit-tracking progress.
//
// The widget renders a static June calendar with two highlighted days
// (15 and 22) representing sample completions. It is intentionally
// read-only and serves only as a storytelling aid.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  /// Sample completed days for the demo calendar.
  static const Set<int> _completedDays = {3, 5, 8, 10, 12, 15, 17, 19, 22, 24, 26};

  /// Today's demo day.
  static const int _todayDay = 27;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMonthHeader(tc),
          const SizedBox(height: 12),
          _buildWeekdayHeader(tc),
          const SizedBox(height: 6),
          _buildDateRows(tc),
          const SizedBox(height: 10),
          _buildLegend(tc),
        ],
      ),
    );
  }

  /// Month header with navigation arrows feel.
  Widget _buildMonthHeader(ThemeColors tc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chevron_left_rounded, size: 18, color: tc.textMuted),
        const SizedBox(width: 8),
        Text(
          'June 2026',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: tc.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 18, color: tc.textMuted),
      ],
    );
  }

  /// Weekday labels (S M T W T F S).
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tc.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Calendar date rows (5 weeks).
  Widget _buildDateRows(ThemeColors tc) {
    return Column(
      children: List.generate(
        5,
        (weekIndex) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final day = weekIndex * 7 + dayIndex - 2;
              if (day < 1 || day > 30) {
                return const SizedBox(width: 26, height: 26);
              }
              final isCompleted = _completedDays.contains(day);
              final isToday = day == _todayDay;
              return _CalendarDayCell(
                day: day,
                isCompleted: isCompleted,
                isToday: isToday,
                tc: tc,
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Mini legend below the calendar.
  Widget _buildLegend(ThemeColors tc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(tc.accent, tc),
        const SizedBox(width: 4),
        Text('Done', style: TextStyle(fontSize: 9, color: tc.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        _legendDot(tc.accent.withValues(alpha: 0.15), tc),
        const SizedBox(width: 4),
        Text('Today', style: TextStyle(fontSize: 9, color: tc.textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _legendDot(Color color, ThemeColors tc) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Calendar Day Cell
/// ---------------------------------------------------------------------------
class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isCompleted,
    required this.isToday,
    required this.tc,
  });

  final int day;
  final bool isCompleted;
  final bool isToday;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    FontWeight weight;

    if (isCompleted) {
      bgColor = tc.accent;
      textColor = Colors.white;
      weight = FontWeight.w700;
    } else if (isToday) {
      bgColor = tc.accent.withValues(alpha: 0.15);
      textColor = tc.accent;
      weight = FontWeight.w700;
    } else {
      bgColor = Colors.transparent;
      textColor = tc.textPrimary;
      weight = FontWeight.w500;
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: tc.accent.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: weight,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
