// Area coordinates utility — shared across the app.

/// Shared area → coordinate mapping for Pakistani cities.
/// Used by VoiceBookingAgent (user location fallback) and AiService (area detection).
class AreaCoords {
  AreaCoords._();

  // ── Islamabad Sectors ─────────────────────────────────────────────────────
  static const Map<String, ({double lat, double lng})> islamabadSectors = {
    'G-13': (lat: 33.7215, lng: 73.0433),
    'G-12': (lat: 33.7185, lng: 73.0505),
    'G-11': (lat: 33.7180, lng: 73.0521),
    'G-10': (lat: 33.7150, lng: 73.0500),
    'G-9':  (lat: 33.7100, lng: 73.0470),
    'G-14': (lat: 33.7290, lng: 73.0390),
    'G-15': (lat: 33.7300, lng: 73.0380),
    'F-10': (lat: 33.7050, lng: 73.0600),
    'F-11': (lat: 33.7100, lng: 73.0620),
    'F-7':  (lat: 33.7200, lng: 73.0640),
    'F-8':  (lat: 33.7230, lng: 73.0610),
    'F-6':  (lat: 33.7280, lng: 73.0680),
    'I-8':  (lat: 33.6950, lng: 73.0700),
    'I-9':  (lat: 33.6900, lng: 73.0550),
    'I-10': (lat: 33.6850, lng: 73.0450),
    'E-11': (lat: 33.7350, lng: 73.0200),
    'E-7':  (lat: 33.7400, lng: 73.0680),
    'H-8':  (lat: 33.6950, lng: 73.0500),
    'H-9':  (lat: 33.6900, lng: 73.0400),
  };

  // ── Major City Centers ────────────────────────────────────────────────────
  static const Map<String, ({double lat, double lng})> cityCenters = {
    'Islamabad':  (lat: 33.6844, lng: 73.0479),
    'Rawalpindi': (lat: 33.5651, lng: 73.0169),
    'Lahore':     (lat: 31.5204, lng: 74.3587),
    'Karachi':    (lat: 24.8607, lng: 67.0011),
    'Peshawar':   (lat: 34.0151, lng: 71.5249),
    'Multan':     (lat: 30.1575, lng: 71.5249),
    'Faisalabad': (lat: 31.4504, lng: 73.1350),
    'Quetta':     (lat: 30.1798, lng: 66.9750),
  };

  // ── Lahore Areas ──────────────────────────────────────────────────────────
  static const Map<String, ({double lat, double lng})> lahoreAreas = {
    'DHA Phase 5': (lat: 31.4700, lng: 74.3700),
    'DHA':         (lat: 31.4700, lng: 74.3700),
    'Gulberg':     (lat: 31.5200, lng: 74.3500),
    'Johar Town':  (lat: 31.4600, lng: 74.2700),
    'Model Town':  (lat: 31.4800, lng: 74.3200),
    'Bahria Town': (lat: 31.3600, lng: 74.1800),
    'Garden Town': (lat: 31.5100, lng: 74.3300),
    'Allama Iqbal Town': (lat: 31.5126, lng: 74.2865),
    'Wapda Town':  (lat: 31.4363, lng: 74.2690),
    'Township':    (lat: 31.4542, lng: 74.3168),
    'Cantt':       (lat: 31.5283, lng: 74.3774),
    'Samanabad':   (lat: 31.5434, lng: 74.3006),
    'Shahdara':    (lat: 31.6211, lng: 74.2824),
  };

  // ── Karachi Areas ─────────────────────────────────────────────────────────
  static const Map<String, ({double lat, double lng})> karachiAreas = {
    'Gulshan':        (lat: 24.9200, lng: 67.0900),
    'Clifton':        (lat: 24.8200, lng: 67.0300),
    'DHA Karachi':    (lat: 24.8100, lng: 67.0500),
    'Defence':        (lat: 24.8100, lng: 67.0500),
    'North Nazimabad':(lat: 24.9400, lng: 67.0300),
    'Korangi':        (lat: 24.8400, lng: 67.1300),
    'PECHS':          (lat: 24.8700, lng: 67.0600),
    'Saddar':         (lat: 24.8585, lng: 67.0163),
    'Tariq Road':     (lat: 24.8719, lng: 67.0583),
    'Lyari':          (lat: 24.8698, lng: 66.9930),
    'Malir':          (lat: 24.8986, lng: 67.1956),
    'Nazimabad':      (lat: 24.9080, lng: 67.0315),
    'Gulistan-e-Johar': (lat: 24.9126, lng: 67.1260),
    'F.B Area':       (lat: 24.9312, lng: 67.0725),
    'Orangi Town':    (lat: 24.9454, lng: 66.9912),
    'SITE Area':      (lat: 24.9042, lng: 66.9944),
    'Liaquatabad':    (lat: 24.9026, lng: 67.0422),
  };

  /// Look up coordinates for an area name.
  /// Searches Islamabad sectors first, then Lahore, Karachi, then city centers.
  /// Returns null if no match found.
  static ({double lat, double lng})? lookup(String area) {
    if (area.isEmpty) return null;
    final normalized = area.trim();

    // Direct match in Islamabad sectors
    if (islamabadSectors.containsKey(normalized)) {
      return islamabadSectors[normalized];
    }

    // Case-insensitive search across all maps
    final lower = normalized.toLowerCase();
    for (final entry in islamabadSectors.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final entry in lahoreAreas.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final entry in karachiAreas.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final entry in cityCenters.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }

    // Partial match (e.g., "DHA" matches "DHA Phase 5")
    for (final entry in {...islamabadSectors, ...lahoreAreas, ...karachiAreas, ...cityCenters}.entries) {
      if (entry.key.toLowerCase().contains(lower) || lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Look up coordinates for a city name.
  /// Returns Islamabad center as ultimate fallback if city not found.
  static ({double lat, double lng})? lookupCity(String city) {
    final lower = city.toLowerCase().trim();
    for (final entry in cityCenters.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    // Partial match
    for (final entry in cityCenters.entries) {
      if (entry.key.toLowerCase().contains(lower) || lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Resolve user coordinates using a 4-level fallback chain:
  /// 1. Provided lat/lng (from GPS or saved location)
  /// 2. Area name lookup
  /// 3. City name lookup
  /// 4. Islamabad city center (safe default)
  ///
  /// This prevents null/crash scenarios during demos.
  static ({double lat, double lng})? resolve({
    double? lat,
    double? lng,
    String? area,
    String? city,
  }) {
    // Level 1: Direct coordinates
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      return (lat: lat, lng: lng);
    }

    // Level 2: Area lookup
    if (area != null && area.isNotEmpty) {
      final coords = lookup(area);
      if (coords != null) return coords;
    }

    // Level 3: City lookup
    if (city != null && city.isNotEmpty) {
      return lookupCity(city);
    }

    // No fallback allowed
    return null;
  }
}
