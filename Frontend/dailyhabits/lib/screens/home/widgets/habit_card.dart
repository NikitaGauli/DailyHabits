// **habit_card.dart** — Individual Habit Card Widget
//
// Provides [HabitCardWidget], a premium card component used on the home
// dashboard to represent a single habit. Features include:
//  • Colour-tinted icon with soft background
//  • Title with completion strikethrough animation
//  • Time / category metadata line
//  • Current streak badge (visible when streak > 0)
//  • Animated completion checkbox with smooth colour transitions
//  • Subtle left-edge accent bar reflecting the habit colour
//
// This widget is **stateless** — all state (completion, streaks, etc.) is
// owned by the parent controller and communicated through the [Habit] model
// and callback closures.
//
// See also:
//   - [Habit] for the data model.
//   - [HomeController] / [HomePage] for usage context.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';
import '../../../models/habit.dart';

/// ===============================================================
/// HabitCardWidget
/// ===============================================================
///
/// A polished card that represents a single habit on the dashboard.
/// Shows habit icon, title, metadata, streak indicator, and a
/// toggleable animated completion checkbox.
///
/// Parameters:
/// - [habit]:    The [Habit] model driving this card's content.
/// - [onTap]:    Callback for card body tap (navigate to detail/edit).
/// - [onToggle]: Callback for checkbox tap (mark complete/incomplete).
///
/// Usage:
/// ```dart
/// HabitCardWidget(
///   habit: myHabit,
///   onTap: () => editHabit(myHabit),
///   onToggle: () => toggleHabitCompletion(index),
/// )
/// ```
/// ===============================================================
class HabitCardWidget extends StatelessWidget {
  /// The [Habit] data model driving this card's content.
  final Habit habit;

  /// Action when the card body is tapped (typically navigates to detail/edit).
  final VoidCallback onTap;

  /// Action when the trailing checkbox is toggled (marks habit complete/incomplete).
  final VoidCallback onToggle;

  const HabitCardWidget({
    super.key,
    required this.habit,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleTapWidget(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.smooth,
          decoration: BoxDecoration(
            color: habit.isCompleted
                ? tc.surfaceVariant.withValues(alpha: 0.6)
                : tc.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: habit.isCompleted
                  ? habit.color.withValues(alpha: 0.25)
                  : tc.border.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: habit.isCompleted
                ? []
                : [
                    BoxShadow(
                      color: habit.color.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                // ── Left accent bar ──────────────────────────────
                // A thin coloured strip on the leading edge that
                // visually ties the card to the habit's colour.
                AnimatedContainer(
                  duration: AppDurations.short,
                  width: 4,
                  height: 72,
                  color: habit.isCompleted
                      ? habit.color.withValues(alpha: 0.3)
                      : habit.color,
                ),

                // ── Card content ─────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Icon container — colored background with
                        // habit-specific icon and completion fade
                        AnimatedContainer(
                          duration: AppDurations.short,
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: habit.isCompleted
                                ? habit.color.withValues(alpha: 0.08)
                                : habit.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: AnimatedOpacity(
                            duration: AppDurations.short,
                            opacity: habit.isCompleted ? 0.45 : 1.0,
                            child: Icon(
                              habit.icon,
                              color: habit.color,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title, metadata, and streak badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title with animated strikethrough
                              AnimatedDefaultTextStyle(
                                duration: AppDurations.short,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: habit.isCompleted
                                      ? tc.textMuted
                                      : tc.textPrimary,
                                  decoration: habit.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: tc.textMuted,
                                ),
                                child: Text(
                                  habit.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Metadata row: time · category (+ streak)
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: tc.textMuted.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    habit.time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tc.textMuted,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        color: tc.textMuted.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      habit.category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: tc.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Streak badge — only visible when > 0
                                  if (habit.currentStreak > 0) ...[
                                    const SizedBox(width: 8),
                                    _StreakBadge(
                                      streak: habit.currentStreak,
                                      color: habit.color,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Animated completion checkbox
                        _CompletionCheckbox(
                          isCompleted: habit.isCompleted,
                          color: habit.color,
                          onTap: onToggle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _StreakBadge — Compact streak indicator chip
// =============================================================================

/// A small pill-shaped badge showing the current streak count with a
/// fire emoji. Uses the habit's colour for tinting.
class _StreakBadge extends StatelessWidget {
  final int streak;
  final Color color;

  const _StreakBadge({required this.streak, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _CompletionCheckbox — Animated check toggle
// =============================================================================

/// A custom animated checkbox that transitions between an empty bordered
/// circle and a filled colour circle with a white checkmark.
class _CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final Color color;
  final VoidCallback onTap;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.smooth,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isCompleted ? color : tc.textMuted.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            child: isCompleted
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 17,
                    key: ValueKey('check'),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
    );
  }
}
