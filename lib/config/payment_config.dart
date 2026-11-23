/// ==============================================================================
/// CONFIGURACIÓN CENTRAL DE COBROS Y QR BANCARIO
/// ==============================================================================
/// Aquí puedes colocar los datos de tu propia cuenta bancaria personal para
/// recibir los pagos por QR de la tienda de souvenirs y de las reservas turísticas.
class PaymentConfig {
  /// 1. Nombre completo del titular de la cuenta bancaria (como figura en tu banco)
  static const String titular = 'Christopher (Cuenta TurisApp)';

  /// 2. Nombre del Banco (Ej: Banco Unión, BCP, BNB, Banco Sol, Banco FIE, etc.)
  static const String banco = 'Banco Unión S.A.';

  /// 3. Tipo y número de cuenta bancaria
  static const String tipoCuenta = 'Caja de Ahorros en Bs.';
  static const String numeroCuenta = '10000049281729';

  /// 4. ¿DÓNDE PONER TU IMAGEN DE QR?
  ///
  /// Opción A (Recomendada - URL directa o Supabase Storage):
  /// Sube la imagen del QR de tu banco a Supabase Storage (en el bucket que creamos
  /// o en cualquier servicio de imágenes) y pega aquí la URL.
  /// Ejemplo: 'https://mi-storage.supabase.co/storage/v1/object/public/comprobantes-pago/mi_qr_personal.png'
  static const String qrImageUrl = '';

  /// Opción B (Archivo Local en Assets):
  /// Guarda la captura de tu QR en tu carpeta del proyecto (ej: 'assets/images/mi_qr.png')
  /// y pon aquí la ruta. Recuerda descomentar los assets en pubspec.yaml.
  static const String qrAssetPath = '';

  /// Si dejas ambas opciones vacías (''), la app generará automáticamente un código
  /// QR dinámico con tu número de cuenta y el código de referencia único de la transacción.
}

