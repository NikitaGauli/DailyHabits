// =============================================================================
// File: google_auth_config.dart
// Description: Centralized configuration for Google OAuth Client IDs.
//              Update the values below with your actual Client IDs from
//              Google Cloud Console → APIs & Services → Credentials.
//
// Setup Instructions:
//   1. Go to https://console.cloud.google.com/apis/credentials
//   2. Create a project (or select existing)
//   3. Configure OAuth Consent Screen (External, publish if needed)
//   4. Create OAuth 2.0 Client IDs:
//      a) Web Application  → copy Client ID → paste as [webClientId] below
//      b) Android App      → use package: com.example.dailyhabits + SHA-1
//   5. The Web Client ID is also used in:
//      - Backend .env as GOOGLE_CLIENT_ID
//      - web/index.html as google-signin-client_id meta tag
// =============================================================================

/// Centralized Google OAuth configuration.
///
/// All Google Client IDs are defined here so they can be updated in a single
/// place. The [webClientId] is the most important — it is used by:
/// - Flutter web (passed as `clientId` to GoogleSignIn)
/// - Flutter mobile (passed as `serverClientId` to get an ID token)
/// - Django backend (as `GOOGLE_CLIENT_ID` to verify the token)
class GoogleAuthConfig {
  GoogleAuthConfig._();

  // ---------------------------------------------------------------------------
  // ⚠️  REPLACE THIS with your actual Web Client ID from Google Cloud Console
  // ---------------------------------------------------------------------------
  // It looks like: 123456789012-abcdefghijklmnop.apps.googleusercontent.com
  //
  // Steps to get it:
  //   1. Go to https://console.cloud.google.com/apis/credentials
  //   2. Click "+ CREATE CREDENTIALS" → "OAuth client ID"
  //   3. Application type: "Web application"
  //   4. Name: "DailyHabits Web"
  //   5. Authorized JavaScript origins: http://localhost:5000 (and your domain)
  //   6. Authorized redirect URIs: http://localhost:5000 (and your domain)
  //   7. Click "Create" → copy the Client ID
  // ---------------------------------------------------------------------------
  static const String webClientId = '';

  /// Whether Google Sign-In is properly configured.
  ///
  /// Returns `false` if the [webClientId] is empty or still a placeholder,
  /// which means the developer hasn't set up Google Cloud Console yet.
  static bool get isConfigured =>
      webClientId.isNotEmpty &&
      webClientId.contains('.apps.googleusercontent.com') &&
      !webClientId.startsWith('your-');
}
