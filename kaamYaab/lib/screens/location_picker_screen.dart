import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

/// Result returned by the location picker.
class LocationResult {
  final LatLng coordinates;
  final String address;

  const LocationResult({required this.coordinates, required this.address});
}

/// Full-screen Google Maps location picker.
/// The user taps anywhere on the map to pin their location.
/// They can also tap "Use My Location" to jump to their GPS position.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Select Your Location',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(31.5497, 74.3436); // Default: Lahore
  Set<Marker> _markers = {};
  bool _loadingGps = false;
  String _addressDisplay = 'Tap anywhere on the map to select your location';

  // Pakistan approximate bounds for camera
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(30.3753, 69.3451), // Center of Pakistan
    zoom: 5.5,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _placeMarker(_selectedLocation);
    }
  }

  void _onMapTap(LatLng position) {
    HapticFeedback.selectionClick();
    _placeMarker(position);
    setState(() {
      _addressDisplay = '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}\n'
          '(Tap "Confirm" to use this location)';
    });
  }

  void _placeMarker(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> _useMyLocation() async {
    setState(() => _loadingGps = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable them.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied. Enable it in Settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final myLocation = LatLng(position.latitude, position.longitude);
      _placeMarker(myLocation);
      setState(() => _addressDisplay =
          'My Location\n${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}');
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.redError.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
    ));
  }

  void _confirm() {
    if (_markers.isEmpty) {
      _showError('Please tap on the map to select a location first.');
      return;
    }
    Navigator.pop(
      context,
      LocationResult(
        coordinates: _selectedLocation,
        address: _addressDisplay,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: widget.initialLocation != null
                ? CameraPosition(target: widget.initialLocation!, zoom: 14)
                : _defaultCamera,
            markers: _markers,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onTap: _onMapTap,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkMapStyle,
          ),

          // ── Header bar ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark.withValues(alpha: 0.95),
                    borderRadius: AppTheme.radiusLg,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.title,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const Text('Tap on the map or use GPS',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ]),
                    ),
                    // GPS button
                    GestureDetector(
                      onTap: _loadingGps ? null : _useMyLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                          borderRadius: AppTheme.radiusMd,
                          border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.4)),
                        ),
                        child: _loadingGps
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(color: AppTheme.tealPrimary, strokeWidth: 2))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.my_location, color: AppTheme.tealPrimary, size: 16),
                                SizedBox(width: 6),
                                Text('My Location',
                                    style: TextStyle(color: AppTheme.tealPrimary,
                                        fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: AppTheme.cardDark.withValues(alpha: 0.97),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selected location display
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, color: AppTheme.tealPrimary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _addressDisplay,
                        style: TextStyle(
                          color: _markers.isEmpty
                              ? AppTheme.textMuted
                              : Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _markers.isEmpty ? null : _confirm,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Confirm This Location',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tealPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.textMuted.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.2, duration: 400.ms),
          ),

          // ── Center crosshair ───────────────────────────────────────────────
          if (_markers.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: AppTheme.radiusMd,
                    ),
                    child: const Text('Tap to drop pin',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Google Maps dark style JSON ────────────────────────────────────────────
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0A0F1E"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#64779e"}]},
  {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
  {"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3C7680"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
  {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023747"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"transit","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit.line","elementType":"geometry.fill","stylers":[{"color":"#283d6a"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';
