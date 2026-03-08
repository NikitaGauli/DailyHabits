// =============================================================================
// DailyHabits — Animation & Transition Utilities
// =============================================================================
// Production-grade animation constants, page route transitions, and reusable
// animation builders for a fluid, modern user experience.
//
// Design Principles:
//   • Transitions should feel natural and purposeful, never gratuitous.
//   • Use spring-based curves for organic motion.
//   • Keep durations under 400ms for responsiveness.
//   • Respect `MediaQuery.disableAnimations` for accessibility.
//
// Usage:
//   Navigator.push(context, AppPageRoute.fade(const SettingsScreen()));
//   AnimatedContainer(duration: AppDurations.medium, curve: AppCurves.smooth);
// =============================================================================

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DURATION TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

/// Standardized animation duration tokens.
///
/// Consistent timing creates a cohesive motion language across the app.
/// Based on Material Design 3 motion guidelines.
class AppDurations {
  AppDurations._();

  /// 100ms — micro-interactions (button press, toggle).
  static const Duration instant = Duration(milliseconds: 100);

  /// 150ms — short transitions (opacity, scale taps, checkbox).
  static const Duration short = Duration(milliseconds: 150);

  /// 200ms — quick feedback (checkbox, ripple).
  static const Duration fast = Duration(milliseconds: 200);

  /// 300ms — standard transitions (page, modal).
  static const Duration medium = Duration(milliseconds: 300);

  /// 450ms — emphasized transitions (hero, expand).
  static const Duration slow = Duration(milliseconds: 450);

  /// 600ms — dramatic reveals (onboarding, celebration).
  static const Duration dramatic = Duration(milliseconds: 600);

  /// 1200ms — progress animations (ring fill, chart draw).
  static const Duration progress = Duration(milliseconds: 1200);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CURVE TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

/// Curated animation curves for different motion contexts.
///
/// Each curve is selected to match the motion intent:
///   • [smooth] — General-purpose ease for most transitions.
///   • [spring] — Slight overshoot for playful interactions.
///   • [decelerate] — Entering elements that slow to a stop.
///   • [accelerate] — Exiting elements that speed up and vanish.
///   • [bounce] — Celebratory or attention-grabbing moments.
class AppCurves {
  AppCurves._();

  /// Smooth ease-in-out — default for most transitions.
  static const Curve smooth = Curves.easeOutCubic;

  /// Emphasized ease — used for page transitions.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Spring-like overshoot — buttons, toggles, playful feedback.
  static const Curve spring = Curves.elasticOut;

  /// Deceleration — entering elements (slide in, expand).
  static const Curve decelerate = Curves.decelerate;

  /// Acceleration — exiting elements (slide out, collapse).
  static const Curve accelerate = Curves.easeInCubic;

  /// Bounce — celebrations, achievements, rewards.
  static const Curve bounce = Curves.bounceOut;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PAGE ROUTE TRANSITIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Factory for premium page route transitions.
///
/// Provides [fade], [slideUp], [slideRight], and [scale] transitions that
/// can be used as drop-in replacements for [MaterialPageRoute].
///
/// Example:
/// ```dart
/// Navigator.push(context, AppPageRoute.slideUp(const SettingsScreen()));
/// ```
class AppPageRoute {
  AppPageRoute._();

  /// Crossfade transition — ideal for tab-like navigation.
  static Route<T> fade<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: duration ?? AppDurations.medium,
      reverseTransitionDuration: duration ?? AppDurations.fast,
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppCurves.smooth,
          ),
          child: child,
        );
      },
    );
  }

  /// Slide-up from bottom — modals, detail screens, and settings.
  static Route<T> slideUp<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: duration ?? AppDurations.medium,
      reverseTransitionDuration: duration ?? AppDurations.fast,
      transitionsBuilder: (_, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: AppCurves.emphasized,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }

  /// Slide-right — standard forward navigation (push).
  static Route<T> slideRight<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: duration ?? AppDurations.medium,
      reverseTransitionDuration: duration ?? AppDurations.fast,
      transitionsBuilder: (_, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: AppCurves.emphasized,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.25, 0),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }

  /// Scale-up with fade — launching features, expanding cards.
  static Route<T> scale<T>(Widget page, {Duration? duration}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: duration ?? AppDurations.medium,
      reverseTransitionDuration: duration ?? AppDurations.fast,
      transitionsBuilder: (_, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: AppCurves.smooth,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STAGGERED ANIMATION HELPER
// ═══════════════════════════════════════════════════════════════════════════════

/// Drives staggered entrance animations for list items.
///
/// Each child receives a delayed [Interval] so items cascade smoothly
/// into view. Used by dashboards, habit lists, and settings pages.
///
/// Example:
/// ```dart
/// StaggeredListAnimation(
///   itemCount: habits.length,
///   child: (index, animation) => FadeTransition(
///     opacity: animation,
///     child: HabitCard(habit: habits[index]),
///   ),
/// )
/// ```
class StaggeredListAnimation extends StatefulWidget {
  /// Total number of items to animate.
  final int itemCount;

  /// Builder that receives the item index and its [Animation<double>].
  final Widget Function(int index, Animation<double> animation) child;

  /// Base delay between items. Default: 50ms.
  final Duration staggerDelay;

  /// Duration of each item's animation. Default: 400ms.
  final Duration itemDuration;

  const StaggeredListAnimation({
    super.key,
    required this.itemCount,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 400),
  });

  @override
  State<StaggeredListAnimation> createState() =>
      _StaggeredListAnimationState();
}

class _StaggeredListAnimationState extends State<StaggeredListAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final totalDuration = widget.itemDuration +
        widget.staggerDelay * (widget.itemCount - 1).clamp(0, 20);
    _controller = AnimationController(vsync: this, duration: totalDuration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(widget.itemCount, (index) {
        final start =
            (widget.staggerDelay.inMilliseconds * index) /
            _controller.duration!.inMilliseconds;
        final end = (start +
                widget.itemDuration.inMilliseconds /
                    _controller.duration!.inMilliseconds)
            .clamp(0.0, 1.0);
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start.clamp(0.0, 1.0), end, curve: AppCurves.smooth),
        );
        return widget.child(index, animation);
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANIMATED SCALE BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

/// A button wrapper that applies a subtle scale-down effect on press.
///
/// Provides tactile feedback without relying solely on ink splashes,
/// making it suitable for custom card-tappable surfaces.
class ScaleTapWidget extends StatefulWidget {
  /// The child widget to wrap.
  final Widget child;

  /// Callback when the widget is tapped.
  final VoidCallback? onTap;

  /// Scale factor when pressed. Default: 0.97.
  final double scaleDown;

  const ScaleTapWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
  });

  @override
  State<ScaleTapWidget> createState() => _ScaleTapWidgetState();
}

class _ScaleTapWidgetState extends State<ScaleTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.instant,
      reverseDuration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppCurves.smooth,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
