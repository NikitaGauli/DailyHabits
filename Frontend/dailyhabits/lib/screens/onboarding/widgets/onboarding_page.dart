// =============================================================================
// onboarding_page.dart — Onboarding Page Data Model & Widget
// =============================================================================
// Defines the [OnboardingPageData] configuration model and the
// [OnboardingPageWidget] that renders a single onboarding page.
//
// Also contains two supporting private widgets:
//  • [_GlassmorphicContainer] – frosted-glass visual container.
//  • [_ImageContent] – placeholder image with optional overlay icon.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/onboarding/widgets/calendar_widget.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// OnboardingPageData
/// ---------------------------------------------------------------------------
/// Immutable configuration model representing a single onboarding page.
///
/// Purpose:
///  • Centralizes page styling and content
///  • Keeps UI widgets clean and declarative
///  • Allows easy addition or modification of onboarding pages
/// ---------------------------------------------------------------------------
class OnboardingPageData {
  /// Background gradient of the page
  final LinearGradient gradient;

  /// Image asset path displayed on the page
  final String imagePath;

  /// Main headline text
  final String title;

  /// Supporting description text
  final String description;

  /// Optional overlay icon displayed above the image
  final IconData? overlayIcon;

  /// Size of the overlay icon
  final double iconSize;

  /// Whether to show the calendar widget instead of image content
  final bool showCalendar;

  /// Marks the final onboarding page (affects skip button visibility)
  final bool isLastPage;

  const OnboardingPageData({
    required this.gradient,
    required this.imagePath,
    required this.title,
    required this.description,
    this.overlayIcon,
    this.iconSize = 70,
    this.showCalendar = false,
    this.isLastPage = false,
  });
}

/// ---------------------------------------------------------------------------
/// OnboardingPageWidget
/// ---------------------------------------------------------------------------
/// Visual representation of a single onboarding page.
///
/// Responsibilities:
///  • Applies gradient background
///  • Displays page content (image / calendar)
///  • Handles skip action visibility
///  • Maintains consistent layout across all pages
/// ---------------------------------------------------------------------------
class OnboardingPageWidget extends StatelessWidget {
  const OnboardingPageWidget({
    super.key,
    required this.pageData,
    required this.onSkip,
  });

  /// Data configuration for this page
  final OnboardingPageData pageData;

  /// Callback triggered when user presses "Skip"
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      decoration: BoxDecoration(gradient: pageData.gradient),
      child: SafeArea(
        child: Stack(
          children: [
            // --------------------------------------------------------------
            // Skip Button (hidden on final page)
            // --------------------------------------------------------------
            if (!pageData.isLastPage)
              Positioned(
                top: 20,
                right: 20,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // --------------------------------------------------------------
            // Main Content
            // --------------------------------------------------------------
            Center(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Glassmorphic content container
                  _GlassmorphicContainer(
                    child: pageData.showCalendar
                        ? const CalendarWidget()
                        : _ImageContent(
                            imagePath: pageData.imagePath,
                            overlayIcon: pageData.overlayIcon,
                            iconSize: pageData.iconSize,
                          ),
                  ),

                  const Spacer(flex: 1),

                  // Page Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      pageData.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: tc.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Page Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      pageData.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: tc.textSecondary,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Glassmorphic Container
/// ---------------------------------------------------------------------------
/// A reusable glass-effect container used to display onboarding visuals.
///
/// Design Characteristics:
///  • Frosted glass appearance
///  • Rounded layered borders
///  • Subtle shadow depth
/// ---------------------------------------------------------------------------
class _GlassmorphicContainer extends StatelessWidget {
  const _GlassmorphicContainer({required this.child});

  /// Child widget displayed inside the container
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        border: Border.all(
          color: tc.border,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: tc.textPrimary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(39),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tc.surfaceVariant,
            borderRadius: BorderRadius.circular(39),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(32),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Image Content
/// ---------------------------------------------------------------------------
/// Displays the main onboarding image with an optional overlay icon.
///
/// Design:
///  • Gradient background with decorative floating orbs
///  • Glowing hero icon with gradient circle and soft shadow
///  • Subtle animated-look decorative dots for visual depth
/// ---------------------------------------------------------------------------
class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.imagePath,
    this.overlayIcon,
    required this.iconSize,
  });

  /// Image asset path
  final String imagePath;

  /// Optional overlay icon displayed at the center
  final IconData? overlayIcon;

  /// Overlay icon size
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tc.accent.withValues(alpha: 0.07),
              tc.surface,
              tc.accent.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Decorative background orbs ──
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -24,
              left: -12,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.accent.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: 20,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 28,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              top: 60,
              right: 40,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.accent.withValues(alpha: 0.2),
                ),
              ),
            ),

            // ── Hero icon with gradient glow ──
            if (overlayIcon != null)
              Center(
                child: Container(
                  width: iconSize + 40,
                  height: iconSize + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tc.accent,
                        tc.accent.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tc.accent.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: tc.accent.withValues(alpha: 0.15),
                        blurRadius: 60,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    overlayIcon,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),

            // ── Fallback if no overlay icon ──
            if (overlayIcon == null)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tc.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: tc.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
