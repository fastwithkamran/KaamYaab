import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
    return Geolocator.distanceBetween(
          latitude, longitude,
          other.latitude, other.longitude,
        ) / 1000.0;
  }

  /// Distance in km to raw coordinates.
  double distanceToCoords(double lat, double lng) {
    return Geolocator.distanceBetween(latitude, longitude, lat, lng) / 1000.0;
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
  static const _cacheDuration = Duration(minutes: 5);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Get current GPS location with reverse geocoding.
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final data = await _reverseGeocode(position.latitude, position.longitude);
      _cached = data;
      _cacheTime = DateTime.now();
      return LocationResult.success(data);
    } on TimeoutException {
      return const LocationResult.failure(LocationError.timeout);
    } catch (_) {
      return const LocationResult.failure(LocationError.unknown);
    }
  }

  /// Reverse geocode coordinates to a human-readable address.
  Future<LocationData> _reverseGeocode(double lat, double lng) async {
    String address = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    String city = '';
    String area = '';

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.administrativeArea ?? '';
        area = p.subLocality ?? p.thoroughfare ?? '';
        final parts = [area, city, p.country]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        address = parts.isNotEmpty ? parts : address;
      }
    } catch (_) {
      // Geocoding failed — use raw coordinates
    }

    return LocationData(
      latitude: lat,
      longitude: lng,
      address: address,
      city: city,
      area: area,
      fetchedAt: DateTime.now(),
    );
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
  }

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
  /// Used by workers who have "Share My Location" enabled.
  Stream<LocationData> watchLocation() async* {
    while (true) {
      final result = await getCurrentLocation(forceRefresh: true);
      if (result.isSuccess) yield result.data!;
      await Future.delayed(const Duration(seconds: 30));
    }
  }
}
