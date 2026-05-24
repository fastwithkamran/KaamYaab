import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Core Palette ───────────────────────────────────────────────────────────
  static const Color backgroundDark  = Color(0xFF0A0F1E);
  static const Color surfaceDark     = Color(0xFF111827);
  static const Color cardDark        = Color(0xFF1C2537);
  static const Color cardElevated    = Color(0xFF212E45);
  static const Color tealPrimary     = Color(0xFF00BFA5);
  static const Color tealLight       = Color(0xFF4DD0C4);
  static const Color tealDark        = Color(0xFF008C7A);
  static const Color goldAccent      = Color(0xFFF59E0B);
  static const Color goldLight       = Color(0xFFFBBF24);
  static const Color redAlert        = Color(0xFFEF4444);
  static const Color greenSuccess    = Color(0xFF22C55E);
  static const Color purpleAgent     = Color(0xFF8B5CF6);
  static const Color purpleLight     = Color(0xFFA78BFA);
  static const Color blueInfo        = Color(0xFF3B82F6);
  static const Color glassOverlay    = Color(0x1AFFFFFF);
  // Alias — redError is used across auth screens
  static const Color redError        = redAlert;

  // ─── Text Colors ────────────────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFFF1F5F9);
  static const Color textSecondary   = Color(0xFF94A3B8);
  static const Color textMuted       = Color(0xFF475569);

  // ─── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [tealDark, tealPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD97706), goldAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient agentGradient = LinearGradient(
    colors: [Color(0xFF4C1D95), purpleAgent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0F1E), Color(0xFF0F1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surgeGradient = LinearGradient(
    colors: [Color(0xFF92400E), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGlassGradient = LinearGradient(
    colors: [Color(0x2600BFA5), Color(0x0A00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGlassGradient = LinearGradient(
    colors: [Color(0x268B5CF6), Color(0x0A8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> tealGlow = [
    BoxShadow(
      color: tealPrimary.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> tealGlowStrong = [
    BoxShadow(
      color: tealPrimary.withValues(alpha: 0.4),
      blurRadius: 28,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> goldGlow = [
    BoxShadow(
      color: goldAccent.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floatShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 30,
      spreadRadius: 0,
      offset: const Offset(0, 10),
    ),
  ];

  // ─── Border Radius ──────────────────────────────────────────────────────────
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(32));

  // ─── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: tealPrimary,
      colorScheme: const ColorScheme.dark(
        primary: tealPrimary,
        secondary: goldAccent,
        surface: surfaceDark,
        error: redAlert,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          displayLarge:  TextStyle(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 32),
          displayMedium: TextStyle(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 28),
          headlineLarge: TextStyle(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 24),
          headlineMedium:TextStyle(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 20),
          headlineSmall: TextStyle(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 18),
          titleLarge:    TextStyle(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 16),
          titleMedium:   TextStyle(color: textPrimary,   fontWeight: FontWeight.w500, fontSize: 14),
          bodyLarge:     TextStyle(color: textSecondary, fontWeight: FontWeight.w400, fontSize: 16),
          bodyMedium:    TextStyle(color: textSecondary, fontWeight: FontWeight.w400, fontSize: 14),
          bodySmall:     TextStyle(color: textMuted,     fontWeight: FontWeight.w400, fontSize: 12),
          labelLarge:    TextStyle(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: tealPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Helper Methods ──────────────────────────────────────────────────────────
  static Color dnaScoreColor(int score) {
    if (score >= 800) return greenSuccess;
    if (score >= 600) return tealPrimary;
    if (score >= 400) return goldAccent;
    return redAlert;
  }

  static String dnaScoreLabel(int score) {
    if (score >= 800) return 'Excellent';
    if (score >= 600) return 'Good';
    if (score >= 400) return 'Average';
    return 'Poor';
  }

  static Color surgeColor(double multiplier) {
    if (multiplier >= 2.0) return redAlert;
    if (multiplier >= 1.5) return goldAccent;
    return greenSuccess;
  }

  /// Returns a greeting based on the current hour (Islamabad timezone context).
  static String timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Raat ka salam';
    if (h < 12) return 'Subah Bakhair';
    if (h < 17) return 'Dopahar Mubarak';
    if (h < 20) return 'Shaam Bakhair';
    return 'Raat Bakhair';
  }
}
