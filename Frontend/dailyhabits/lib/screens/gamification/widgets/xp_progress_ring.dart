// =============================================================================
// File: xp_progress_ring.dart
// Description: Animated circular progress ring displaying the user's current
//              level number with a gradient arc representing XP progress toward
//              the next level.
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';

/// An animated circular ring that fills based on XP progression.
///
/// Displays the numeric [level] in the centre and draws a gradient arc
/// from 0 to [progress] (0.0–1.0). The arc animates smoothly on mount
/// and whenever [progress] changes.
class XPProgressRing extends StatefulWidget {
  /// Current user level displayed in the ring centre.
  final int level;

  /// XP progress fraction (0.0 = 0%, 1.0 = 100%) toward the next level.
  final double progress;

  /// Diameter of the ring widget in logical pixels.
  final double size;

  const XPProgressRing({
    super.key,
    required this.level,
    required this.progress,
    this.size = 80,
  });

  @override
  State<XPProgressRing> createState() => _XPProgressRingState();
}

class _XPProgressRingState extends State<XPProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(XPProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _oldProgress = oldWidget.progress;
      _animation = Tween<double>(begin: _oldProgress, end: widget.progress)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _animation.value.clamp(0.0, 1.0),
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              strokeWidth: 6,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LV',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black38,
                      fontSize: widget.size * 0.12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    '${widget.level}',
                    style: TextStyle(
                      color: const Color(0xFF4F46E5),
                      fontSize: widget.size * 0.32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Custom Painter — Gradient Arc
// =============================================================================

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    // Track (background circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, trackPaint);

    if (progress <= 0) return;

    // Gradient arc (progress)
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [
          Color(0xFF818CF8), // Indigo-400
          Color(0xFF4F46E5), // Indigo-600
          Color(0xFF14B8A6), // Teal-500
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,             // Start at 12 o'clock
      2 * pi * progress,   // Sweep proportional to progress
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress;
  }
}
