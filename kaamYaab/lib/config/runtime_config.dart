/// Centralized runtime config loaded via `--dart-define` values.
class EnvConfig {
  const EnvConfig._();

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const String superAdminPhone =
      String.fromEnvironment('SUPER_ADMIN_PHONE', defaultValue: '03000000000');

  static const bool smsEnabled =
      bool.fromEnvironment('SMS_ENABLED', defaultValue: false);

  static const int otpExpirySeconds =
      int.fromEnvironment('OTP_EXPIRY_SECONDS', defaultValue: 120);
}
