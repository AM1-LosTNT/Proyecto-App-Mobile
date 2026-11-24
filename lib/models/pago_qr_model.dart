class PagoQrModel {
  final String id;
  final String? usuarioId;
  final String? idPedido;
  final String? idReserva;
  final String referenciaInterna;
  final double montoEsperado;
  final double? montoRecibido;
  final String moneda;
  final String? glosa;
  final String estado;
  final String? pagadoPor;
  final String? notificacionTexto;
  final double? saldoAnterior;
  final double? saldoNuevo;
  final String? validadoPorAdmin;
  final String? origenConfirmacion;
  final bool confirmadoAutomaticamente;
  final DateTime expiraEn;
  final DateTime? pagadoEn;
  final DateTime creadoEn;

  PagoQrModel({
    required this.id,
    this.usuarioId,
    this.idPedido,
    this.idReserva,
    required this.referenciaInterna,
    required this.montoEsperado,
    this.montoRecibido,
    this.moneda = 'BOB',
    this.glosa,
    this.estado = 'PENDIENTE',
    this.pagadoPor,
    this.notificacionTexto,
    this.saldoAnterior,
    this.saldoNuevo,
    this.validadoPorAdmin,
    this.origenConfirmacion,
    this.confirmadoAutomaticamente = false,
    required this.expiraEn,
    this.pagadoEn,
    required this.creadoEn,
  });

  bool get isPendiente => estado == 'PENDIENTE';

  /// Estado heredado de la versión anterior. Ya no se produce: la notificación
  /// pasa el cobro directo a `PAGADO`.
  bool get isValidadoNotif => estado == 'VALIDADO_NOTIF';

  bool get isPagado => estado == 'PAGADO';
  bool get isExpirado => estado == 'EXPIRADO';
  bool get isRechazado => estado == 'RECHAZADO';

  /// `true` si el pago se completó solo con la notificación de Yape.
  bool get isPagadoAutomatico =>
      isPagado &&
      (confirmadoAutomaticamente || origenConfirmacion == 'NOTIFICACION');

  /// `true` si el admin lo marcó a mano (respaldo).
  bool get isPagadoManual =>
      isPagado && origenConfirmacion == 'ADMIN' && !confirmadoAutomaticamente;

  /// Monto que realmente entró a la cuenta.
  double get montoAcreditado => montoRecibido ?? montoEsperado;

  factory PagoQrModel.fromMap(Map<String, dynamic> map) {
    return PagoQrModel(
      id: map['id']?.toString() ?? '',
      usuarioId: map['usuario_id']?.toString(),
      idPedido: map['id_pedido']?.toString(),
      idReserva: map['id_reserva']?.toString(),
      referenciaInterna: map['referencia_interna'] ?? '',
      montoEsperado: (map['monto_esperado'] as num?)?.toDouble() ?? 0.0,
      montoRecibido: (map['monto_recibido'] as num?)?.toDouble(),
      moneda: map['moneda'] ?? 'BOB',
      glosa: map['glosa'],
      estado: map['estado'] ?? 'PENDIENTE',
      pagadoPor: map['pagado_por'],
      notificacionTexto: map['notificacion_texto'],
      saldoAnterior: (map['saldo_anterior'] as num?)?.toDouble(),
      saldoNuevo: (map['saldo_nuevo'] as num?)?.toDouble(),
      validadoPorAdmin: map['validado_por_admin']?.toString(),
      origenConfirmacion: map['origen_confirmacion']?.toString(),
      confirmadoAutomaticamente: map['confirmado_automaticamente'] == true,
      expiraEn: map['expira_en'] != null
          ? DateTime.tryParse(map['expira_en'].toString()) ?? DateTime.now()
          : DateTime.now(),
      pagadoEn: map['pagado_en'] != null
          ? DateTime.tryParse(map['pagado_en'].toString())
          : null,
      creadoEn: map['creado_en'] != null
          ? DateTime.tryParse(map['creado_en'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'id_pedido': idPedido,
      'id_reserva': idReserva,
      'referencia_interna': referenciaInterna,
      'monto_esperado': montoEsperado,
      'monto_recibido': montoRecibido,
      'moneda': moneda,
      'glosa': glosa,
      'estado': estado,
      'pagado_por': pagadoPor,
      'notificacion_texto': notificacionTexto,
      'saldo_anterior': saldoAnterior,
      'saldo_nuevo': saldoNuevo,
      'validado_por_admin': validadoPorAdmin,
      'origen_confirmacion': origenConfirmacion,
      'confirmado_automaticamente': confirmadoAutomaticamente,
      'expira_en': expiraEn.toIso8601String(),
      'pagado_en': pagadoEn?.toIso8601String(),
      'creado_en': creadoEn.toIso8601String(),
    };
  }
}
