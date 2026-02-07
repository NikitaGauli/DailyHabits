import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

class ConsistencyRing extends StatelessWidget {
  final double consistency; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
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
          // Background Ring
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
          // Foreground Ring (Progress)
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
          // Content
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
