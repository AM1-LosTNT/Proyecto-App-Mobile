import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const Distance _distance = Distance();

  static double metersBetween(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b);

  static Future<String?> ensurePermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return 'Activa la ubicación del dispositivo para calcular tu ruta.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return 'Necesitamos permiso de ubicación para mostrarte cómo llegar.';
      }
      if (permission == LocationPermission.deniedForever) {
        return 'El permiso de ubicación está bloqueado. Habilítalo en los ajustes del dispositivo.';
      }
      return null;
    } catch (_) {
      return 'No se pudo acceder a la ubicación del dispositivo.';
    }
  }

  static Future<LatLng?> currentPosition() async {
    final error = await ensurePermission();
    if (error != null) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LatLng(last.latitude, last.longitude);
      } catch (_) {}
      return null;
    }
  }
}
