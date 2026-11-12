import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initial;

  const MapPickerScreen({super.key, required this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _controller = MapController();
  late LatLng _point;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  Future<void> _goToLocation() async {
    setState(() => _locating = true);
    final position = await LocationService.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position != null) {
      setState(() => _point = position);
      _controller.move(position, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicar en el mapa')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _point = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.turisapp.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 46,
                    height: 46,
                    child: const Icon(Icons.location_on_rounded,
                        color: AppTheme.secondaryColor, size: 44),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 14,
            right: 14,
            child: FloatingActionButton.small(
              heroTag: 'picker_location',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              onPressed: _locating ? null : _goToLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Toca el mapa para mover el marcador',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'Lat: ${_point.latitude.toStringAsFixed(6)} · '
                          'Lng: ${_point.longitude.toStringAsFixed(6)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _point),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Usar esta ubicación'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
