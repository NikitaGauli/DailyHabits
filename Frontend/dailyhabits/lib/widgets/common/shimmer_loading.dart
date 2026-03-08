// =============================================================================
// DailyHabits — Shimmer Loading Placeholder
// =============================================================================
// A polished loading skeleton that pulses with a shimmer gradient,
// providing clear visual feedback while content loads.
//
// Inspired by Notion's and Facebook's content-loading patterns.
//
// Usage:
//   ShimmerBox(width: 200, height: 16)              // single text line
//   ShimmerBox.circle(radius: 24)                    // avatar placeholder
//   ShimmerCardPlaceholder()                         // full card skeleton
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  SHIMMER BOX — Atomic Placeholder Element
// ═══════════════════════════════════════════════════════════════════════════════

/// A single shimmering rectangle or circle used as a content placeholder.
///
/// Animates a linear gradient sweep from left to right, creating the
/// characteristic loading "shimmer" effect.
class ShimmerBox extends StatefulWidget {
  /// Width of the shimmer box. Uses parent width if null.
  final double? width;

  /// Height of the shimmer box.
  final double height;

  /// Border radius in logical pixels (uniform circular).
  final double borderRadius;

  /// Creates a rectangular shimmer placeholder.
  ///
  /// [borderRadius] is a convenience parameter (in logical pixels) that
  /// creates a uniform circular [BorderRadius]. Defaults to `8`.
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  /// Creates a circular shimmer placeholder (e.g., avatar skeleton).
  const ShimmerBox.circle({
    super.key,
    required double radius,
  })  : width = radius * 2,
        height = radius * 2,
        borderRadius = 999;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final baseColor = tc.surfaceVariant;
    final highlightColor = tc.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHIMMER CARD PLACEHOLDER — Habit Card Skeleton
// ═══════════════════════════════════════════════════════════════════════════════

/// A full habit-card-shaped skeleton used while the habit list loads.
///
/// Mimics the layout of [HabitCardWidget] with three shimmer lines
/// (icon, title, subtitle) to set accurate user expectations.
class ShimmerCardPlaceholder extends StatelessWidget {
  const ShimmerCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Icon placeholder
          const ShimmerBox(width: 46, height: 46,
            borderRadius: 14,
          ),
          const SizedBox(width: 14),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14,
                  borderRadius: 6,
                ),
                const SizedBox(height: 8),
                ShimmerBox(width: 100, height: 10,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
          // Checkbox placeholder
          const ShimmerBox(width: 36, height: 36,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHIMMER LIST — Multiple Card Skeletons
// ═══════════════════════════════════════════════════════════════════════════════

/// Renders [count] shimmer card placeholders, perfect for initial load states.
class ShimmerHabitList extends StatelessWidget {
  /// Number of placeholder cards to display.
  final int count;

  const ShimmerHabitList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const ShimmerCardPlaceholder(),
      ),
    );
  }
}
