// DailyHabits — Authentication Button Widget
//
// A reusable, gradient-filled (or outlined) button designed for the
// authentication flow.  Supports a loading state with an embedded
// [CircularProgressIndicator] and adapts its appearance to the active theme.
//
// See also:
// - [AppColors.accentGradient] — the gradient applied to filled buttons.
// - [AppTextStyles.button]     — the base text style used for the label.

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// A premium gradient button used across authentication screens.
///
/// Renders as either a **filled gradient** button (default) or an
/// **outlined** variant controlled by the [outlined] flag.  When
/// [isLoading] is `true`, the label is replaced with a spinner and
/// taps are disabled to prevent duplicate submissions.
///
/// ```dart
/// AuthButton(
///   label: 'Sign In',
///   onPressed: _handleSignIn,
///   isLoading: _isBusy,
/// )
/// ```
class AuthButton extends StatelessWidget {
  /// The text displayed inside the button.
  final String label;

  /// Callback invoked when the button is tapped (ignored while loading).
  final VoidCallback onPressed;

  /// When `true`, shows a [CircularProgressIndicator] and disables taps.
  final bool isLoading;

  /// When `true`, renders an outlined variant instead of the filled gradient.
  final bool outlined;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    // ── Outlined variant ───────────────────────────────────────────────
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: tc.accent, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tc.accent,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.button.copyWith(
                    color: tc.accent,
                  ),
                ),
        ),
      );
    }

    // ── Filled gradient variant ────────────────────────────────────────
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            // Subtle colored glow beneath the button
            BoxShadow(
              color: tc.primary.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
