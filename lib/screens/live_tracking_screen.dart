import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import '../services/location_service.dart';

/// Uber-style live worker tracking screen.
/// Shows an animated worker marker moving toward the user on a Google Map.
class LiveTrackingScreen extends StatefulWidget {
  final ProviderMatch match;
  final ServiceRequest request;

  const LiveTrackingScreen({
    super.key,
    required this.match,
    required this.request,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isLoadingLocation = true;

  // Worker starts ~distance km away from user
  late LatLng _userPos;
  late LatLng _workerPos;
  late LatLng _workerStart;
  late LatLng _workerTarget;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ETA countdown
  late int _etaSeconds;
  late int _totalSeconds;
  Timer? _movementTimer;
  Timer? _etaTimer;

  String _status = 'En-Route'; // En-Route → Arriving → Arrived
  bool _arrived = false;
  final bool _mapLoadFailed = false; // BUG-3 FIX: graceful Maps API fallback

  late AnimationController _pulseCtrl;
  late AnimationController _statusCtrl;

  // Map style — dark theme matching the app
  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _statusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initLiveTracking();
  }

  Future<void> _initLiveTracking() async {
    final locResult = await LocationService().getCurrentLocation();
    if (!locResult.isSuccess || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live location is required for tracking.'), backgroundColor: AppTheme.redAlert),
        );
        Navigator.pop(context);
      }
      return;
    }

    _userPos = LatLng(locResult.data!.latitude, locResult.data!.longitude);

    // Place worker at a realistic offset based on their distance
    final distKm = widget.match.distanceKm.clamp(0.5, 15.0);
    // Random angle so workers come from different directions each time
    final angle = (widget.match.provider.id.hashCode % 360) * math.pi / 180;
    final latOffset = (distKm / 111.0) * math.cos(angle);
    final lngOffset = (distKm / 111.0) * math.sin(angle) /
        math.cos(_userPos.latitude * math.pi / 180);
    _workerStart = LatLng(_userPos.latitude + latOffset, _userPos.longitude + lngOffset);
    _workerTarget = _userPos;
    _workerPos = _workerStart;

    _etaSeconds = widget.match.etaMinutes * 60;
    // Guard: ensure _totalSeconds is never 0 to avoid division-by-zero
    _totalSeconds = _etaSeconds > 0 ? _etaSeconds : 1;

    _buildMarkersAndRoute();
    _startSimulation();

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _buildMarkersAndRoute() {
    _markers = {
      // User pin
      Marker(
        markerId: const MarkerId('user'),
        position: _userPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Your Location', snippet: widget.request.area),
      ),
      // Worker pin (starts at offset position)
      Marker(
        markerId: const MarkerId('worker'),
        position: _workerPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.match.provider.name,
          snippet: '${widget.match.provider.serviceCategory} · ETA ${widget.match.etaMinutes} min',
        ),
        rotation: _bearing(_workerPos, _userPos),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        color: AppTheme.tealPrimary.withValues(alpha: 0.8),
        width: 4,
        points: [_workerPos, _userPos],
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  void _startSimulation() {
    // Move worker every 2 seconds
    _movementTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted || _arrived) { t.cancel(); return; }
      _updateWorkerPosition();
    });

    // Countdown timer every second
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _arrived) { t.cancel(); return; }
      setState(() {
        if (_etaSeconds > 0) _etaSeconds--;
        if (_etaSeconds <= 120 && _status == 'En-Route') {
          _status = 'Arriving Soon';
          _statusCtrl.forward();
          HapticFeedback.mediumImpact();
        }
        if (_etaSeconds == 0) {
          _status = 'Arrived! 🎉';
          _arrived = true;
          _workerPos = _userPos;
          HapticFeedback.heavyImpact();
          _buildMarkersAndRoute();
          _movementTimer?.cancel();
          _etaTimer?.cancel();
        }
      });
    });
  }

  void _updateWorkerPosition() {
    if (!mounted) return;
    // Linear interpolation: progress = elapsed / total
    final progress = 1.0 - (_etaSeconds / _totalSeconds).clamp(0.0, 1.0);
    final newLat = _workerStart.latitude +
        (_workerTarget.latitude - _workerStart.latitude) * progress;
    final newLng = _workerStart.longitude +
        (_workerTarget.longitude - _workerStart.longitude) * progress;

    setState(() {
      _workerPos = LatLng(newLat, newLng);
      _markers = {
        Marker(
          markerId: const MarkerId('user'),
          position: _userPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'Your Location', snippet: widget.request.area),
        ),
        Marker(
          markerId: const MarkerId('worker'),
          position: _workerPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _arrived ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: widget.match.provider.name,
            snippet: _status,
          ),
          rotation: _bearing(_workerPos, _userPos),
        ),
      };
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppTheme.tealPrimary.withValues(alpha: 0.7),
          width: 4,
          points: [_workerPos, _userPos],
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    // Keep camera focused between worker and user
    try {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            math.min(_workerPos.latitude, _userPos.latitude) - 0.005,
            math.min(_workerPos.longitude, _userPos.longitude) - 0.005,
          ),
          northeast: LatLng(
            math.max(_workerPos.latitude, _userPos.latitude) + 0.005,
            math.max(_workerPos.longitude, _userPos.longitude) + 0.005,
          ),
        ),
        80,
      ));
    } catch (_) {
      // Maps camera update failed — non-fatal, simulation continues
    }
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  String get _etaLabel {
    if (_etaSeconds <= 0) return 'Arrived!';
    final m = _etaSeconds ~/ 60;
    final s = _etaSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Color get _statusColor {
    if (_arrived) return AppTheme.goldAccent;
    if (_status == 'Arriving Soon') return Colors.orangeAccent;
    return AppTheme.tealPrimary;
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _etaTimer?.cancel();
    _pulseCtrl.dispose();
    _statusCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // BUG-3 FIX: Google Maps with graceful fallback
          if (_mapLoadFailed)
            _buildMapFallback()
          else
            _buildGoogleMap(),

          // ── Top bar overlay ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildBottomCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          (_userPos.latitude + _workerStart.latitude) / 2,
          (_userPos.longitude + _workerStart.longitude) / 2,
        ),
        zoom: 13.5,
      ),
      style: _darkMapStyle,
      markers: _markers,
      polylines: _polylines,
      mapType: MapType.normal,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
      },
    );
  }

  /// Fallback shown when Maps API is unavailable (no key, no internet, emulator)
  Widget _buildMapFallback() {
    final progress = (1.0 - _etaSeconds / _totalSeconds).clamp(0.0, 1.0);
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, a) => Container(
                width: 160 + _pulseCtrl.value * 20,
                height: 160 + _pulseCtrl.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.tealPrimary.withValues(alpha: 0.06 + _pulseCtrl.value * 0.04),
                  border: Border.all(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_rounded,
                          color: AppTheme.tealPrimary, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        '${(widget.match.distanceKm * (1.0 - progress)).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text('remaining',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Live Tracking (Simulated)',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.92),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: _statusColor.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: AppTheme.radiusSm,
            ),
            child: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _status,
              style: TextStyle(
                color: _statusColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.match.provider.name} · ${widget.request.serviceType}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ]),
        ),
        // ETA countdown
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1 + (_arrived ? 0 : _pulseCtrl.value * 0.05)),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              Text(
                _etaLabel,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _arrived ? 'Here!' : 'ETA',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3);
  }

  Widget _buildBottomCard() {
    final p = widget.match.provider;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.95),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.3)),
        boxShadow: AppTheme.tealGlow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Worker info row
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
              child: Text(
                p.name.length >= 2 ? p.name.substring(0, 2).toUpperCase() : p.name.toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.tealPrimary, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(p.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 6),
                  if (p.isVerified)
                    const Icon(Icons.verified_rounded, color: AppTheme.tealPrimary, size: 14),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 12),
                  const SizedBox(width: 3),
                  Text('${p.rating.toStringAsFixed(1)} · ${p.totalJobs} jobs',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('DNA ${p.dnascore}',
                        style: const TextStyle(
                            color: AppTheme.tealPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
            // Call button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('📞 Calling worker... (demo mode)'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.tealGlow,
                ),
                child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Progress bar
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.route_rounded, color: AppTheme.tealPrimary, size: 14),
              const SizedBox(width: 6),
              Text(
                '${(widget.match.distanceKm * (1.0 - (1.0 - _etaSeconds / _totalSeconds).clamp(0.0, 1.0))).toStringAsFixed(1)} km remaining',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${(100 * (1.0 - _etaSeconds / _totalSeconds).clamp(0.0, 1.0)).toInt()}% complete',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (1.0 - _etaSeconds / _totalSeconds).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(_statusColor),
                minHeight: 6,
              ),
            ),
          ]),

          const SizedBox(height: 14),

          // Journey detail pills
          Row(children: [
            _infoChip(Icons.location_on_outlined, widget.request.area),
            const SizedBox(width: 8),
            _infoChip(Icons.schedule_outlined, widget.match.recommendedSlot),
            const SizedBox(width: 8),
            _infoChip(Icons.payments_outlined, 'Rs. ${widget.match.quotePkr.toStringAsFixed(0)}'),
          ]),

          if (_arrived) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.goldAccent.withValues(alpha: 0.2),
                  AppTheme.tealPrimary.withValues(alpha: 0.1),
                ]),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🎉', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text('Your worker has arrived!',
                    style: TextStyle(
                        color: AppTheme.goldAccent, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.3);
  }

  Widget _infoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: AppTheme.radiusSm,
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Icon(icon, color: AppTheme.textMuted, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ),
        ]),
      ),
    );
  }
}