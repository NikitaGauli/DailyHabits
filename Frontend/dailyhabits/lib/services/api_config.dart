// =============================================================================
// File: api_config.dart
// Description: Centralized API configuration for the DailyHabits application.
//              Provides platform-aware base URL resolution and network timeout
//              settings for communicating with the Django REST Framework backend.
// =============================================================================

import 'package:flutter/foundation.dart';

// =============================================================================
// API Configuration
// =============================================================================

/// Centralized API configuration that resolves the correct backend base URL
/// based on the current runtime platform (web, Android emulator, iOS, desktop).
///
/// This class uses compile-time and runtime platform detection to ensure that
/// HTTP requests are routed to the correct host address for the Django backend.
///
/// Usage:
/// ```dart
/// final url = '${ApiConfig.baseUrl}/habits/';
/// ```
class ApiConfig {
  // ---------------------------------------------------------------------------
  // Host Constants
  // ---------------------------------------------------------------------------

  // For Android Emulator, use 10.0.2.2. For physical device, use your LAN IP.
  static const String _androidEmulatorHost = '10.0.2.2';
  // Use 'localhost' for web (more reliable with CORS than 127.0.0.1)
  static const String _webHost = 'localhost';
  static const String _localhost = '127.0.0.1';
  static const String _port = '8000';

  /// Default request timeout duration applied to all HTTP calls.
  ///
  /// If the backend does not respond within this window, the request is
  /// cancelled and a user-friendly timeout message is shown.
  static const Duration timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // Base URL Resolution
  // ---------------------------------------------------------------------------

  /// Returns the platform-appropriate API base URL.
  ///
  /// The resolved URL varies by platform:
  /// - **Web**: Uses `localhost` to avoid mixed-content and CORS issues.
  /// - **Android emulator**: Uses `10.0.2.2` (the host loopback alias).
  /// - **iOS simulator**: Uses `127.0.0.1` (standard loopback).
  /// - **Desktop** (Windows / macOS / Linux): Uses `127.0.0.1`.
  static String get baseUrl {
    if (kIsWeb) {
      // 'localhost' avoids browser mixed-content / CORS quirks
      return 'http://$_webHost:$_port/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$_androidEmulatorHost:$_port/api';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://$_localhost:$_port/api';
    }
    // Windows, macOS, Linux desktop
    return 'http://$_localhost:$_port/api';
  }
}
