import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/app_error.dart';
import 'supabase_service.dart';

/// Resultado del análisis de un comprobante de pago.
///
/// El archivo se identifica por su hash SHA-256 y su tipo. Los datos bancarios
/// (referencia, monto y banco) los confirma el usuario en pantalla, de modo que
/// la app no depende de librerías de OCR pesadas y funciona en todas las
/// plataformas (Android, iOS, Windows, macOS, Linux y Web).
class ReceiptParseResult {
  final bool success;
  final String? bankName;
  final String? referenceNumber;
  final double? amount;
  final String? date;
  final String fullText;
  final String sha256Hash;
  final String fileType; // 'imagen' | 'pdf'
  final String? errorMessage;

  ReceiptParseResult({
    required this.success,
    this.bankName,
    this.referenceNumber,
    this.amount,
    this.date,
    required this.fullText,
    required this.sha256Hash,
    required this.fileType,
    this.errorMessage,
  });
}

class ReceiptVerificationService {
  static final ReceiptVerificationService _instance =
      ReceiptVerificationService._internal();
  factory ReceiptVerificationService() => _instance;
  ReceiptVerificationService._internal();

  /// Calcula el hash SHA-256 del archivo y valida que tenga contenido.
  ///
  /// El hash es la pieza clave del blindaje anti-fraude: impide que el mismo
  /// comprobante se reutilice en dos compras distintas.
  Future<ReceiptParseResult> analyzeReceiptBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final hash = sha256.convert(bytes).toString();
    final extension = fileName.split('.').last.toLowerCase();
    final isPdf = extension == 'pdf';

    if (bytes.isEmpty) {
      return ReceiptParseResult(
        success: false,
        fullText: '',
        sha256Hash: hash,
        fileType: isPdf ? 'pdf' : 'imagen',
        errorMessage: 'El archivo está vacío. Elige otro comprobante.',
      );
    }

    return ReceiptParseResult(
      success: true,
      fullText: '',
      sha256Hash: hash,
      fileType: isPdf ? 'pdf' : 'imagen',
    );
  }

  /// Verifica y registra el pago en Supabase con las reglas anti-fraude.
  ///
  /// - No permite reutilizar el mismo archivo (hash SHA-256 duplicado).
  /// - No permite reutilizar el mismo número de referencia bancaria.
  /// - Exige que el monto validado cubra el total del pedido o reserva.
  Future<void> submitAndVerifyPayment({
    String? orderId,
    String? reservaId,
    required double orderTotal,
    required Uint8List bytes,
    required String fileName,
    required ReceiptParseResult parseResult,
    required String manualReferenceIfAny,
    required double manualAmountIfAny,
    required String manualBankIfAny,
  }) async {
    final supabase = SupabaseService();
    final user = supabase.currentUser;
    if (user == null) {
      throw const AppMessageException(
        'Debes iniciar sesión para verificar el pago.',
      );
    }

    if (orderId == null && reservaId == null) {
      throw const AppMessageException(
        'No se especificó la orden o reserva a pagar.',
      );
    }

    final finalReference = (parseResult.referenceNumber != null &&
            parseResult.referenceNumber!.isNotEmpty)
        ? parseResult.referenceNumber!
        : manualReferenceIfAny.trim();

    final finalAmount = parseResult.amount ?? manualAmountIfAny;
    final finalBank = parseResult.bankName ?? manualBankIfAny.trim();

    if (finalReference.isEmpty) {
      throw const AppMessageException(
        'Es obligatorio contar con el Número de Referencia u Operación bancaria.',
      );
    }

    if (finalAmount <= 0) {
      throw const AppMessageException(
        'Ingresa el monto que transferiste para poder validar el pago.',
      );
    }

    if (finalAmount < orderTotal) {
      throw AppMessageException(
        'El monto validado (Bs. ${finalAmount.toStringAsFixed(2)}) es menor al '
        'total requerido (Bs. ${orderTotal.toStringAsFixed(2)}).',
      );
    }

    // 1. Blindaje Anti-Fraude: comprobar si el archivo ya fue usado.
    final existingHash = await supabase.client
        .from('pagos_historial')
        .select('id')
        .eq('archivo_hash_sha256', parseResult.sha256Hash)
        .maybeSingle();

    if (existingHash != null) {
      throw const AppMessageException(
        '¡ALERTA DE SEGURIDAD! Este archivo de comprobante ya ha sido '
        'registrado previamente en el sistema. No se permite reutilizar '
        'comprobantes.',
      );
    }

    // 2. Blindaje Anti-Fraude: comprobar si la referencia bancaria ya existe.
    final existingRef = await supabase.client
        .from('pagos_historial')
        .select('id')
        .eq('numero_referencia_banco', finalReference)
        .maybeSingle();

    if (existingRef != null) {
      throw AppMessageException(
        '¡ALERTA DE SEGURIDAD! El número de operación bancaria '
        '($finalReference) ya fue utilizado en otra transacción. No se admiten '
        'pagos duplicados.',
      );
    }

    // 3. Subir el comprobante a Supabase Storage.
    final rawExtension = fileName.split('.').last.toLowerCase();
    final extension =
        rawExtension.isEmpty || rawExtension.length > 5 ? 'jpg' : rawExtension;
    final storedName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final filePath = 'comprobantes/$storedName';

    await supabase.client.storage.from('comprobantes-pago').uploadBinary(
          filePath,
          bytes,
        );

    final publicUrl = supabase.client.storage
        .from('comprobantes-pago')
        .getPublicUrl(filePath);

    // 4. Registrar el pago. El trigger de la base de datos actualiza el pedido
    //    o la reserva automáticamente cuando el estado es "Verificado".
    await supabase.client.from('pagos_historial').insert({
      if (orderId != null) 'id_pedido': orderId,
      if (reservaId != null) 'id_reserva': reservaId,
      'id_usuario': user.id,
      'banco_origen': finalBank.isEmpty ? null : finalBank,
      'numero_referencia_banco': finalReference,
      'monto_validado': finalAmount,
      'fecha_transferencia':
          parseResult.date ?? DateTime.now().toIso8601String(),
      'comprobante_url': publicUrl,
      'tipo_archivo': parseResult.fileType,
      'archivo_hash_sha256': parseResult.sha256Hash,
      'estado': 'Verificado',
      'metadatos_extraccion': {
        'banco_detectado': parseResult.bankName,
        'referencia_detectada': parseResult.referenceNumber,
        'monto_detectado': parseResult.amount,
        'tipo': reservaId != null ? 'reserva' : 'pedido',
        'texto_ocr_preview': parseResult.fullText.length > 500
            ? parseResult.fullText.substring(0, 500)
            : parseResult.fullText,
      },
    });
  }
}
