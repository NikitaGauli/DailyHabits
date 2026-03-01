// **bottom_navigation.dart** — Custom Bottom Navigation Bar Widget
//
// Provides [BottomNavigationWidget], a five-tab bottom navigation bar
// for the DailyHabits app. Tabs include Home, Statistics, Habits,
// Rewards, and Settings.
//
// Selection state is managed externally via [selectedIndex] and
// communicated back through [onIndexChanged].
//
// See also:
//   - [HomePage._buildBottomNav] for the inline variant currently in use.
//   - [HomeController.changeNavigationIndex] for tab switching logic.

// =============================================================================
// Imports
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/theme/app_theme.dart';

/// ===============================================================
/// BottomNavigationWidget
/// ===============================================================
///
/// A customizable bottom navigation bar for the DailyHabits app.
///
/// Parameters:
/// - [selectedIndex]: The currently selected navigation index.
/// - [onIndexChanged]: Callback function called when a navigation item is tapped.
///
/// UI:
/// - Displays 5 navigation items: Home, Statistics, Habits, Rewards, Settings.
/// - Highlights the selected item with a purple color.
/// - Uses icons with labels arranged vertically.
/// - Includes shadow and background styling for elevation.
///
/// Usage:
/// ```dart
/// BottomNavigationWidget(
///   selectedIndex: homeController.selectedIndex,
///   onIndexChanged: (index) => homeController.changeNavigationIndex(index),
/// )
/// ```
/// ===============================================================
class BottomNavigationWidget extends StatelessWidget {
  /// Currently selected navigation index
  final int selectedIndex;

  /// Callback triggered when a navigation item is tapped
  final Function(int) onIndexChanged;

  const BottomNavigationWidget({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        boxShadow: [
          BoxShadow(
            color: tc.border,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, tc),
              _buildNavItem(Icons.bar_chart_rounded, 'Statistics', 1, tc),
              _buildNavItem(Icons.calendar_today_rounded, 'Habits', 2, tc),
              _buildNavItem(Icons.emoji_events_rounded, 'Rewards', 3, tc),
              _buildNavItem(Icons.settings_rounded, 'Settings', 4, tc),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an individual navigation item with icon and label
  Widget _buildNavItem(IconData icon, String label, int index, ThemeColors tc) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onIndexChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? tc.accent
                : tc.textMuted,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? tc.accent
                  : tc.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
