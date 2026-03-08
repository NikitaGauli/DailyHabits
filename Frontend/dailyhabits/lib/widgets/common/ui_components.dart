// =============================================================================
// DailyHabits — Reusable UI Components
// =============================================================================
// Production-quality, theme-aware building blocks used across multiple
// screens. Designed for maximum reuse and visual consistency.
//
// Components:
//   • [SectionCard]     — Elevated container for grouped content.
//   • [GradientStatChip] — Compact metric display with gradient accent.
//   • [IconBadge]       — Circular icon with tinted background.
//   • [EmptyStateWidget] — Friendly placeholder for empty lists.
//   • [AnimatedProgressBar] — Smooth linear progress indicator.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/app_animations.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION CARD — Elevated Content Container
// ═══════════════════════════════════════════════════════════════════════════════

/// A themed card wrapper with soft shadow, border, and consistent padding.
///
/// Used to group related content into visually distinct sections. Adapts
/// to light/dark themes automatically via [ThemeColors].
///
/// ```dart
/// SectionCard(
///   child: Column(children: [/* ... */]),
/// )
/// ```
class SectionCard extends StatelessWidget {
  /// The card's content.
  final Widget child;

  /// Internal padding. Defaults to 20px all around.
  final EdgeInsetsGeometry padding;

  /// Outer margin. Defaults to zero.
  final EdgeInsetsGeometry margin;

  /// Optional gradient overlay (e.g., for hero cards).
  final Gradient? gradient;

  /// Override border radius. Defaults to 20px.
  final double borderRadius;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.gradient,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? tc.card : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: tc.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: tc.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GRADIENT STAT CHIP — Compact Metric Display
// ═══════════════════════════════════════════════════════════════════════════════

/// A small stat display with icon, value, and label — accented by a
/// subtle gradient background. Ideal for quick-view dashboard metrics.
///
/// ```dart
/// GradientStatChip(
///   icon: Icons.local_fire_department_rounded,
///   value: '12',
///   label: 'Streak',
///   color: AppColors.warning,
/// )
/// ```
class GradientStatChip extends StatelessWidget {
  /// The leading icon.
  final IconData icon;

  /// The primary numeric value.
  final String value;

  /// A short descriptive label.
  final String label;

  /// The accent color for icon and gradient tint.
  final Color color;

  const GradientStatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tc.card,
            color.withValues(alpha: tc.isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tinted icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          // Numeric value
          Text(
            value,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: TextStyle(
              color: tc.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ICON BADGE — Circular Tinted Icon
// ═══════════════════════════════════════════════════════════════════════════════

/// Small circular container with a tinted background and centered icon.
///
/// Used in settings rows, list tiles, and navigation items for consistent
/// icon presentation.
class IconBadge extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// The accent color for background tint and icon fill.
  final Color color;

  /// Overall size of the badge. Default: 40.
  final double size;

  /// Icon size. Default: 20.
  final double iconSize;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

/// A polished empty-state placeholder with an icon, title, and subtitle.
///
/// Optionally includes a CTA button. Adapts to both light and dark themes.
class EmptyStateWidget extends StatelessWidget {
  /// The large icon displayed at the top.
  final IconData icon;

  /// Headline text (e.g., "No habits yet").
  final String title;

  /// Supportive body text with instructions.
  final String subtitle;

  /// Optional action button label.
  final String? actionLabel;

  /// Optional action callback.
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tc.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon with gradient ring
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tc.primary.withValues(alpha: 0.08),
                  tc.primary.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(icon, size: 44, color: tc.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(color: tc.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMd.copyWith(
              color: tc.textMuted,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANIMATED PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════════

/// A smooth, theme-aware linear progress bar with rounded caps and an
/// animated fill transition.
///
/// ```dart
/// AnimatedProgressBar(progress: 0.65, color: AppColors.success)
/// ```
class AnimatedProgressBar extends StatelessWidget {
  /// Progress value from 0.0 to 1.0.
  final double progress;

  /// Fill color. Defaults to primary theme color.
  final Color? color;

  /// Track height. Default: 8.
  final double height;

  /// Animation duration. Default: 800ms.
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final fillColor = color ?? tc.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: AppCurves.smooth,
      builder: (_, value, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: fillColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fillColor, fillColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}
