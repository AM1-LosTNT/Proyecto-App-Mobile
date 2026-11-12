import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MicroLineInfo {
  final String id;
  final String numero;
  final String color;
  final double tarifa;
  final String descripcion;

  const MicroLineInfo({
    required this.id,
    required this.numero,
    this.color = '',
    this.tarifa = 2.0,
    this.descripcion = '',
  });

  factory MicroLineInfo.fromMap(Map<String, dynamic> map) {
    return MicroLineInfo(
      id: map['id']?.toString() ?? '',
      numero: map['numero']?.toString() ?? map['id']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      tarifa: (map['tarifa'] as num?)?.toDouble() ?? 2.0,
      descripcion: map['descripcion']?.toString() ?? '',
    );
  }

  Color get colorUi {
    final raw = color.replaceAll('#', '').trim();
    if (raw.length == 6) {
      final value = int.tryParse(raw, radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return const Color(0xFF0F766E);
  }
}

class MicroRouteSuggestion {
  final String tipo; // 'directa' o 'transbordo'
  final String linea1;
  final String? linea2;
  final double distanciaOrigen;
  final double distanciaDestino;
  final double distanciaTransbordo;
  final MicroLineInfo? info1;
  final MicroLineInfo? info2;

  const MicroRouteSuggestion({
    required this.tipo,
    required this.linea1,
    this.linea2,
    required this.distanciaOrigen,
    required this.distanciaDestino,
    this.distanciaTransbordo = 0,
    this.info1,
    this.info2,
  });

  bool get esTransbordo => tipo == 'transbordo' && linea2 != null;
  bool get esDirecta => !esTransbordo;

  double get caminataTotal =>
      distanciaOrigen + distanciaDestino + (esTransbordo ? distanciaTransbordo : 0);

  String get numero1 => info1?.numero ?? linea1;
  String get numero2 => info2?.numero ?? linea2 ?? '';

  double get tarifa => esTransbordo
      ? (info1?.tarifa ?? 2.0) + (info2?.tarifa ?? 2.0)
      : (info1?.tarifa ?? 2.0);

  factory MicroRouteSuggestion.fromMap(Map<String, dynamic> map) {
    final tipo = map['tipo']?.toString() ?? 'directa';
    return MicroRouteSuggestion(
      tipo: tipo,
      linea1: map['linea_1']?.toString() ?? '',
      linea2: map['linea_2']?.toString(),
      distanciaOrigen: (map['distancia_origen'] as num?)?.toDouble() ?? 0,
      distanciaDestino: (map['distancia_destino'] as num?)?.toDouble() ?? 0,
      distanciaTransbordo: (map['distancia_transbordo'] as num?)?.toDouble() ?? 0,
    );
  }

  MicroRouteSuggestion withInfo({
    MicroLineInfo? info1,
    MicroLineInfo? info2,
  }) {
    return MicroRouteSuggestion(
      tipo: tipo,
      linea1: linea1,
      linea2: linea2,
      distanciaOrigen: distanciaOrigen,
      distanciaDestino: distanciaDestino,
      distanciaTransbordo: distanciaTransbordo,
      info1: info1 ?? this.info1,
      info2: info2 ?? this.info2,
    );
  }
}

class NearbyMicroLine {
  final String linea;
  final int sentido;
  final double distanciaMetros;

  const NearbyMicroLine({
    required this.linea,
    required this.sentido,
    required this.distanciaMetros,
  });

  factory NearbyMicroLine.fromMap(Map<String, dynamic> map) {
    return NearbyMicroLine(
      linea: map['linea']?.toString() ?? '',
      sentido: (map['sentido'] as num?)?.toInt() ?? 0,
      distanciaMetros: (map['distancia_metros'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MicroRoutePlan {
  final LatLng origen;
  final LatLng destino;
  final List<MicroRouteSuggestion> sugerencias;
  final List<LatLng> caminataOrigen;
  final List<LatLng> caminataDestino;

  const MicroRoutePlan({
    required this.origen,
    required this.destino,
    required this.sugerencias,
    this.caminataOrigen = const [],
    this.caminataDestino = const [],
  });
}
