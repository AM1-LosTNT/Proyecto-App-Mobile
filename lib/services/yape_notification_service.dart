import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pago_qr_model.dart';
import 'yape_listener_bridge.dart';

/// Servicio de cobros por QR estático (Bs 0).
///
/// - El cobro vive en `pagos_qr` y expira en 10 minutos.
/// - `configuracion_cobros.escucha_activa` la mantiene un trigger de PostgreSQL:
///   se enciende solo cuando hay un cobro PENDIENTE vigente.
/// - En Android, el `NotificationListenerService` nativo lee las notificaciones
///   de Yape/Banca y consulta el estado del cobro antes de hacer cualquier cosa,
///   así no se gasta batería ni se generan falsos positivos.
class YapeNotificationService extends ChangeNotifier {
  static final YapeNotificationService _instance =
      YapeNotificationService._internal();
  factory YapeNotificationService() => _instance;
  YapeNotificationService._internal();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _configChannel;
  RealtimeChannel? _pagosChannel;

  bool _escuchaActiva = false;
  bool get escuchaActiva => _escuchaActiva;

  String? _qrEstaticoUrl;
  String? get qrEstaticoUrl => _qrEstaticoUrl;

  bool _nativeAccessGranted = false;
  bool get nativeAccessGranted => _nativeAccessGranted;

  bool _nativeEnabled = false;
  bool get nativeEnabled => _nativeEnabled;

  bool _initialized = false;

  /// Inicializa Realtime y carga la configuración actual.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await refreshNativeState();
    await _cargarEstadoInicial();
    _suscribirConfiguracionRealtime();
    _suscribirPagosRealtime();
  }

  /// Sincroniza la sesión de Supabase y el rol admin con el servicio nativo.
  /// Se llama desde `AppState` al iniciar sesión / cerrar sesión.
  Future<void> syncNativeSession({required bool isAdmin}) async {
    if (!YapeListenerBridge.isSupported) return;

    final session = _supabase.auth.currentSession;
    if (session == null) {
      _nativeEnabled = false;
      await YapeListenerBridge.setEnabled(false);
      notifyListeners();
      return;
    }

    _nativeAccessGranted = await YapeListenerBridge.hasAccess();
    // Si el usuario no es admin, apagamos el listener en su teléfono.
    _nativeEnabled = isAdmin && _nativeAccessGranted;

    await YapeListenerBridge.configure(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      userId: session.user.id,
      isAdmin: isAdmin,
      enabled: _nativeEnabled,
    );
    notifyListeners();
  }

  /// Revisa si el permiso de acceso a notificaciones está concedido.
  Future<void> refreshNativeState() async {
    if (!YapeListenerBridge.isSupported) return;
    _nativeAccessGranted = await YapeListenerBridge.hasAccess();
    if (!_nativeAccessGranted) _nativeEnabled = false;
    notifyListeners();
  }

  /// Abre los ajustes de Android para conceder "Acceso a notificaciones".
  Future<void> abrirAjustesNotificaciones() async {
    await YapeListenerBridge.openSettings();
  }

  /// Vuelve a leer el permiso y sincroniza la sesión (llamar al volver de ajustes).
  Future<void> reactivarEscuchaNativa({required bool isAdmin}) async {
    await refreshNativeState();
    await syncNativeSession(isAdmin: isAdmin);
  }

  /// Vuelve a leer `configuracion_cobros` (estado de escucha y URL del QR).
  Future<void> cargarConfiguracion() => _cargarEstadoInicial();

  Future<void> _cargarEstadoInicial() async {
    try {
      final data = await _supabase
          .from('configuracion_cobros')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (data != null) {
        _escuchaActiva = data['escucha_activa'] == true;
        _qrEstaticoUrl = data['qr_estatico_url']?.toString();
        notifyListeners();
      }
    } catch (_) {}
  }

  void _suscribirConfiguracionRealtime() {
    _configChannel = _supabase
        .channel('public:configuracion_cobros')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'configuracion_cobros',
          callback: (payload) {
            final nuevo = payload.newRecord;
            if (nuevo['id'] == 1) {
              _escuchaActiva = nuevo['escucha_activa'] == true;
              _qrEstaticoUrl = nuevo['qr_estatico_url']?.toString();
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void _suscribirPagosRealtime() {
    _pagosChannel = _supabase
        .channel('public:pagos_qr')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pagos_qr',
          callback: (payload) {
            notifyListeners();
          },
        )
        .subscribe();
  }

  /// Extrae el monto de textos como:
  /// "¡Te yapearon Bs 25.00!", "Transferencia recibida por Bs. 50".
  double? extraerMonto(String texto) {
    final conMoneda = RegExp(
      r'(?:bs\.?|bob|s/)\s*([0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final respaldo = RegExp(r'([0-9]+[.,][0-9]{2})');
    final match = conMoneda.firstMatch(texto) ?? respaldo.firstMatch(texto);
    if (match != null) {
      final raw = match.group(1)?.replaceAll(',', '.');
      if (raw != null) {
        final val = double.tryParse(raw);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  /// Procesa una notificación (usado por el diagnóstico del panel admin).
  /// El camino real en Android lo hace el servicio nativo.
  ///
  /// Si el monto coincide con un cobro pendiente, el cobro pasa directo a
  /// `PAGADO`: la notificación es la confirmación del pago.
  Future<bool> procesarNotificacion({
    required String titulo,
    required String texto,
    String? paqueteOrigen,
  }) async {
    if (!_escuchaActiva) {
      debugPrint('Notificación ignorada: no hay cobros pendientes activos.');
      return false;
    }

    final monto = extraerMonto(texto) ?? extraerMonto(titulo);
    if (monto == null || monto <= 0) return false;

    final eventoHash = sha256
        .convert(utf8.encode('${paqueteOrigen ?? ''}|$titulo|$texto|$monto'))
        .toString();

    try {
      final res = await _supabase.rpc('validar_pago_por_notificacion', params: {
        'p_monto': monto,
        'p_titulo': titulo,
        'p_texto': texto,
        'p_hash': eventoHash,
      });

      notifyListeners();
      return res != null;
    } catch (e) {
      debugPrint('No se pudo validar cobro con notificación: $e');
      return false;
    }
  }

  /// Respaldo manual: el admin marca un cobro como pagado de un solo toque,
  /// sin escribir saldos. Solo se usa si la notificación no llegó.
  Future<void> confirmarPagoManual(String pagoId) async {
    await _supabase.rpc('confirmar_pago_qr', params: {
      'p_pago_id': pagoId,
    });
    notifyListeners();
  }

  /// Crea un cobro en `pagos_qr` mediante RPC. El servidor cancela intentos
  /// pendientes anteriores del mismo pedido, genera la referencia y el trigger
  /// enciende `escucha_activa` automáticamente.
  Future<PagoQrModel> crearCobroQr({
    required double monto,
    String? idPedido,
    String? idReserva,
    String? glosa,
  }) async {
    final res = await _supabase.rpc('crear_cobro_qr', params: {
      'p_monto': monto,
      'p_id_pedido': idPedido,
      'p_id_reserva': idReserva,
      'p_glosa': glosa ?? 'Pago en TurisApp',
    });

    final map = res is List ? (res.first as Map) : (res as Map);
    return PagoQrModel.fromMap(map.cast<String, dynamic>());
  }

  /// Guarda la URL pública del QR estático de Bs 0 (solo admin por RLS).
  Future<void> actualizarQrEstatico(String url) async {
    await _supabase.from('configuracion_cobros').update({
      'qr_estatico_url': url,
      'actualizado_en': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', 1);

    _qrEstaticoUrl = url;
    notifyListeners();
  }

  @override
  void dispose() {
    _configChannel?.unsubscribe();
    _pagosChannel?.unsubscribe();
    super.dispose();
  }
}
