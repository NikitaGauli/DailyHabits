// DailyHabits — Glass Container Widget
//
// A decorative container that provides a glass-morphism–inspired card
// surface with theme-aware fill, border, and optional shadow/gradient.
// Used as the primary card wrapper throughout the app for habit tiles,
// analytics cards, and settings panels.
//
// See also:
// - [AppRadius] — default border-radius tokens.
// - [ThemeColors] — runtime card/border color resolution.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A theme-aware card container with a frosted-glass visual style.
///
/// Renders a [Container] with the current theme’s card color, a subtle
/// border, and optional shadows or gradient overlay.  Accepts standard
/// layout properties ([padding], [margin], [borderRadius]) for flexible
/// composition.
///
/// ```dart
/// GlassContainer(
///   padding: EdgeInsets.all(16),
///   borderRadius: AppRadius.lgAll,
///   child: Text('Hello'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  /// The widget rendered inside the container.
  final Widget child;

  /// Blur sigma for the glass effect (reserved for future backdrop filter).
  final double blur;

  /// Base opacity multiplier (reserved for future translucency logic).
  final double opacity;

  /// Fallback fill color; overridden at build time by `tc.card`.
  final Color color;

  /// Corner rounding. Defaults to `BorderRadius.circular(16)` if `null`.
  final BorderRadius? borderRadius;

  /// Inner content padding.
  final EdgeInsetsGeometry? padding;

  /// Outer margin around the container.
  final EdgeInsetsGeometry? margin;

  /// Optional custom border; defaults to a 1-px theme border.
  final BoxBorder? border;

  /// Optional elevation shadows applied to the outer decoration.
  final List<BoxShadow>? shadows;

  /// Optional gradient painted on top of the fill color.
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

    // Compose the final decoration using the theme’s card color, with
    // caller-supplied overrides for border, radius, and shadow.
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
