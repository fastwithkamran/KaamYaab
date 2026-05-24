import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Default to Karachi city centre — user drags the pin to their exact spot.
  // No GPS required.
  static const _defaultPosition = LatLng(24.8607, 67.0011);

  late LatLng _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition ?? _defaultPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Select Location',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.tealPrimary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _currentPosition),
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: AppTheme.tealPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _currentPosition, zoom: 14.0),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onCameraMove: (pos) => _currentPosition = pos.target,
            ),
          ),
          // Crosshair pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35.0),
              child: Icon(Icons.location_on, size: 40, color: AppTheme.tealPrimary),
            ),
          ),
          // Hint banner
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: AppTheme.textMuted.withValues(alpha: 0.2),
                ),
              ),
              child: const Text(
                'Drag the map to move the pin to your exact location, then tap Confirm.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}