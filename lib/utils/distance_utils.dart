import 'dart:math';

typedef GeoPoint = ({double lat, double lng});

double haversineDistanceKm(GeoPoint from, GeoPoint to) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRad(to.lat - from.lat);
  final dLng = _toRad(to.lng - from.lng);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(from.lat)) *
          cos(_toRad(to.lat)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

// Assumes average urban speed of 30 km/h for ETA estimation.
double estimateTravelTimeHours(double distanceKm) => distanceKm / 30.0;

double _toRad(double deg) => deg * pi / 180.0;
