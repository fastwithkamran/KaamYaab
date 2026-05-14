import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Select Your Location',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(
      text: (widget.initialLatitude ?? 31.5497).toStringAsFixed(6),
    );
    _lngCtrl = TextEditingController(
      text: (widget.initialLongitude ?? 74.3436).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _loadingGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showError('Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission denied.');
        return;
      }

      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latCtrl.text = p.latitude.toStringAsFixed(6);
      _lngCtrl.text = p.longitude.toStringAsFixed(6);
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.redError,
      ),
    );
  }

  void _confirm() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      _showError('Enter valid latitude and longitude.');
      return;
    }
    Navigator.pop(
      context,
      LocationResult(
        latitude: lat,
        longitude: lng,
        address: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _latCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lngCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingGps ? null : _useMyLocation,
                icon: _loadingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: const Text('Use My Current GPS Location'),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                child: const Text('Confirm This Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
