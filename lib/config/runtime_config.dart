import 'env_config.dart';

/// Centralized runtime config — all secrets come from EnvConfig (gitignored).
/// Override any key at build time with --dart-define=KEY=value.
class RuntimeConfig {
  const RuntimeConfig._();


  /// Cohere API key — primary AI backend
  static const String cohereApiKey = String.fromEnvironment(
    'COHERE_API_KEY',
    defaultValue: EnvConfig.cohereApiKey,
  );

  /// Gemini API key — New primary AI backend
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: EnvConfig.geminiApiKey,
  );

  /// Google Maps API key
  static const String mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: EnvConfig.mapsApiKey,
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