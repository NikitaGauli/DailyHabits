import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.color = const Color(0xFF312C51), // AppColors.primaryBg
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(color: tc.border, width: 1.0),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
