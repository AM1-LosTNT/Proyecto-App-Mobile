import 'package:flutter/material.dart';

/// Estados posibles de una reserva.
///
/// En la base de datos se guardan en minúsculas. El lector acepta también los
/// valores antiguos ("Pendiente", "Confirmada", etc.) para que la app siga
/// funcionando aunque la migración SQL todavía no se haya ejecutado.
enum ReservationStatus {
  pendiente(
    'pendiente',
    'En espera',
    'El negocio todavía debe confirmar tu solicitud.',
    Icons.hourglass_top_rounded,
    Color(0xFFF59E0B),
  ),
  aceptada(
    'aceptada',
    'Aceptada',
    'El negocio confirmó tu reserva.',
    Icons.check_circle_rounded,
    Color(0xFF16A34A),
  ),
  rechazada(
    'rechazada',
    'Rechazada',
    'El negocio no pudo aceptar tu solicitud.',
    Icons.cancel_rounded,
    Color(0xFFDC2626),
  ),
  completada(
    'completada',
    'Completada',
    'La reserva ya se realizó.',
    Icons.task_alt_rounded,
    Color(0xFF475569),
  ),
  cancelada(
    'cancelada',
    'Cancelada',
    'La reserva fue cancelada.',
    Icons.remove_circle_rounded,
    Color(0xFF94A3B8),
  );

  const ReservationStatus(
    this.dbValue,
    this.label,
    this.description,
    this.icon,
    this.color,
  );

  final String dbValue;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  static ReservationStatus fromDb(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'pendiente':
      case 'en espera':
      case 'pending':
        return pendiente;
      case 'aceptada':
      case 'confirmada':
      case 'accepted':
      case 'confirmed':
        return aceptada;
      case 'rechazada':
      case 'rejected':
        return rechazada;
      case 'completada':
      case 'completed':
        return completada;
      case 'cancelada':
      case 'cancelled':
      case 'canceled':
        return cancelada;
      default:
        return pendiente;
    }
  }

  /// El turista puede cancelar mientras la reserva no haya terminado.
  bool get puedeCancelarTurista => this == pendiente || this == aceptada;

  /// El negocio solo puede aceptar o rechazar solicitudes en espera.
  bool get puedeGestionarNegocio => this == pendiente;
}

/// Reserva ya normalizada para mostrarse en las pantallas.
class Reserva {
  final String id;
  final String idDestino;
  final String idTurista;
  final String fecha;
  final String hora;
  final int cantidadPersonas;
  final double precioUnitario;
  final double total;
  final ReservationStatus estado;
  final String motivoRechazo;
  final DateTime? createdAt;

  final String destinoNombre;
  final String destinoImagen;
  final String destinoDireccion;

  final String clienteNombre;
  final String clienteEmail;
  final String clienteTelefono;

  const Reserva({
    required this.id,
    required this.idDestino,
    required this.idTurista,
    required this.fecha,
    required this.hora,
    required this.cantidadPersonas,
    required this.precioUnitario,
    required this.total,
    required this.estado,
    required this.motivoRechazo,
    required this.createdAt,
    required this.destinoNombre,
    required this.destinoImagen,
    required this.destinoDireccion,
    required this.clienteNombre,
    required this.clienteEmail,
    required this.clienteTelefono,
  });

  factory Reserva.fromMap(Map<String, dynamic> map) {
    final destino = map['destinos_lugares'];
    final usuario = map['usuarios'];
    final destinoMap = destino is Map ? destino : const <String, dynamic>{};
    final usuarioMap = usuario is Map ? usuario : const <String, dynamic>{};

    final fechaCruda = map['fecha_reserva']?.toString() ?? '';
    var fecha = fechaCruda;
    var hora = _normalizarHora(map['hora_reserva']?.toString() ?? '');

    // Compatibilidad con reservas antiguas que guardaban todo en fecha_reserva.
    if (fechaCruda.contains('T')) {
      final partes = fechaCruda.split('T');
      fecha = partes.first;
      if (hora.isEmpty && partes.length > 1) {
        hora = _normalizarHora(partes[1]);
      }
    }

    return Reserva(
      id: map['id']?.toString() ?? '',
      idDestino: map['id_destino']?.toString() ?? '',
      idTurista: map['id_turista']?.toString() ?? '',
      fecha: fecha,
      hora: hora,
      cantidadPersonas: (map['cantidad_personas'] as num?)?.toInt() ?? 1,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      estado: ReservationStatus.fromDb(map['estado']),
      motivoRechazo: map['motivo_rechazo']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      destinoNombre:
          destinoMap['nombre']?.toString() ?? 'Lugar reservado',
      destinoImagen: destinoMap['imagen_principal']?.toString() ?? '',
      destinoDireccion: destinoMap['direccion']?.toString() ?? '',
      clienteNombre: usuarioMap['nombre']?.toString() ?? 'Turista',
      clienteEmail: usuarioMap['email']?.toString() ?? '',
      clienteTelefono: usuarioMap['telefono']?.toString() ?? '',
    );
  }

  static String _normalizarHora(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final h = match.group(1)!.padLeft(2, '0');
    final m = match.group(2)!;
    return '$h:$m';
  }

  DateTime? get fechaHora {
    if (fecha.isEmpty) return null;
    final horaSegura = hora.isEmpty ? '00:00' : hora;
    return DateTime.tryParse('${fecha}T$horaSegura:00');
  }

  bool get esFutura {
    final fechaReserva = fechaHora;
    if (fechaReserva == null) return true;
    return fechaReserva.isAfter(DateTime.now());
  }

  static const List<String> _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String get fechaTexto {
    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return fecha.isEmpty ? 'Fecha por confirmar' : fecha;
    return '${parsed.day} ${_meses[parsed.month - 1]} ${parsed.year}';
  }

  String get horaTexto => hora.isEmpty ? 'Hora por confirmar' : hora;

  String get fechaHoraTexto => '$fechaTexto · $horaTexto';

  String get totalTexto => 'Bs. ${total.toStringAsFixed(2)}';

  String get personasTexto =>
      '$cantidadPersonas ${cantidadPersonas == 1 ? 'persona' : 'personas'}';
}
