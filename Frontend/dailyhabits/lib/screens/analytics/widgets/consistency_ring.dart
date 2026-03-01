// =============================================================================
// File: consistency_ring.dart
// Project: DailyHabits — Personal Habit Tracking Application
// Description: A reusable circular progress indicator that animates from zero
//              to the provided consistency value. Used across the analytics
//              dashboard to visually represent daily completion rates.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// An animated circular progress ring that displays a consistency percentage.
///
/// Renders two concentric [CircularProgressIndicator] widgets:
/// - A **background ring** at full opacity representing the total.
/// - A **foreground ring** animated via [TweenAnimationBuilder] to the target
///   [consistency] value.
///
/// A default centre label shows the percentage and the word “Consistent”;
/// callers may supply a custom [child] to override the label content.
///
/// Example usage:
/// ```dart
/// ConsistencyRing(
///   consistency: 0.73,
///   size: 120,
///   color: Colors.green,
/// )
/// ```
class ConsistencyRing extends StatelessWidget {
  /// The completion ratio expressed as a value between `0.0` and `1.0`.
  final double consistency; // 0.0 to 1.0

  /// Overall diameter of the ring widget in logical pixels.
  final double size;

  /// Width of the circular stroke in logical pixels.
  final double strokeWidth;

  /// Foreground ring colour; defaults to the theme’s accent colour.
  final Color? color;

  /// Background ring colour; defaults to the theme’s surface colour.
  final Color? backgroundColor;

  /// Optional widget rendered in the centre of the ring.
  /// When `null`, a percentage label is shown by default.
  final Widget? child;

  const ConsistencyRing({
    super.key,
    required this.consistency,
    this.size = 120,
    this.strokeWidth = 10,
    this.color,
    this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final effectiveColor = color ?? tc.accent;
    final effectiveBgColor = backgroundColor ?? tc.surface;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring — always at full progress to show the track
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              color: effectiveBgColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Foreground ring — animates from 0 to [consistency] over 1.5 s
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: consistency),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  color: effectiveColor,
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Centre content — either the provided child or a default label
          if (child != null)
            child!
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(consistency * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
                Text(
                  'Consistent',
                  style: TextStyle(
                    fontSize: size * 0.1,
                    color: tc.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
