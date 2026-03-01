// =============================================================================
// File: xp_celebration_overlay.dart
// Description: Animated overlay that appears when the user earns XP from
//              completing a habit. Shows XP earned, streak multiplier, and
//              optional milestone celebrations with confetti effects.
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dailyhabits/models/gamification_models.dart';

/// Shows an animated XP celebration overlay on top of the current screen.
///
/// Call [XPCelebrationOverlay.show] as a static method after a habit
/// completion returns gamification data.
class XPCelebrationOverlay {
  /// Displays the celebration overlay for the given [result].
  ///
  /// Automatically dismisses after 2.5 seconds or on tap.
  static void show(BuildContext context, GamificationResult result) {
    if (result.xpEarned <= 0) return;

    final overlay = OverlayEntry(
      builder: (context) => _XPCelebrationWidget(
        result: result,
        onDismiss: () {},
      ),
    );

    Overlay.of(context).insert(overlay);

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (overlay.mounted) overlay.remove();
    });

    // Allow the onDismiss callback to remove early
    overlay.markNeedsBuild();
  }
}

// =============================================================================
// Internal Celebration Widget
// =============================================================================

class _XPCelebrationWidget extends StatefulWidget {
  final GamificationResult result;
  final VoidCallback onDismiss;

  const _XPCelebrationWidget({
    required this.result,
    required this.onDismiss,
  });

  @override
  State<_XPCelebrationWidget> createState() => _XPCelebrationWidgetState();
}

class _XPCelebrationWidgetState extends State<_XPCelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _particleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Slide-in + fade for the XP badge
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      ),
    );

    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _slideController.forward();
    _particleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final hasMilestone = result.hasMilestones;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasMilestone
                          ? [
                              const Color(0xFFF59E0B),
                              const Color(0xFFFF6B35),
                            ]
                          : [
                              const Color(0xFF4F46E5),
                              const Color(0xFF7C3AED),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (hasMilestone
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF4F46E5))
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sparkle particles
                      if (hasMilestone)
                        ..._buildParticles(),

                      // Main content
                      Row(
                        children: [
                          // XP badge
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                hasMilestone ? '🏆' : '⚡',
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasMilestone
                                      ? 'Milestone Reached!'
                                      : 'XP Earned!',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '+${result.totalXp} XP',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (result.multiplier > 1.0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${result.multiplier}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (result.coinsEarned > 0)
                                  Text(
                                    '+${result.coinsEarned} coins',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (hasMilestone)
                                  Text(
                                    result.milestones.first.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Creates decorative animated particle widgets for milestone celebrations.
  List<Widget> _buildParticles() {
    final random = Random(42);
    return List.generate(8, (i) {
      final dx = random.nextDouble() * 280 - 20;
      final dy = random.nextDouble() * 60 - 30;
      final delay = random.nextDouble() * 0.4;

      return Positioned(
        left: dx,
        top: dy,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            final t = (_particleController.value - delay).clamp(0.0, 1.0);
            return Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -40 * t),
                child: Text(
                  ['✨', '⭐', '🌟', '💫'][i % 4],
                  style: TextStyle(fontSize: 12 + random.nextDouble() * 8),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
