import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/micro_route.dart';
import '../../models/place_model.dart';
import '../../services/location_service.dart';
import '../../services/transport_service.dart';
import '../../theme/app_theme.dart';

class RouteScreen extends StatefulWidget {
  final DestinoLugar destination;
  final LatLng? initialOrigin;

  const RouteScreen({
    super.key,
    required this.destination,
    this.initialOrigin,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final MapController _mapController = MapController();
  final TransportService _transport = TransportService();

  LatLng? _origin;
  List<MicroRouteSuggestion> _suggestions = [];
  List<List<LatLng>> _lineSegments = [];
  MicroRouteSuggestion? _selected;
  bool _loadingLocation = true;
  bool _loadingRoutes = false;
  String? _message;

  LatLng get _destination => widget.destination.ubicacion;

  @override
  void initState() {
    super.initState();
    _origin = widget.initialOrigin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    if (_origin == null) {
      setState(() => _loadingLocation = true);
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      if (position == null) {
        setState(() {
          _loadingLocation = false;
          _message =
              'No pudimos obtener tu ubicación. Toca el mapa para marcar tu punto de partida.';
        });
        _moveToDestination();
        return;
      }
      _origin = position;
    }

    setState(() {
      _loadingLocation = false;
      _message = null;
    });
    _moveToDestination();
    await _loadRoutes();
  }

  void _moveToDestination() {
    final origin = _origin;
    if (origin == null) {
      _mapController.move(_destination, 13.5);
      return;
    }
    final center = LatLng(
      (origin.latitude + _destination.latitude) / 2,
      (origin.longitude + _destination.longitude) / 2,
    );
    final distance = LocationService.metersBetween(origin, _destination);
    final zoom = distance > 12000
        ? 11.5
        : distance > 5000
            ? 12.5
            : 14.0;
    _mapController.move(center, zoom);
  }

  Future<void> _loadRoutes() async {
    final origin = _origin;
    if (origin == null) return;

    setState(() {
      _loadingRoutes = true;
      _selected = null;
      _lineSegments = [];
    });

    final suggestions = await _transport.planRoute(
      origin: origin,
      destination: _destination,
    );

    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      _loadingRoutes = false;
    });

    if (suggestions.isNotEmpty) {
      await _selectSuggestion(suggestions.first);
    }
  }

  Future<void> _selectSuggestion(MicroRouteSuggestion suggestion) async {
    setState(() {
      _selected = suggestion;
      _lineSegments = [];
    });

    final segments = await _transport.getLinePolyline(suggestion.linea1);
    List<List<LatLng>> second = [];
    if (suggestion.linea2 != null && suggestion.linea2!.isNotEmpty) {
      second = await _transport.getLinePolyline(suggestion.linea2!);
    }

    if (!mounted) return;
    setState(() => _lineSegments = [...segments, ...second]);
  }

  Future<void> _setOriginFromMap(LatLng point) async {
    setState(() {
      _origin = point;
      _lineSegments = [];
    });
    _moveToDestination();
    await _loadRoutes();
  }

  Future<void> _useMyLocation() async {
    setState(() => _loadingLocation = true);
    final position = await LocationService.currentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() => _loadingLocation = false);
      _snack('No pudimos obtener tu ubicación.');
      return;
    }
    _origin = position;
    setState(() => _loadingLocation = false);
    _moveToDestination();
    await _loadRoutes();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    final selected = _selected;
    final timing = selected == null || origin == null
        ? null
        : _transport.estimate(
            origin: origin,
            destination: _destination,
            suggestion: selected,
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cómo llegar', style: TextStyle(fontSize: 18)),
            Text(
              widget.destination.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recalcular',
            onPressed: _loadingRoutes ? null : _loadRoutes,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _destination,
              initialZoom: 13.5,
              onTap: (_, point) => _setOriginFromMap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.turisapp.app',
              ),
              if (origin != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [origin, _destination],
                      color: Colors.grey.withValues(alpha: 0.7),
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                    if (selected != null)
                      for (final segment in _lineSegments)
                        Polyline(
                          points: segment,
                          color: (selected.info1?.colorUi ?? AppTheme.primaryColor)
                              .withValues(alpha: 0.85),
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                        ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (origin != null)
                    Marker(
                      point: origin,
                      width: 34,
                      height: 34,
                      child: const _MapPin(
                        color: Colors.blue,
                        icon: Icons.person_pin_circle_rounded,
                      ),
                    ),
                  Marker(
                    point: _destination,
                    width: 42,
                    height: 42,
                    child: const _MapPin(
                      color: AppTheme.secondaryColor,
                      icon: Icons.place_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            right: 14,
            top: 14,
            child: FloatingActionButton.small(
              heroTag: 'route_location',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              onPressed: _loadingLocation ? null : _useMyLocation,
              child: _loadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          if (_loadingRoutes)
            const Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Calculando ruta...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.2,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 14,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_message!,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    if (_message != null) const SizedBox(height: 12),

                    _OriginRow(
                      origin: origin,
                      destination: _destination,
                      onUseLocation: _useMyLocation,
                    ),
                    const SizedBox(height: 16),

                    if (timing != null && selected != null) ...[
                      _SelectedRouteSummary(
                        suggestion: selected,
                        timing: timing,
                      ),
                      const SizedBox(height: 18),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Líneas sugeridas',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_suggestions.length} opciones',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_loadingRoutes)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_suggestions.isEmpty)
                      _EmptyRoutes(origin: origin, destination: _destination)
                    else
                      ..._suggestions.map((suggestion) {
                        final sTiming = origin == null
                            ? null
                            : _transport.estimate(
                                origin: origin,
                                destination: _destination,
                                suggestion: suggestion,
                              );
                        return _SuggestionCard(
                          suggestion: suggestion,
                          timing: sTiming,
                          selected: _selected == suggestion,
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      }),

                    const SizedBox(height: 14),
                    const Text(
                      'Los tiempos son estimados y consideran caminata, espera y recorrido. '
                      'Verifica la información con el conductor.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _OriginRow extends StatelessWidget {
  final LatLng? origin;
  final LatLng destination;
  final VoidCallback onUseLocation;

  const _OriginRow({
    required this.origin,
    required this.destination,
    required this.onUseLocation,
  });

  @override
  Widget build(BuildContext context) {
    final distance = origin == null
        ? null
        : LocationService.metersBetween(origin!, destination);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trip_origin_rounded,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Punto de partida',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  origin == null
                      ? 'Toca el mapa para marcarlo'
                      : (distance != null && distance < 1000
                          ? 'Tu ubicación · a ${distance.toStringAsFixed(0)} m'
                          : 'Tu ubicación · a ${(distance! / 1000).toStringAsFixed(1)} km'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onUseLocation,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Mi ubicación'),
          ),
        ],
      ),
    );
  }
}

class _SelectedRouteSummary extends StatelessWidget {
  final MicroRouteSuggestion suggestion;
  final RouteTiming timing;

  const _SelectedRouteSummary({
    required this.suggestion,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.esDirecta
                      ? 'Línea ${suggestion.numero1}'
                      : 'Línea ${suggestion.numero1} → ${suggestion.numero2}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timing.totalLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.directions_walk_rounded,
                text: '${timing.walkingMeters.toStringAsFixed(0)} m a pie',
              ),
              _Chip(
                icon: Icons.directions_bus_rounded,
                text: '${timing.ridingMinutes} min en micro',
              ),
              _Chip(
                icon: Icons.schedule_rounded,
                text: '${timing.waitingMinutes} min de espera',
              ),
              _Chip(
                icon: Icons.payments_outlined,
                text: 'Bs. ${timing.fare.toStringAsFixed(0)}',
              ),
              _Chip(
                icon: Icons.alt_route_rounded,
                text: suggestion.esDirecta ? 'Sin transbordos' : '1 transbordo',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final MicroRouteSuggestion suggestion;
  final RouteTiming? timing;
  final bool selected;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
    required this.timing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = suggestion.info1?.colorUi ?? AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Column(
                children: [
                  _LineBadge(
                    text: suggestion.numero1,
                    color: color,
                  ),
                  if (suggestion.esTransbordo) ...[
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_downward_rounded,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(height: 4),
                    _LineBadge(
                      text: suggestion.numero2,
                      color: suggestion.info2?.colorUi ??
                          AppTheme.secondaryColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.esDirecta
                          ? 'Micro directo'
                          : 'Con 1 transbordo',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Camina ${suggestion.distanciaOrigen.toStringAsFixed(0)} m para tomarlo'
                      '${suggestion.esTransbordo ? ' · transbordo a ${suggestion.distanciaTransbordo.toStringAsFixed(0)} m' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (timing != null) ...[
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppTheme.primaryColor),
                          const SizedBox(width: 3),
                          Text(
                            timing!.totalLabel,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'Bs. ${suggestion.tarifa.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _LineBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyRoutes extends StatelessWidget {
  final LatLng? origin;
  final LatLng destination;

  const _EmptyRoutes({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    final distance = origin == null
        ? null
        : LocationService.metersBetween(origin!, destination);
    final walkMinutes = distance == null
        ? null
        : (distance / TransportService.walkMetersPerMinute).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_bus_outlined,
              size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          const Text(
            'No encontramos líneas de micro cerca de este recorrido.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (distance != null) ...[
            const SizedBox(height: 6),
            Text(
              'Distancia aproximada: ${distance < 1000 ? '${distance.toStringAsFixed(0)} m' : '${(distance / 1000).toStringAsFixed(1)} km'}'
              '${walkMinutes != null ? ' · ~$walkMinutes min caminando' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Prueba marcando otro punto de partida en el mapa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
