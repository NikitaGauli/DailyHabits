import 'package:flutter/foundation.dart';

class ApiConfig {
  // For Android Emulator, use 10.0.2.2. For physical device, use your LAN IP.
  static const String _androidEmulatorHost = '10.0.2.2';
  // Use 'localhost' for web (more reliable with CORS than 127.0.0.1)
  static const String _webHost = 'localhost';
  static const String _localhost = '127.0.0.1';
  static const String _port = '8000';

  /// Request timeout duration
  static const Duration timeout = Duration(seconds: 15);

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
