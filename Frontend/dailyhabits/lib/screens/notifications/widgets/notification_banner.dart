// =============================================================================
// File: notification_banner.dart
// Description: In-app notification banner overlay for real-time notifications.
//
//   When a new notification arrives via WebSocket, this banner slides in from
//   the top of the screen for 4 seconds, providing instant visual feedback
//   without interrupting the user's current workflow.
//
//   The banner is displayed as an overlay on top of all other content,
//   similar to iOS/Android system notification banners but rendered
//   entirely within the Flutter widget tree.
//
// Usage:
//   Call [NotificationBanner.show] from the widget tree when a new
//   notification arrives via WebSocket:
//
//   ```dart
//   NotificationBanner.show(
//     context,
//     notification: AppNotification(...),
//     onTap: () { /* navigate to relevant screen */ },
//   );
//   ```
//
// See also:
//   - [NotificationController] — Triggers banner display on WS events.
//   - [HomePage] — Mounts the banner overlay via [Overlay].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/models/notification_model.dart';
import 'package:dailyhabits/theme/app_theme.dart';

// =============================================================================
//  Notification Banner — In-App Toast for Real-Time Events
// =============================================================================

/// Displays a slide-down banner at the top of the screen when a new
/// notification arrives via the WebSocket connection.
///
/// The banner auto-dismisses after [_displayDuration] and can be manually
/// dismissed with a swipe-up gesture.
class NotificationBanner {
  /// How long the banner stays visible before auto-dismissing.
  static const Duration _displayDuration = Duration(seconds: 4);

  /// Currently displayed overlay entry (null if no banner is showing).
  static OverlayEntry? _currentEntry;

  /// Shows a notification banner at the top of the screen.
  ///
  /// If a banner is already showing, it is replaced by the new one.
  ///
  /// Args:
  ///   [context] — BuildContext for overlay insertion and theming.
  ///   [notification] — The notification to display.
  ///   [onTap] — Optional callback when the banner is tapped.
  static void show(
    BuildContext context, {
    required AppNotification notification,
    VoidCallback? onTap,
  }) {
    // Remove any existing banner before showing a new one
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        notification: notification,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto-dismiss after the display duration
    Future.delayed(_displayDuration, dismiss);
  }

  /// Dismisses the currently displayed banner, if any.
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

// =============================================================================
//  Banner Widget (Internal)
// =============================================================================

/// The actual banner widget rendered in the overlay.
///
/// Slides in from the top with a subtle animation and displays the
/// notification title, message, icon, and timestamp.
class _BannerWidget extends StatefulWidget {
  /// The notification to display.
  final AppNotification notification;

  /// Callback invoked when the user taps the banner.
  final VoidCallback? onTap;

  /// Callback invoked when the banner should be dismissed.
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.notification,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  /// Controls the slide-in / slide-out animation.
  late AnimationController _animCtrl;

  /// The vertical slide animation (from -1.0 offscreen to 0.0 in place).
  late Animation<Offset> _slideAnimation;

  /// Fade animation for smooth entrance and exit.
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final notification = widget.notification;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              // Swipe up to dismiss
              if (details.velocity.pixelsPerSecond.dy < -100) {
                widget.onDismiss();
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + 8,
                left: 12,
                right: 12,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notification.color.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Notification Icon ──────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notification.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Title & Message ────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: tc.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.message,
                          style: TextStyle(
                            color: tc.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── Close Button ───────────────────────────────
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close_rounded,
                      color: tc.textMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
