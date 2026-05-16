/// Centralized runtime config loaded via `--dart-define` values.
class RuntimeConfig {
  const RuntimeConfig._();

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Google Maps API key — used for live worker tracking map.
  /// Hardcoded for hackathon demo; move to dart-define for production.
  static const String mapsApiKey = 'REDACTED_MAPS_KEY';

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