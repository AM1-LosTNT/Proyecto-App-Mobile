import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/micro_route.dart';
import 'location_service.dart';
import 'supabase_service.dart';

class RouteTiming {
  final int totalMinutes;
  final int walkingMinutes;
  final int ridingMinutes;
  final int waitingMinutes;
  final double walkingMeters;
  final double fare;

  const RouteTiming({
    required this.totalMinutes,
    required this.walkingMinutes,
    required this.ridingMinutes,
    required this.waitingMinutes,
    required this.walkingMeters,
    required this.fare,
  });

  String get totalLabel {
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }
}

class TransportService {
  final SupabaseService _service;

  TransportService([SupabaseService? service])
      : _service = service ?? SupabaseService();

  static const double walkMetersPerMinute = 80;
  static const double busMetersPerMinute = 400;
  static const int waitMinutes = 6;
  static const int transferWaitMinutes = 7;
  static const double _roadFactor = 1.3;

  Future<List<MicroRouteSuggestion>> planRoute({
    required LatLng origin,
    required LatLng destination,
    double searchRadius = 700,
  }) async {
    final originLat = origin.latitude;
    final originLng = origin.longitude;
    final destLat = destination.latitude;
    final destLng = destination.longitude;

    var suggestions = await _service.planificarRutaMicros(
      origenLat: originLat,
      origenLng: originLng,
      destinoLat: destLat,
      destinoLng: destLng,
      distanciaMetros: searchRadius,
    );

    if (suggestions.isEmpty) {
      suggestions = await _fallbackPlan(
        origin: origin,
        destination: destination,
        searchRadius: searchRadius,
      );
    }

    if (suggestions.isEmpty) return [];

    final lineIds = <String>{};
    for (final suggestion in suggestions) {
      if (suggestion.linea1.isNotEmpty) lineIds.add(suggestion.linea1);
      if (suggestion.linea2 != null && suggestion.linea2!.isNotEmpty) {
        lineIds.add(suggestion.linea2!);
      }
    }

    final info = await _service.getLineasInfo(lineIds);
    final enriched = suggestions
        .map((s) => s.withInfo(
              info1: info[s.linea1],
              info2: s.linea2 == null ? null : info[s.linea2],
            ))
        .toList();

    enriched.sort((a, b) {
      if (a.esDirecta != b.esDirecta) return a.esDirecta ? -1 : 1;
      return a.caminataTotal.compareTo(b.caminataTotal);
    });

    return enriched.take(6).toList();
  }

  Future<List<MicroRouteSuggestion>> _fallbackPlan({
    required LatLng origin,
    required LatLng destination,
    required double searchRadius,
  }) async {
    final results = await Future.wait([
      _service.getMicrosCercanos(
        lat: origin.latitude,
        lng: origin.longitude,
        distanciaMetros: searchRadius,
      ),
      _service.getMicrosCercanos(
        lat: destination.latitude,
        lng: destination.longitude,
        distanciaMetros: searchRadius,
      ),
    ]);

    final originLines = results[0];
    final destLines = results[1];
    if (originLines.isEmpty || destLines.isEmpty) return [];

    final suggestions = <MicroRouteSuggestion>[];
    final seen = <String>{};

    for (final o in originLines) {
      for (final d in destLines) {
        if (o.linea != d.linea) continue;
        final key = 'directa-${o.linea}';
        if (!seen.add(key)) continue;
        suggestions.add(MicroRouteSuggestion(
          tipo: 'directa',
          linea1: o.linea,
          distanciaOrigen: o.distanciaMetros,
          distanciaDestino: d.distanciaMetros,
        ));
      }
    }

    if (suggestions.isEmpty) {
      final pairs = <MicroRouteSuggestion>[];
      for (final o in originLines) {
        for (final d in destLines) {
          if (o.linea == d.linea) continue;
          pairs.add(MicroRouteSuggestion(
            tipo: 'transbordo',
            linea1: o.linea,
            linea2: d.linea,
            distanciaOrigen: o.distanciaMetros,
            distanciaDestino: d.distanciaMetros,
            distanciaTransbordo: 250,
          ));
        }
      }
      pairs.sort((a, b) => a.caminataTotal.compareTo(b.caminataTotal));
      suggestions.addAll(pairs.take(5));
    }

    return suggestions;
  }

  RouteTiming estimate({
    required LatLng origin,
    required LatLng destination,
    required MicroRouteSuggestion suggestion,
  }) {
    final directDistance =
        LocationService.metersBetween(origin, destination) * _roadFactor;
    final walking = suggestion.caminataTotal;
    final riding = math.max(directDistance - walking, 350.0);

    final walkingMinutes = (walking / walkMetersPerMinute).ceil().clamp(1, 180);
    final ridingMinutes = (riding / busMetersPerMinute).ceil().clamp(3, 240);
    final waiting = waitMinutes + (suggestion.esTransbordo ? transferWaitMinutes : 0);

    return RouteTiming(
      totalMinutes: walkingMinutes + ridingMinutes + waiting,
      walkingMinutes: walkingMinutes,
      ridingMinutes: ridingMinutes,
      waitingMinutes: waiting,
      walkingMeters: walking,
      fare: suggestion.tarifa,
    );
  }

  Future<List<List<LatLng>>> getLinePolyline(String lineaId) async {
    final rawSegments = await _service.getLineaTrazado(lineaId);
    return rawSegments
        .map((segment) =>
            segment.map((p) => LatLng(p.latitude, p.longitude)).toList())
        .where((segment) => segment.length > 1)
        .toList();
  }
}
