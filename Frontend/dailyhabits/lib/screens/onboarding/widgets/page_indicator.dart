import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// PageIndicator
/// ---------------------------------------------------------------------------
/// A modern, animated page indicator used in onboarding flows.
///
/// Purpose:
///  • Visually communicates the current onboarding step
///  • Provides subtle animation feedback during page transitions
///  • Matches the provided UI prototype exactly
///
/// Design:
///  • Active indicator expands horizontally
///  • Inactive indicators remain compact
///  • Smooth animated transitions for width and color
/// ---------------------------------------------------------------------------
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  /// Total number of pages in the onboarding flow
  final int pageCount;

  /// Index of the currently active page (zero-based)
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => _IndicatorDot(isActive: index == currentPage),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Indicator Dot
/// ---------------------------------------------------------------------------
/// Represents a single indicator element.
/// Separated for clarity and potential future reuse or customization.
/// ---------------------------------------------------------------------------
class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot({required this.isActive});

  /// Determines whether this indicator represents the active page
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 5),

      // Active indicator stretches horizontally for emphasis
      width: isActive ? 32 : 8,
      height: 8,

      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
