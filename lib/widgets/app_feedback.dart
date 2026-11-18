import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_error.dart';
import '../theme/app_theme.dart';

enum _FeedbackKind { error, success, info }

/// Mensajes visibles en la parte superior de la pantalla.
///
/// Se usa para resultados de acciones (guardar, eliminar, aceptar una reserva).
/// Para errores dentro de formularios o diálogos usa [InlineAlert], que aparece
/// pegado al campo y no se pierde fuera de la vista.
class AppFeedback {
  static void error(BuildContext context, String message) =>
      _show(context, message, _FeedbackKind.error);

  static void success(BuildContext context, String message) =>
      _show(context, message, _FeedbackKind.success);

  static void info(BuildContext context, String message) =>
      _show(context, message, _FeedbackKind.info);

  /// Muestra el error ya traducido a un mensaje entendible.
  static void errorFrom(
    BuildContext context,
    Object cause, {
    String fallback = 'Ocurrió un problema inesperado. Inténtalo de nuevo.',
  }) {
    error(context, friendlyError(cause, fallback: fallback));
  }

  static void dismiss(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearMaterialBanners();
  }

  static void _show(
    BuildContext context,
    String message,
    _FeedbackKind kind,
  ) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (color, icon, title) = switch (kind) {
      _FeedbackKind.error => (
          const Color(0xFFDC2626),
          Icons.error_outline_rounded,
          'No se pudo completar',
        ),
      _FeedbackKind.success => (
          AppTheme.primaryColor,
          Icons.check_circle_outline_rounded,
          'Listo',
        ),
      _FeedbackKind.info => (
          const Color(0xFF2563EB),
          Icons.info_outline_rounded,
          'Información',
        ),
    };

    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: color.withValues(alpha: 0.10),
        elevation: 2,
        leading: Icon(icon, color: color, size: 26),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.clearMaterialBanners(),
            child: Text(
              'Cerrar',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    unawaited(
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!context.mounted) return;
        messenger.clearMaterialBanners();
      }),
    );
  }
}

/// Aviso dentro de un formulario, hoja o diálogo.
///
/// Aparece justo encima del botón de acción, por lo que el usuario siempre lo
/// ve sin tener que cerrar la ventana.
class InlineAlert extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  const InlineAlert({
    super.key,
    required this.message,
    this.isError = true,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFDC2626) : AppTheme.primaryColor;
    final background =
        isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA);
    final border =
        isError ? const Color(0xFFFECACA) : const Color(0xFF99F6E4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.35),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, color: color, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
