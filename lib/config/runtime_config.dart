import 'env_config.dart';

/// Central runtime configuration for KaamYaab.
///
/// RULE: Two categories of values live here:
///
/// 1. ENVIRONMENT DELEGATES — API keys, flags, OTP settings injected at build
///    time. These are thin getters that forward to [EnvConfig]. They must never
///    have hardcoded literals as their value.
///
/// 2. APP-LOGIC CONSTANTS — tuneable numbers that control matching, pricing,
///    worker scoring, and UI behaviour. These are plain `const` or `static`
///    values. Changing them requires a rebuild (intentional — they are product
///    decisions, not secrets).
///
/// No service file may contain a magic number or hardcoded string for any of
/// these values. Always read from RuntimeConfig.
class RuntimeConfig {
  const RuntimeConfig._();

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  SECTION 1 — ENVIRONMENT DELEGATES                                      ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ── AI ─────────────────────────────────────────────────────────────────────
  /// Cohere API key — primary AI backend.
  /// Supplied via --dart-define=COHERE_API_KEY=your_key
  static String get cohereApiKey => EnvConfig.cohereApiKey;

  /// Cohere model identifier. Update when the model version changes.
  /// Centralised here so every agent call picks up the change automatically.
  static const String cohereModel = 'command-a-03-2025';

  // ── Maps ───────────────────────────────────────────────────────────────────
  /// Google Maps API key.
  /// Supplied via --dart-define=GOOGLE_MAPS_API_KEY=your_key
  static String get mapsApiKey => EnvConfig.mapsApiKey;


  // ── OTP ────────────────────────────────────────────────────────────────────
  static int    get otpExpirySeconds               => EnvConfig.otpExpirySeconds;
  static int    get otpSendTimeoutSeconds          => EnvConfig.otpSendTimeoutSeconds;
  static int    get otpAutoRetrievalTimeoutSeconds => EnvConfig.otpAutoRetrievalTimeoutSeconds;
  static String get defaultCountryDialCode         => EnvConfig.defaultCountryDialCode;

  // ── SMS ────────────────────────────────────────────────────────────────────
  static String get smsApiKey  => EnvConfig.smsApiKey;
  static bool   get smsEnabled => EnvConfig.smsEnabled;

  // ── Feature flags ──────────────────────────────────────────────────────────
  static bool get useLiveAI    => EnvConfig.useLiveAI;
  static bool get useFirestore => EnvConfig.useFirestore;
  static bool get mapsEnabled  => EnvConfig.mapsEnabled;

  // ── App metadata ───────────────────────────────────────────────────────────
  static String get appVersion  => EnvConfig.appVersion;
  static String get buildNumber => EnvConfig.buildNumber;
  static String get appName     => EnvConfig.appName;
  static String get packageId   => EnvConfig.packageId;

  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  SECTION 2 — APP-LOGIC CONSTANTS                                        ║
  // ╚══════════════════════════════════════════════════════════════════════════╝

  // ── Chat ───────────────────────────────────────────────────────────────────
  /// Maximum messages kept in the sliding AI chat history window.
  static const int chatHistoryMaxMessages = 20;

  // ── Matching / Distance ────────────────────────────────────────────────────
  /// Distance (km) within which no travel charge is added to the quote.
  static const double distanceFreeZoneKm = 5.0;

  /// PKR charged per km beyond [distanceFreeZoneKm].
  static const double distanceChargePerKm = 30.0;

  // ── Pricing adjustments ────────────────────────────────────────────────────
  /// Fractional discount applied to the base rate for repeat customers.
  static const double loyaltyDiscountRate = 0.05;       // 5 %

  /// Fractional discount applied when budget sensitivity ≥ 0.75.
  static const double budgetSensitivityDiscount = 0.05; // 5 %

  // ── Worker defaults (new / live registered workers) ───────────────────────
  /// Provisional star rating for brand-new workers (fewer than 5 jobs).
  static const double newWorkerProvisionalRating = 3.5;

  /// Fallback star rating for workers with no rating history but ≥ 5 jobs.
  static const double defaultWorkerRating = 4.0;

  /// On-time delivery rate assumed for new workers.
  static const double newWorkerOnTimeRate = 0.85;

  /// On-time delivery rate assumed for established workers.
  static const double defaultWorkerOnTimeRate = 0.90;

  /// Cancellation rate assumed for new workers.
  static const double newWorkerCancellationRate = 0.05;

  /// Cancellation rate assumed for established workers.
  static const double defaultWorkerCancellationRate = 0.03;

  /// Price-fairness score assumed for new workers.
  static const double newWorkerPriceFairnessScore = 0.80;

  /// Price-fairness score assumed for established workers.
  static const double defaultWorkerPriceFairnessScore = 0.85;

  /// Base rate (PKR/hr) used when a worker registers without setting their own.
  static const double defaultWorkerBaseRatePkr = 600.0;

  // ── UI ─────────────────────────────────────────────────────────────────────
  /// How long toast SnackBars remain visible.
  static const Duration snackBarDuration = Duration(seconds: 4);

  // ── Scoring thresholds ─────────────────────────────────────────────────────
  /// Budget sensitivity below this value triggers premium-worker preference.
  static const double premiumBudgetSensitivityThreshold = 0.3;

  /// Minimum star rating to qualify as a high-preference (premium) worker.
  static const double premiumWorkerRatingThreshold = 4.6;
}