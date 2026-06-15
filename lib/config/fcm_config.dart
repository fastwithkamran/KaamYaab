/// FCM v1 API configuration.
///
/// HOW TO SET UP:
///   1. Firebase Console → Project Settings → Service Accounts
///   2. Click "Generate new private key" → save the downloaded JSON
///   3. Replace assets/fcm_service_account.json with the downloaded file
///   4. Set [projectId] below to match the "project_id" in that JSON
///
/// ⚠️  SECURITY: Never commit fcm_service_account.json to a public repo.
///    Add it to .gitignore. For production, move push to a Cloud Function.
class FcmConfig {
  FcmConfig._();

  /// Your Firebase project ID — found in Firebase Console → Project Settings
  /// or inside your service account JSON as "project_id".
  static const String projectId = 'kaamyaab-92';

  /// Path to the service account JSON bundled as a Flutter asset.
  static const String serviceAccountAsset = 'assets/fcm_service_account.json';

  /// FCM v1 send endpoint.
  static String get sendUrl =>
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

  /// OAuth2 scope required for FCM v1.
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  /// How long (minutes) before the cached OAuth2 token expires and is refreshed.
  /// Google tokens last 60 min; we refresh at 55 to stay safe.
  static const int tokenRefreshBufferMinutes = 55;
}
