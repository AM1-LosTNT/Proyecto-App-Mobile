class OrderItemModel {
  final int id;
  final String idPedido;
  final String idProducto;
  final String nombreProducto;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  OrderItemModel({
    required this.id,
    required this.idPedido,
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      idPedido: map['id_pedido']?.toString() ?? '',
      idProducto: map['id_producto']?.toString() ?? '',
      nombreProducto: map['nombre_producto'] ?? '',
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final String id;
  final String idTurista;
  final double total;
  final String estado;
  final String metodoPago;
  final String codigoReferencia;
  final String? direccionEntrega;
  final String? telefonoContacto;
  final String? notas;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.idTurista,
    required this.total,
    required this.estado,
    required this.metodoPago,
    required this.codigoReferencia,
    this.direccionEntrega,
    this.telefonoContacto,
    this.notas,
    required this.createdAt,
    this.items = const [],
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, [List<OrderItemModel>? items]) {
    return OrderModel(
      id: map['id']?.toString() ?? '',
      idTurista: map['id_turista']?.toString() ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      estado: map['estado'] ?? 'Pendiente',
      metodoPago: map['metodo_pago'] ?? 'QR_SIMPLE',
      codigoReferencia: map['codigo_referencia'] ?? '',
      direccionEntrega: map['direccion_entrega'],
      telefonoContacto: map['telefono_contacto'],
      notas: map['notas'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: items ?? [],
    );
  }
}

class PaymentRecordModel {
  final String id;
  final String idPedido;
  final String idUsuario;
  final String? bancoOrigen;
  final String numeroReferenciaBanco;
  final double montoValidado;
  final String? fechaTransferencia;
  final String comprobanteUrl;
  final String tipoArchivo;
  final String archivoHashSha256;
  final String estado;
  final Map<String, dynamic>? metadatosExtraccion;
  final DateTime createdAt;

  PaymentRecordModel({
    required this.id,
    required this.idPedido,
    required this.idUsuario,
    this.bancoOrigen,
    required this.numeroReferenciaBanco,
    required this.montoValidado,
    this.fechaTransferencia,
    required this.comprobanteUrl,
    required this.tipoArchivo,
    required this.archivoHashSha256,
    required this.estado,
    this.metadatosExtraccion,
    required this.createdAt,
  });

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map) {
    return PaymentRecordModel(
      id: map['id']?.toString() ?? '',
      idPedido: map['id_pedido']?.toString() ?? '',
      idUsuario: map['id_usuario']?.toString() ?? '',
      bancoOrigen: map['banco_origen'],
      numeroReferenciaBanco: map['numero_referencia_banco'] ?? '',
      montoValidado: (map['monto_validado'] as num?)?.toDouble() ?? 0.0,
      fechaTransferencia: map['fecha_transferencia'],
      comprobanteUrl: map['comprobante_url'] ?? '',
      tipoArchivo: map['tipo_archivo'] ?? 'imagen',
      archivoHashSha256: map['archivo_hash_sha256'] ?? '',
      estado: map['estado'] ?? 'Verificado',
      metadatosExtraccion: map['metadatos_extraccion'] != null
          ? Map<String, dynamic>.from(map['metadatos_extraccion'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

