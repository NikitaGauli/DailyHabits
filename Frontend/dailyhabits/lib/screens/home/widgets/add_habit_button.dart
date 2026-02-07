import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';
/// ===============================================================
///
/// A reusable button widget to trigger the action of adding a new habit.
///
/// Parameters:
/// - [onPressed]: Callback function executed when the button is tapped.
///
/// UI:
/// - Displays a purple rounded button with a shadow.
/// - Contains an "add" icon and text label "Add New Habit".
///
/// Usage:
/// ```dart
/// AddHabitButtonWidget(
///   onPressed: () {
///     // Show habit creation dialog or navigate to add habit screen
///   },
/// )
/// ```
/// ===============================================================
class AddHabitButtonWidget extends StatelessWidget {
  /// Callback triggered on button tap
  final VoidCallback onPressed;

  const AddHabitButtonWidget({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: tc.accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tc.accent.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Add New Habit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
