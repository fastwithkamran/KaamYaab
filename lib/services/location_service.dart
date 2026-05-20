import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/distance_utils.dart';

/// Result of a GPS location lookup.
class LocationData {
  final double latitude;
  final double longitude;
  final String address;     // Human-readable: "DHA Phase 5, Lahore"
  final String city;        // Just the city: "Lahore"
  final String area;        // Locality: "DHA Phase 5"
  final DateTime fetchedAt;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.area,
    required this.fetchedAt,
  });

  /// Distance in km from this location to [other].
  double distanceTo(LocationData other) {
    return haversineDistanceKm(
      (lat: latitude, lng: longitude),
      (lat: other.latitude, lng: other.longitude),
    );
  }

  /// Distance in km to raw coordinates.
  double distanceToCoords(double lat, double lng) {
    return haversineDistanceKm(
      (lat: latitude, lng: longitude),
      (lat: lat, lng: lng),
    );
  }

  String get shortAddress => area.isNotEmpty ? '$area, $city' : city;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'address': address,
        'city': city,
        'area': area,
        'at': fetchedAt.toIso8601String(),
      };

  factory LocationData.fromJson(Map<String, dynamic> j) => LocationData(
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        address: j['address'] as String,
        city: j['city'] as String,
        area: j['area'] as String? ?? '',
        fetchedAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Errors that can be returned by [LocationService.getCurrentLocation].
enum LocationError { disabled, denied, deniedForever, timeout, unknown }

class LocationResult {
  final LocationData? data;
  final LocationError? error;

  bool get isSuccess => data != null;
  const LocationResult.success(this.data) : error = null;
  const LocationResult.failure(this.error) : data = null;
}

/// Singleton GPS service — auto-detects location for customers and workers.
///
/// Usage:
/// ```dart
/// final result = await LocationService().getCurrentLocation();
/// if (result.isSuccess) print(result.data!.shortAddress);
/// ```
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  // Last known location for this session (prevents repeated GPS calls).
  LocationData? _cached;
  DateTime? _cacheTime;
  bool _watchActive = false;
  static const _cacheDuration = Duration(minutes: 5);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Get current GPS location.
  /// Returns cached result if < 5 minutes old.
  Future<LocationResult> getCurrentLocation({bool forceRefresh = false}) async {
    // Return cache if fresh enough
    if (!forceRefresh &&
        _cached != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return LocationResult.success(_cached!);
    }

    // Check service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationResult.failure(LocationError.disabled);

    // Check / request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationError.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(LocationError.deniedForever);
    }

    try {
      // geolocator 14.x: desiredAccuracy/timeLimit params were removed.
      // Use LocationSettings + Future.timeout instead.
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw _LocationTimeoutException(),
      );

      final data = _toLocationData(position.latitude, position.longitude);
      _cached = data;
      _cacheTime = DateTime.now();
      return LocationResult.success(data);
    } on _LocationTimeoutException {
      return const LocationResult.failure(LocationError.timeout);
    } catch (_) {
      return const LocationResult.failure(LocationError.unknown);
    }
  }

  LocationData _toLocationData(double lat, double lng) {
    final city = _inferCityFromCoords(lat, lng);
    final address = city.isNotEmpty
        ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} ($city)'
        : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    return LocationData(
      latitude: lat,
      longitude: lng,
      address: address,
      city: city,
      area: '',
      fetchedAt: DateTime.now(),
    );
  }

  /// Derives a city name from GPS coordinates using rough bounding boxes
  /// for major Pakistani cities (no external API required).
  static String _inferCityFromCoords(double lat, double lng) {
    if (lat >= 33.5 && lat <= 33.9 && lng >= 72.8 && lng <= 73.3) return 'Islamabad';
    if (lat >= 33.4 && lat <= 33.8 && lng >= 73.0 && lng <= 73.4) return 'Rawalpindi';
    if (lat >= 31.3 && lat <= 31.8 && lng >= 74.1 && lng <= 74.6) return 'Lahore';
    if (lat >= 24.7 && lat <= 25.1 && lng >= 66.8 && lng <= 67.5) return 'Karachi';
    if (lat >= 30.1 && lat <= 30.4 && lng >= 71.4 && lng <= 71.7) return 'Multan';
    if (lat >= 34.1 && lat <= 34.4 && lng >= 71.4 && lng <= 71.8) return 'Peshawar';
    if (lat >= 29.3 && lat <= 29.5 && lng >= 71.6 && lng <= 71.8) return 'Bahawalpur';
    if (lat >= 32.1 && lat <= 32.3 && lng >= 72.6 && lng <= 72.8) return 'Sargodha';
    if (lat >= 30.6 && lat <= 30.8 && lng >= 73.0 && lng <= 73.2) return 'Faisalabad';
    return '';
  }

  // ── Persist worker/customer location to SharedPreferences ─────────────────

  /// Saves the user's current location to local storage (called by workers on
  /// "Go Online" and by customers when booking).
  Future<void> saveUserLocation(String uid, LocationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loc_$uid', jsonEncode(data.toJson()));
  }

  /// Loads the last saved location for a given user (by uid).
  Future<LocationData?> loadUserLocation(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('loc_$uid');
    if (raw == null) return null;
    try {
      return LocationData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clears cached GPS result (forces fresh fetch next time).
  void clearCache() {
    _cached = null;
    _cacheTime = null;
    _watchActive = false;
  }

  /// Stops the active watchLocation() stream loop.
  void stopWatchingLocation() => _watchActive = false;

  // ── Utility: user-friendly error messages ─────────────────────────────────

  static String errorMessage(LocationError error) {
    switch (error) {
      case LocationError.disabled:
        return 'Please turn on Location Services in your phone settings.';
      case LocationError.denied:
        return 'Location permission was denied. Please allow it to auto-detect your area.';
      case LocationError.deniedForever:
        return 'Location permission is permanently blocked. Enable it in App Settings → Permissions.';
      case LocationError.timeout:
        return 'GPS took too long. Make sure you have a clear sky view or try again.';
      case LocationError.unknown:
        return 'Could not detect your location. Please enter it manually.';
    }
  }

  // ── Stream: watch position (for worker live tracking) ────────────────────

  /// Returns a stream that emits location updates every 30 seconds.
  /// Call [stopWatchingLocation] to cleanly cancel the loop and prevent leaks.
  Stream<LocationData> watchLocation() async* {
    _watchActive = true;
    while (_watchActive) {
      final result = await getCurrentLocation(forceRefresh: true);
      if (result.isSuccess) yield result.data!;
      // Delay with early-exit check so cancel takes effect within 1s.
      for (var i = 0; i < 30 && _watchActive; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
}

/// Internal sentinel used to distinguish our manual timeout from other errors.
/// Avoids the dart:async / geolocator TimeoutException mismatch on geolocator 14.x.
class _LocationTimeoutException implements Exception {
  const _LocationTimeoutException();
}