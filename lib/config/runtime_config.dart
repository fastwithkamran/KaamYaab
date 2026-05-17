import 'env_config.dart';

/// Centralized runtime config loaded via `--dart-define` values.
/// Keys are hardcoded as defaultValues for hackathon demo builds.
class RuntimeConfig {
  const RuntimeConfig._();

  /// Gemini 1.5 Flash API key — hardcoded for demo, override with --dart-define.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAw_tBxhumpAoyAUDfz6-AVe3MZ6786JFM',
  );

<<<<<<< HEAD
  static const String cohereApiKey =
      String.fromEnvironment('COHERE_API_KEY', defaultValue: EnvConfig.cohereApiKey);

  /// Google Maps API key — used for live worker tracking map.
  /// Hardcoded for hackathon demo; move to dart-define for production.
  static const String mapsApiKey = 'AIzaSyCX0lQaNZFHXlwDS8aM3Yz3yLNBrQRkHiw';
=======
  /// Google Maps API key.
  static const String mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyCX0lQaNZFHXlwDS8aM3Yz3yLNBrQRkHiw',
  );
>>>>>>> cbb51c88c7537750323fa764b26eeb3f9ab41613

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