// =============================================================================
// DailyHabits — Habit Completion Celebration Animation
// =============================================================================
// Renders a brief, delightful celebration animation when a user completes
// a habit. Includes a scale-bounce check mark, radiating particles, and
// an optional confetti burst.
//
// Inspired by Duolingo's lesson-complete animation and Habitica's reward
// feedback — designed to trigger dopamine and reinforce the habit loop.
//
// Usage:
//   CompletionCelebration.show(context, color: AppColors.success);
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages the overlay lifecycle for habit-completion celebrations.
///
/// Call [show] when a habit is toggled to "completed" to play a brief
/// full-screen celebration animation.
class CompletionCelebration {
  CompletionCelebration._();

  /// Currently active overlay entry (null when not displayed).
  static OverlayEntry? _entry;

  /// Shows a celebration overlay centered on the screen.
  ///
  /// [color] — the accent color for the check and particles.
  /// Auto-dismisses after 1.2 seconds.
  static void show(BuildContext context, {Color? color}) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (_) => _CelebrationWidget(
        color: color ?? AppColors.success,
        onComplete: dismiss,
      ),
    );

    overlay.insert(_entry!);
  }

  /// Removes the celebration overlay immediately.
  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CELEBRATION WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _CelebrationWidget extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;

  const _CelebrationWidget({required this.color, required this.onComplete});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;

  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _particleProgress;

  // Random particle directions
  final List<_Particle> _particles = List.generate(
    12,
    (_) => _Particle.random(),
  );

  @override
  void initState() {
    super.initState();

    // Main animation: check mark + ring
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _checkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    ));

    _checkOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
    ));

    _ringScale = Tween(begin: 0.5, end: 2.5).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _ringOpacity = Tween(begin: 0.6, end: 0.0).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    ));

    // Particle burst
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _particleProgress = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));

    // Start animation sequence
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _particleController.forward();
    });

    // Auto-dismiss after completion
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_mainController, _particleController]),
            builder: (_, _) => SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Expanding ring
                  Transform.scale(
                    scale: _ringScale.value,
                    child: Opacity(
                      opacity: _ringOpacity.value.clamp(0.0, 1.0),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.color,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Radiating particles
                  ..._particles.map((p) {
                    final dx = cos(p.angle) * p.distance * _particleProgress.value;
                    final dy = sin(p.angle) * p.distance * _particleProgress.value;
                    final opacity = (1.0 - _particleProgress.value).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: p.size,
                          height: p.size,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Check mark circle
                  Transform.scale(
                    scale: _checkScale.value,
                    child: Opacity(
                      opacity: _checkOpacity.value.clamp(0.0, 1.0),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PARTICLE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// A single celebration particle with random direction and size.
class _Particle {
  final double angle;
  final double distance;
  final double size;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
  });

  /// Generates a particle with random angle, distance, and size.
  factory _Particle.random() {
    final rng = Random();
    return _Particle(
      angle: rng.nextDouble() * 2 * pi,
      distance: 40 + rng.nextDouble() * 35,
      size: 4 + rng.nextDouble() * 5,
    );
  }
}
