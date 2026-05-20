import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  late LatLng _currentPosition;
  bool _isLoading = true;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition!;
      _isLoading = false;
      _initMapDelay();
    } else {
      _determinePosition();
    }
  }

  void _initMapDelay() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _showMap = true);
    }
  }

  Future<void> _determinePosition() async {
    final result = await LocationService().getCurrentLocation();
    if (!result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your live location is not enabled. Please enable it to continue.'),
            backgroundColor: AppTheme.redAlert,
          ),
        );
        Navigator.pop(context); // Go back instead of defaulting to Islamabad
      }
      return;
    }

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(result.data!.latitude, result.data!.longitude);
        _isLoading = false;
        _showMap = true;
      });
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Select Location', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.tealPrimary),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _currentPosition);
            },
            child: const Text('Confirm', style: TextStyle(color: AppTheme.tealPrimary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading || !_showMap
          ? const Center(child: CircularProgressIndicator(color: AppTheme.tealPrimary))
          : Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14.0),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _controller = controller;
                    },
                    onCameraMove: (CameraPosition position) {
                      _currentPosition = position.target;
                    },
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35.0),
                    child: const Icon(Icons.location_on, size: 40, color: AppTheme.tealPrimary),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                      borderRadius: AppTheme.radiusMd,
                      border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Move the map to set your exact location for better matching.',
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
