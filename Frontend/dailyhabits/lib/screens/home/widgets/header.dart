import 'package:flutter/material.dart';

/// ===============================================================
/// HeaderWidget
/// ===============================================================
///
/// A reusable widget that displays:
/// 1. Greeting message based on the current time (Morning/Afternoon/Evening)
/// 2. User's name
/// 3. A menu button on the top-right
///
/// Parameters:
/// - [userName]: Name of the logged-in user
/// - [onMenuTap]: Callback triggered when the menu button is pressed
///
/// Usage:
/// ```dart
/// HeaderWidget(
///   userName: 'Nikita',
///   onMenuTap: () {
///     // Handle menu action
///   },
/// )
/// ```
/// ===============================================================
class HeaderWidget extends StatelessWidget {
  final String userName;
  final VoidCallback onMenuTap;

  const HeaderWidget({
    super.key,
    required this.userName,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting and message
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Good ${_getGreeting()}, $userName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👋', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Let's make today amazing!",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          // Menu button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 24,
              ),
              onPressed: onMenuTap,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns greeting based on current hour
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
