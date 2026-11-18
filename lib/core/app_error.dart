import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error con un mensaje ya redactado para mostrarse al usuario.
///
/// Se usa para lanzar validaciones de negocio desde los servicios sin
/// exponer detalles técnicos.
class AppMessageException implements Exception {
  final String message;
  const AppMessageException(this.message);

  @override
  String toString() => message;
}

/// Traduce cualquier excepción a un mensaje corto, claro y en español.
///
/// Nunca devuelve textos técnicos como `PostgrestException(...)`, nombres de
/// tablas, SQL ni códigos internos.
String friendlyError(
  Object error, {
  String fallback = 'Ocurrió un problema inesperado. Inténtalo de nuevo.',
}) {
  if (error is AppMessageException) return error.message;

  if (error is String) {
    final text = _clean(error);
    return text.isEmpty ? fallback : text;
  }

  if (error is AuthException) return _authMessage(error);

  if (error is PostgrestException) return _postgrestMessage(error, fallback);

  if (error is StorageException) return _storageMessage(error, fallback);

  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return 'No hay conexión a internet. Revisa tu red e inténtalo de nuevo.';
  }

  if (error is FormatException) {
    return 'Algunos datos tienen un formato inválido. Revísalos e inténtalo de nuevo.';
  }

  final text = _clean(error.toString());
  return text.isEmpty ? fallback : text;
}

String _authMessage(AuthException error) {
  final message = error.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (message.contains('already registered')) {
    return 'Este correo ya está registrado. Inicia sesión.';
  }
  if (message.contains('password should be')) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }
  if (message.contains('email not confirmed')) {
    return 'Confirma tu correo electrónico antes de iniciar sesión.';
  }
  if (message.contains('user not found')) {
    return 'No encontramos una cuenta con ese correo.';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Demasiados intentos. Espera un momento y vuelve a probar.';
  }
  return _clean(error.message);
}

String _postgrestMessage(PostgrestException error, String fallback) {
  final code = error.code ?? '';
  final message = error.message.toLowerCase();

  if (code == '23505' || message.contains('duplicate key')) {
    return 'Ya existe un registro con esos datos. Revisa la información.';
  }
  if (code == '23503') {
    return 'No se puede completar la acción porque el registro está relacionado con otros datos.';
  }
  if (code == '23514') {
    return 'Algunos datos no cumplen las reglas del sistema. Revísalos e inténtalo de nuevo.';
  }
  if (code == '42501' ||
      message.contains('row-level security') ||
      message.contains('permission denied')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (code == 'PGRST301' || message.contains('jwt expired')) {
    return 'Tu sesión expiró. Vuelve a iniciar sesión.';
  }
  if (code == 'PGRST116' || message.contains('0 rows')) {
    return 'No encontramos el registro que buscas. Actualiza la pantalla e inténtalo de nuevo.';
  }
  if (code == '42P01' || message.contains('does not exist')) {
    return 'La aplicación no está completamente configurada. Contacta al administrador.';
  }
  if (code == 'PGRST204' || message.contains('could not find')) {
    return 'La base de datos necesita una actualización. Contacta al administrador.';
  }
  if (message.contains('timeout') || message.contains('timed out')) {
    return 'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
  }

  final cleaned = _clean(error.message);
  return cleaned.isEmpty ? fallback : cleaned;
}

String _storageMessage(StorageException error, String fallback) {
  final status = error.statusCode ?? '';
  final message = error.message.toLowerCase();

  if (status == '403' || message.contains('permission')) {
    return 'No tienes permiso para subir este archivo.';
  }
  if (status == '404' || message.contains('bucket')) {
    return 'El almacenamiento de imágenes no está disponible. Contacta al administrador.';
  }
  if (status == '413' || message.contains('too large')) {
    return 'La imagen es demasiado grande. Elige una más pequeña.';
  }
  if (message.contains('mime') || message.contains('content type')) {
    return 'El formato de la imagen no es válido. Usa JPG o PNG.';
  }
  return fallback;
}

/// Limpia prefijos y textos técnicos que no aportan nada al usuario.
String _clean(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';

  text = text
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^Error:\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final technical = [
    'postgrestexception',
    'storageexception',
    'authexception',
    'sqlexception',
    'socketexception',
    'clientexception',
    'pgrst',
    'sqlstate',
    'row-level security',
    'stack trace',
    'at package:',
    'dart:',
    'null check operator',
    'type \'',
  ];

  final lower = text.toLowerCase();
  for (final marker in technical) {
    if (lower.contains(marker)) return '';
  }

  // Mensajes de error demasiado largos suelen ser volcados técnicos.
  if (text.length > 220) return '';
  return text;
}
