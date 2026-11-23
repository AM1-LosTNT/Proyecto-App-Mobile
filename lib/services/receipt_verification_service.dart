import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/app_error.dart';
import 'supabase_service.dart';

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

  /// Analiza un archivo de comprobante (Imagen o PDF) y extrae sus datos
  Future<ReceiptParseResult> analyzeReceiptFile({
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      final extension = file.path.split('.').last.toLowerCase();
      final isPdf = extension == 'pdf';

      String extractedText = '';

      if (isPdf) {
        extractedText = _extractTextFromPdf(bytes);
      } else {
        extractedText = await _extractTextFromImage(file.path);
      }

      if (extractedText.trim().isEmpty) {
        return ReceiptParseResult(
          success: false,
          fullText: '',
          sha256Hash: hash,
          fileType: isPdf ? 'pdf' : 'imagen',
          errorMessage:
              'No se pudo leer texto en el archivo. Asegúrate de que no sea una imagen borrosa.',
        );
      }

      // Parsear datos del comprobante bancario
      final bank = _detectBank(extractedText);
      final reference = _detectReferenceNumber(extractedText);
      final amount = _detectAmount(extractedText);
      final date = _detectDate(extractedText);

      return ReceiptParseResult(
        success: reference != null && amount != null,
        bankName: bank ?? 'Banco del Sistema Financiero',
        referenceNumber: reference,
        amount: amount,
        date: date,
        fullText: extractedText,
        sha256Hash: hash,
        fileType: isPdf ? 'pdf' : 'imagen',
        errorMessage: (reference == null || amount == null)
            ? 'No se identificó claramente el N° de Referencia u Operación o el Monto.'
            : null,
      );
    } catch (e) {
      return ReceiptParseResult(
        success: false,
        fullText: '',
        sha256Hash: '',
        fileType: 'desconocido',
        errorMessage: 'Error al procesar el archivo: $e',
      );
    }
  }

  /// Extrae texto nativo de un PDF usando Syncfusion PDF
  String _extractTextFromPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return text;
    } catch (_) {
      return '';
    } finally {
      document?.dispose();
    }
  }

  /// Extrae texto de una imagen usando Google ML Kit OCR
  Future<String> _extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      textRecognizer.close();
    }
  }

  /// Detecta el banco emisor a través de palabras clave
  String? _detectBank(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('UNION') || upper.contains('UNIÓN')) {
      return 'Banco Unión S.A.';
    }
    if (upper.contains('BCP') || upper.contains('BANCO DE CREDITO') || upper.contains('BANCO DE CRÉDITO')) {
      return 'Banco de Crédito BCP';
    }
    if (upper.contains('BNB') || upper.contains('NACIONAL DE BOLIVIA')) {
      return 'Banco Nacional de Bolivia (BNB)';
    }
    if (upper.contains('MERCANTIL') || upper.contains('BMSC')) {
      return 'Banco Mercantil Santa Cruz';
    }
    if (upper.contains('FIE')) {
      return 'Banco FIE';
    }
    if (upper.contains('BANCO SOL') || upper.contains('BANCOSOL')) {
      return 'BancoSol';
    }
    if (upper.contains('GANADERO')) {
      return 'Banco Ganadero';
    }
    if (upper.contains('BISA')) {
      return 'Banco BISA';
    }
    if (upper.contains('ECONOMICO') || upper.contains('ECONÓMICO')) {
      return 'Banco Económico';
    }
    if (upper.contains('PRODEM')) {
      return 'Banco Prodem';
    }
    if (upper.contains('COMUNIDAD')) {
      return 'Banco Comunidad';
    }
    return null;
  }

  /// Detecta el número de operación, transacción o referencia
  String? _detectReferenceNumber(String text) {
    final patterns = [
      RegExp(
        r'(?:N[°oº\.]?\s*(?:de\s*)?(?:Operaci[óo]n|Transacci[óo]n|Referencia|Comprobante|Control|Autorizaci[óo]n)|Ref(?:erencia)?\.?|N[úu]mero\s*de\s*Control)\s*[:#-]?\s*([A-Za-z0-9\-]{5,30})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Cod\.?\s*(?:de\s*)?Referencia|Movimiento\s*N[°oº]?)\s*[:#-]?\s*([A-Za-z0-9\-]{5,30})',
        caseSensitive: false,
      ),
      RegExp(r'(?:TRANSAC|ORDEN|TRX)[\s:]*([0-9]{6,16})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final ref = match.group(1)?.trim();
        if (ref != null && ref.isNotEmpty && ref.length >= 4) {
          return ref;
        }
      }
    }

    final genericDigitMatch = RegExp(r'\b\d{7,14}\b').firstMatch(text);
    if (genericDigitMatch != null) {
      return genericDigitMatch.group(0);
    }

    return null;
  }

  /// Detecta el monto pagado (Bs. o BOB o cantidad decimal)
  double? _detectAmount(String text) {
    final patterns = [
      RegExp(
        r'(?:Bs\.?|BOB|BS|Bs|Total|Monto|Importe|Monto\s*Transferido)\s*[:\$]?\s*([0-9]{1,4}(?:[,\.][0-9]{3})*(?:[,\.][0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(r'([0-9]+(?:[\.,][0-9]{1,2}))\s*(?:Bs|BOB)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final raw = match.group(1);
        if (raw != null) {
          final clean = raw.replaceAll(',', '.');
          final val = double.tryParse(clean);
          if (val != null && val > 0) {
            return val;
          }
        }
      }
    }

    return null;
  }

  /// Detecta fecha en formato dd/mm/aaaa
  String? _detectDate(String text) {
    final datePattern = RegExp(
      r'([0-3]?[0-9][/\-\.][0-1]?[0-9][/\-\.][1-2][0-9]{3})',
    );
    final match = datePattern.firstMatch(text);
    return match?.group(1);
  }

  /// Verifica y registra el pago en Supabase con todas las reglas anti-fraude
  Future<void> submitAndVerifyPayment({
    String? orderId,
    String? reservaId,
    required double orderTotal,
    required File file,
    required ReceiptParseResult parseResult,
    required String manualReferenceIfAny,
    required double manualAmountIfAny,
    required String manualBankIfAny,
  }) async {
    final supabase = SupabaseService();
    final user = supabase.currentUser;
    if (user == null) {
      throw const AppMessageException('Debes iniciar sesión para verificar el pago.');
    }

    if (orderId == null && reservaId == null) {
      throw const AppMessageException('No se especificó la orden o reserva a pagar.');
    }

    final finalReference = (parseResult.referenceNumber != null &&
            parseResult.referenceNumber!.isNotEmpty)
        ? parseResult.referenceNumber!
        : manualReferenceIfAny.trim();

    final finalAmount = parseResult.amount ?? manualAmountIfAny;
    final finalBank = parseResult.bankName ?? manualBankIfAny;

    if (finalReference.isEmpty) {
      throw const AppMessageException(
          'Es obligatorio contar con el Número de Referencia u Operación bancaria.');
    }

    if (finalAmount < orderTotal) {
      throw AppMessageException(
          'El monto validado (Bs. ${finalAmount.toStringAsFixed(2)}) es menor al total requerido (Bs. ${orderTotal.toStringAsFixed(2)}).');
    }

    // 1. Blindaje Anti-Fraude: Comprobar si el archivo hash SHA-256 ya fue usado
    final existingHash = await supabase.client
        .from('pagos_historial')
        .select('id')
        .eq('archivo_hash_sha256', parseResult.sha256Hash)
        .maybeSingle();

    if (existingHash != null) {
      throw const AppMessageException(
          '¡ALERTA DE SEGURIDAD! Este archivo de comprobante ya ha sido registrado previamente en el sistema. No se permite reutilizar comprobantes.');
    }

    // 2. Blindaje Anti-Fraude: Comprobar si el Número de Referencia Bancaria ya existe
    final existingRef = await supabase.client
        .from('pagos_historial')
        .select('id')
        .eq('numero_referencia_banco', finalReference)
        .maybeSingle();

    if (existingRef != null) {
      throw AppMessageException(
          '¡ALERTA DE SEGURIDAD! El número de operación bancaria ($finalReference) ya fue utilizado en otra transacción. No se admiten pagos duplicados.');
    }

    // 3. Subir el comprobante a Supabase Storage
    final extension = file.path.split('.').last.toLowerCase();
    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final filePath = 'comprobantes/$fileName';

    final bytes = await file.readAsBytes();
    await supabase.client.storage.from('comprobantes-pago').uploadBinary(
          filePath,
          bytes,
        );

    final publicUrl = supabase.client.storage
        .from('comprobantes-pago')
        .getPublicUrl(filePath);

    // 4. Insertar en la tabla de pagos_historial
    // NOTA: El trigger de la BD automáticamente actualizará el pedido o reserva
    await supabase.client.from('pagos_historial').insert({
      if (orderId != null) 'id_pedido': orderId,
      if (reservaId != null) 'id_reserva': reservaId,
      'id_usuario': user.id,
      'banco_origen': finalBank,
      'numero_referencia_banco': finalReference,
      'monto_validado': finalAmount,
      'fecha_transferencia': parseResult.date ?? DateTime.now().toIso8601String(),
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
