// =============================================================================
// File: level_up_dialog.dart
// Description: A celebratory dialog that appears when the user levels up.
//              Features a gradient background, animated level number,
//              reward summary, and confetti-style particles.
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';

/// Shows a level-up celebration dialog.
///
/// Call as:
/// ```dart
/// LevelUpDialog.show(context, newLevel: 5, levelName: 'Expert');
/// ```
class LevelUpDialog {
  static void show(
    BuildContext context, {
    required int newLevel,
    required String levelName,
    int xpBonus = 0,
    int coinBonus = 0,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level Up',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelUpContent(
          newLevel: newLevel,
          levelName: levelName,
          xpBonus: xpBonus,
          coinBonus: coinBonus,
        );
      },
    );
  }
}

class _LevelUpContent extends StatefulWidget {
  final int newLevel;
  final String levelName;
  final int xpBonus;
  final int coinBonus;

  const _LevelUpContent({
    required this.newLevel,
    required this.levelName,
    required this.xpBonus,
    required this.coinBonus,
  });

  @override
  State<_LevelUpContent> createState() => _LevelUpContentState();
}

class _LevelUpContentState extends State<_LevelUpContent>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _random = Random();
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    // Confetti animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    // Level number pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Generate confetti particles
    _particles = List.generate(30, (i) {
      return _ConfettiParticle(
        x: _random.nextDouble(),
        speed: 0.3 + _random.nextDouble() * 0.7,
        size: 4 + _random.nextDouble() * 6,
        color: [
          const Color(0xFF4F46E5),
          const Color(0xFF14B8A6),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
          const Color(0xFF8B5CF6),
          const Color(0xFF22C55E),
        ][i % 6],
        delay: _random.nextDouble() * 0.3,
      );
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 320,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Confetti behind the card
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return SizedBox(
                  width: 320,
                  height: 400,
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      particles: _particles,
                    ),
                  ),
                );
              },
            ),

            // Main Card
            Material(
              color: Colors.transparent,
              child: Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Star icon
                    const Text('🌟', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),

                    // "LEVEL UP" text
                    const Text(
                      'LEVEL UP!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Level number with pulse
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Text(
                        '${widget.newLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Level name
                    Text(
                      widget.levelName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rewards
                    if (widget.xpBonus > 0 || widget.coinBonus > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.xpBonus > 0) ...[
                              const Icon(Icons.stars_rounded,
                                  color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.xpBonus} XP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (widget.xpBonus > 0 && widget.coinBonus > 0)
                              const SizedBox(width: 16),
                            if (widget.coinBonus > 0) ...[
                              const Icon(Icons.monetization_on_rounded,
                                  color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.coinBonus}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Awesome!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Confetti Particle Model + Painter
// =============================================================================

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double delay;

  const _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  const _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = p.x * size.width;
      final y = size.height * 0.3 - (t * size.height * p.speed);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final spread = sin(t * pi * 3) * 30;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x + spread, y), p.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
