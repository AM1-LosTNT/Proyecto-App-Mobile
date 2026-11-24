import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/supabase_config.dart';

/// Puente con el `NotificationListenerService` nativo de Android.
///
/// El servicio nativo es el encargado de leer las notificaciones de Yape/Banca
/// y de hablar con Supabase, por lo que sigue funcionando aunque la app esté
/// cerrada o en segundo plano.
///
/// En iOS / Web / escritorio todas las llamadas son "no-op" seguras.
class YapeListenerBridge {
  YapeListenerBridge._();

  static const MethodChannel _channel =
      MethodChannel('turisapp/yape_listener');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// ¿El usuario ya dio permiso de "Acceso a notificaciones" en Android?
  static Future<bool> hasAccess() async {
    if (!isSupported) return false;
    try {
      final value = await _channel.invokeMethod<bool>('hasAccess');
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre la pantalla de Ajustes → Acceso a notificaciones.
  static Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openSettings');
    } on PlatformException {
      // Ignorado: el dispositivo no tiene esa pantalla.
    } on MissingPluginException {
      // Ignorado: build sin código nativo (por ejemplo Flutter web).
    }
  }

  /// Guarda en el teléfono la sesión de Supabase y si el usuario es admin.
  /// El servicio nativo usa estos datos para validar notificaciones.
  static Future<void> configure({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required bool isAdmin,
    required bool enabled,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('configure', {
        'url': SupabaseConfig.url,
        'anonKey': SupabaseConfig.anonKey,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'isAdmin': isAdmin,
        'enabled': enabled,
      });
    } on PlatformException {
      // Sin código nativo disponible: no pasa nada.
    } on MissingPluginException {
      // Sin código nativo disponible: no pasa nada.
    }
  }

  /// Enciende o apaga el procesamiento de notificaciones en el teléfono.
  static Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } on PlatformException {
      // Ignorado.
    } on MissingPluginException {
      // Ignorado.
    }
  }
}
