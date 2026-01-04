import 'package:flutter/material.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.bar_chart_rounded, 'Statistics', 1),
              _buildNavItem(Icons.calendar_today_rounded, 'Habits', 2),
              _buildNavItem(Icons.emoji_events_rounded, 'Rewards', 3),
              _buildNavItem(Icons.settings_rounded, 'Settings', 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an individual navigation item with icon and label
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onIndexChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: 0.4),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
