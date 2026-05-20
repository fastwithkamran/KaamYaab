import 'env_config.dart';

/// Centralized runtime config — all values delegate to EnvConfig.
/// Override any key at build time with --dart-define=KEY=value.
///
/// FIX: Removed duplicate String.fromEnvironment() calls. EnvConfig already
/// resolves --dart-define; calling fromEnvironment() again here was redundant
/// and caused the otpExpirySeconds conflict (150 here vs 120 in EnvConfig).
///
/// FIX: Removed geminiApiKey entirely — project has shifted to Cohere.
/// The old reference to EnvConfig.geminiApiKey caused a compile error because
/// that field never existed in env_config.dart.
class RuntimeConfig {
  const RuntimeConfig._();

  // ── AI ─────────────────────────────────────────────────────────────────────
  /// Cohere API key — primary AI backend
  static String get cohereApiKey => EnvConfig.cohereApiKey;

  // ── Maps ───────────────────────────────────────────────────────────────────
  /// Google Maps API key
  static String get mapsApiKey => EnvConfig.mapsApiKey;

  // ── Auth ───────────────────────────────────────────────────────────────────
  /// Super Admin phone — login with this number to access admin panel.
  static String get superAdminPhone => EnvConfig.superAdminPhone;

  // ── OTP ────────────────────────────────────────────────────────────────────
  static int    get otpExpirySeconds               => EnvConfig.otpExpirySeconds;
  static int    get otpSendTimeoutSeconds          => EnvConfig.otpSendTimeoutSeconds;
  static int    get otpAutoRetrievalTimeoutSeconds => EnvConfig.otpAutoRetrievalTimeoutSeconds;
  static String get defaultCountryDialCode         => EnvConfig.defaultCountryDialCode;

  // ── Feature Flags ──────────────────────────────────────────────────────────
  static bool get useLiveAI    => EnvConfig.useLiveAI;
  static bool get useFirestore => EnvConfig.useFirestore;
  static bool get mapsEnabled  => EnvConfig.mapsEnabled;
}