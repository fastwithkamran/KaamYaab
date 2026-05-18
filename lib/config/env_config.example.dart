// ─────────────────────────────────────────────────────────────────────────────
// SETUP INSTRUCTIONS
// 1. Copy this file:  cp env_config.example.dart env_config.dart
// 2. Replace each placeholder below with your real API key.
// 3. Never commit env_config.dart — it is listed in .gitignore.
// ─────────────────────────────────────────────────────────────────────────────
class EnvConfig {
  // Cohere — https://dashboard.cohere.com/api-keys
  static const String cohereApiKey = 'YOUR_COHERE_API_KEY_HERE';


  // Google Maps — https://console.cloud.google.com/apis/credentials
  static const String mapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
}
