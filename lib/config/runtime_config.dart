/// Centralized runtime config loaded via `--dart-define` values.
/// Keys are hardcoded as defaultValues for hackathon demo builds.
class RuntimeConfig {
  const RuntimeConfig._();

  /// Gemini 1.5 Flash API key — hardcoded for demo, override with --dart-define.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'REDACTED_GEMINI_KEY',
  );

  /// Google Maps API key.
  static const String mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'REDACTED_MAPS_KEY',
  );

  /// Super Admin phone — login with this number to access admin panel.
  static const String superAdminPhone =
      String.fromEnvironment('SUPER_ADMIN_PHONE', defaultValue: '03000000000');

  static const int otpExpirySeconds =
      int.fromEnvironment('OTP_EXPIRY_SECONDS', defaultValue: 150);

  static const int otpSendTimeoutSeconds =
      int.fromEnvironment('OTP_SEND_TIMEOUT_SECONDS', defaultValue: 35);

  static const int otpAutoRetrievalTimeoutSeconds =
      int.fromEnvironment('OTP_AUTO_RETRIEVAL_TIMEOUT_SECONDS', defaultValue: 60);

  static const String defaultCountryDialCode =
      String.fromEnvironment('DEFAULT_COUNTRY_DIAL_CODE', defaultValue: '92');
}