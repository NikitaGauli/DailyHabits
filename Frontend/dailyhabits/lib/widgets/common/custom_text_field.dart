// DailyHabits — Custom Text Field Widget
//
// A fully themed [TextFormField] wrapper that provides consistent styling,
// validation support, and theme-aware colors throughout the app.  Used on
// authentication screens, habit forms, and settings panels.
//
// See also:
// - [AppRadius]     — border-radius tokens applied to input borders.
// - [ThemeColors]   — runtime color resolution for fill, border, and text.

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// A themed text field with consistent styling for the DailyHabits app.
///
/// Wraps [TextFormField] with the app’s design-system border radii, fill
/// colors, and focus/error border treatments.  Supports an optional leading
/// icon, suffix widget, obscured text, multi-line input, and form validation.
///
/// ```dart
/// CustomTextField(
///   controller: _emailCtrl,
///   hintText: 'you@example.com',
///   prefixIcon: Icons.email_outlined,
///   validator: (v) => v!.isEmpty ? 'Required' : null,
/// )
/// ```
class CustomTextField extends StatelessWidget {
  /// Optional controller to read/write the field’s text value.
  final TextEditingController? controller;

  /// Placeholder text shown when the field is empty.
  final String? hintText;

  /// Floating label displayed above the field when focused.
  final String? labelText;

  /// Material icon rendered to the left of the input area.
  final IconData? prefixIcon;

  /// Widget placed at the trailing end (e.g., visibility toggle).
  final Widget? suffixIcon;

  /// Whether to mask the input (e.g., for passwords). Defaults to `false`.
  final bool obscureText;

  /// Keyboard type hint for the platform input method.
  final TextInputType keyboardType;

  /// Optional form validator returning an error string or `null`.
  final String? Function(String?)? validator;

  /// Callback fired on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Number of visible text lines. Defaults to `1`.
  final int maxLines;

  /// Whether the field accepts user input. Defaults to `true`.
  final bool enabled;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    // Build a TextFormField with theme-aware decoration that responds
    // to light/dark mode through the ThemeColors extension.
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: tc.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        hintStyle: TextStyle(
          color: tc.textMuted,
        ),
        labelStyle: TextStyle(
          color: tc.textSecondary,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: tc.textMuted)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: tc.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: tc.surfaceVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: tc.accent,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: tc.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: tc.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
