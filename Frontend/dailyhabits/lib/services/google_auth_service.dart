// =============================================================================
// File: google_auth_service.dart
// Description: Handles the complete Google Sign-In authentication flow for
//              the DailyHabits application. Orchestrates the Google Sign-In
//              SDK, sends the ID token to the Django backend for verification,
//              and stores the resulting JWT tokens securely.
//
// Platforms:
//   - Web:     Uses Google Identity Services (GIS) via the google_sign_in
//              web plugin. Requires `clientId` in the constructor AND the
//              GIS script tag in web/index.html.
//   - Android: Uses Google Play Services. Requires `serverClientId` to
//              obtain an ID token. SHA-1 must be registered in GCP.
//   - iOS:     Uses Google Sign-In SDK. Requires `serverClientId`.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dailyhabits/config/google_auth_config.dart';
import 'package:dailyhabits/services/auth_service.dart';

// =============================================================================
// Google Authentication Service
// =============================================================================

/// Handles the complete "Continue with Google" authentication flow.
///
/// This service orchestrates:
/// 1. **Google Sign-In SDK** — Launches the native Google sign-in dialog
///    and retrieves the user's Google ID token.
/// 2. **Backend verification** — Sends the ID token to the Django backend
///    (`/api/auth/google/`) where it is cryptographically verified against
///    Google's public keys.
/// 3. **Token storage** — On success, delegates JWT token persistence to
///    [AuthService] which uses `FlutterSecureStorage`.
///
/// Security:
/// - The Google ID token is **never** trusted on the client side alone.
///   It is always sent to the backend for server-side verification.
/// - The `serverClientId` / `clientId` must match the Web Client ID
///   configured in Google Cloud Console and the Django backend's
///   `GOOGLE_CLIENT_ID`.
class GoogleAuthService {
  // ---------------------------------------------------------------------------
  // Constants & Singleton
  // ---------------------------------------------------------------------------

  /// Singleton instance — ensures a single [GoogleAuthService] across the app.
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  /// Factory constructor returns the shared singleton instance.
  factory GoogleAuthService() => _instance;

  /// Private named constructor used by the singleton pattern.
  GoogleAuthService._internal();

  /// Google Sign-In instance configured for cross-platform use.
  ///
  /// Configuration:
  /// - `scopes`: `email` + `profile` are requested to get the user's email
  ///   and display name. Profile picture is NOT used by this app.
  /// - `clientId`: Required for **web** — the Google Identity Services (GIS)
  ///   library needs this to render the sign-in popup.
  /// - `serverClientId`: Required for **mobile** (Android/iOS) — ensures the
  ///   ID token's `aud` claim matches the Web Client ID so the backend can
  ///   verify it.
  ///
  /// Both values come from [GoogleAuthConfig.webClientId] so you only need
  /// to configure it once in `lib/config/google_auth_config.dart`.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // For web: pass the Client ID so GIS can initialize
    clientId: kIsWeb ? GoogleAuthConfig.webClientId : null,
    // For mobile: pass the server Client ID to get a verifiable ID token
    serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initiates the full Google authentication flow.
  ///
  /// Steps:
  /// 1. Validates that the Google Client ID is configured.
  /// 2. Launches the native Google Sign-In dialog.
  /// 3. Retrieves the Google ID token from the authentication result.
  /// 4. Extracts email and name (NO avatar/photo).
  /// 5. Sends the ID token + profile to the Django backend.
  /// 6. On backend success, stores JWT tokens securely via [AuthService].
  /// 7. Returns an authentication status map.
  ///
  /// Returns a `Map<String, dynamic>` with:
  /// - `success: true` and `data` on successful authentication.
  /// - `success: false` and a human-readable `message` on failure.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // --- Pre-flight: Check configuration ---
      if (!GoogleAuthConfig.isConfigured) {
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('GOOGLE_AUTH ✖ Google Client ID is NOT configured!');
        debugPrint('');
        debugPrint('To fix this:');
        debugPrint('  1. Go to https://console.cloud.google.com/apis/credentials');
        debugPrint('  2. Create an OAuth 2.0 "Web application" Client ID');
        debugPrint('  3. Paste the Client ID into:');
        debugPrint('     → lib/config/google_auth_config.dart  (webClientId)');
        debugPrint('     → Backend/.env                        (GOOGLE_CLIENT_ID)');
        debugPrint('     → web/index.html                      (meta tag)');
        debugPrint('═══════════════════════════════════════════════════════');
        return {
          'success': false,
          'message':
              'Google Sign-In is not configured yet. '
              'Please set up a Google OAuth Client ID in Google Cloud Console.',
        };
      }

      debugPrint('GOOGLE_AUTH ➜ Starting Google Sign-In flow...');
      debugPrint('GOOGLE_AUTH ➜ Platform: ${kIsWeb ? "Web" : defaultTargetPlatform.name}');

      // --- Step 1: Trigger native Google Sign-In ---
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the sign-in dialog
      if (googleUser == null) {
        debugPrint('GOOGLE_AUTH ➜ User cancelled sign-in');
        return {
          'success': false,
          'message': 'Google sign-in was cancelled.',
          'cancelled': true,
        };
      }

      debugPrint('GOOGLE_AUTH ➜ Signed in as: ${googleUser.email}');

      // --- Step 2: Retrieve the authentication tokens ---
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('GOOGLE_AUTH ✖ ID token is null!');
        debugPrint('GOOGLE_AUTH ➜ This usually means serverClientId is missing or wrong.');
        debugPrint('GOOGLE_AUTH ➜ Check that GoogleAuthConfig.webClientId matches your GCP Web Client ID.');
        return {
          'success': false,
          'message': 'Failed to retrieve Google authentication token. '
              'Please check your Google Cloud Console configuration.',
        };
      }

      debugPrint('GOOGLE_AUTH ➜ ID token retrieved (${idToken.length} chars)');

      // --- Step 3: Extract email and name (NO photo/avatar) ---
      final String email = googleUser.email;
      final String name = googleUser.displayName ?? '';
      // Note: googleUser.photoUrl is intentionally NOT accessed or sent.

      debugPrint('GOOGLE_AUTH ➜ Sending to backend: email=$email, name=$name');

      // --- Step 4: Send ID token + profile data to Django backend ---
      final result = await AuthService().loginWithGoogle(
        idToken: idToken,
        email: email,
        name: name,
      );

      if (result['success'] == true) {
        debugPrint('GOOGLE_AUTH ✔ Authentication successful!');
      } else {
        debugPrint('GOOGLE_AUTH ✖ Backend rejected: ${result['message']}');
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('GOOGLE_AUTH ✖ Exception: $e');
      debugPrint('GOOGLE_AUTH ➜ Stack trace: $stackTrace');
      return {'success': false, 'message': _friendlyGoogleError(e)};
    }
  }

  /// Signs out the user from both Google and the local app session.
  ///
  /// This method:
  /// 1. Signs out from the Google Sign-In SDK (revokes Google session).
  /// 2. Clears local JWT tokens via [AuthService.logout].
  ///
  /// Should be called when the user explicitly logs out from the app.
  Future<void> signOut() async {
    try {
      // Sign out from Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        debugPrint('GOOGLE_AUTH ➜ Signed out from Google');
      }
    } catch (e) {
      // Google sign-out failure is non-critical — still clear local tokens
      debugPrint('GOOGLE_AUTH ➜ Google sign-out warning: $e');
    }

    // Always clear local JWT tokens
    await AuthService().logout();
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Converts Google Sign-In exceptions into user-friendly error messages.
  ///
  /// Provides specific guidance for common failure scenarios:
  /// - **Network errors** — connectivity issues during Google OAuth.
  /// - **API exceptions** — Google Play Services issues.
  /// - **Configuration errors** — missing or invalid client IDs.
  /// - **Initialization errors** — GIS library failed to load (web).
  String _friendlyGoogleError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('network_error') || msg.contains('network error')) {
      return 'Network error during Google sign-in. Please check your connection.';
    }
    if (msg.contains('sign_in_cancelled') || msg.contains('canceled')) {
      return 'Google sign-in was cancelled.';
    }
    if (msg.contains('sign_in_failed')) {
      return 'Google sign-in failed. Please try again.';
    }
    if (msg.contains('apiexception') || msg.contains('api exception')) {
      return 'Google Play Services error. Please update Google Play Services.';
    }
    if (msg.contains('idpiframe_initialization_failed') ||
        msg.contains('gis') ||
        msg.contains('client_id')) {
      return 'Google Sign-In configuration error. '
          'The OAuth Client ID may be invalid or missing.';
    }
    if (msg.contains('popup_closed') || msg.contains('popup_blocked')) {
      return 'The Google sign-in popup was closed. Please try again.';
    }
    if (msg.contains('access_denied')) {
      return 'Access was denied. Please grant the required permissions.';
    }

    return 'Google sign-in failed. Please try again.';
  }
}
