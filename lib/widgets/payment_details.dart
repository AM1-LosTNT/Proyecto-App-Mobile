import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/payment_config.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';

/// Muestra los datos bancarios para pagar un pedido por QR Simple.
///
/// Se usa tanto en la confirmación del pedido como en la pantalla de
/// comprobante, para que el usuario siempre tenga a mano la referencia y el
/// monto exacto.
class PaymentDetails extends StatelessWidget {
  final double total;
  final String reference;

  const PaymentDetails({
    super.key,
    required this.total,
    required this.reference,
  });

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    AppFeedback.info(context, '$label copiado al portapapeles.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Datos para el pago',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (PaymentConfig.qrImageUrl.isNotEmpty)
            Center(
              child: Image.network(
                PaymentConfig.qrImageUrl,
                height: 180,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          else if (PaymentConfig.qrAssetPath.isNotEmpty)
            Center(
              child: Image.asset(
                PaymentConfig.qrAssetPath,
                height: 180,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          _row(context, 'Monto', 'Bs. ${total.toStringAsFixed(2)}'),
          _row(context, 'Titular', PaymentConfig.titular),
          _row(context, 'Banco', PaymentConfig.banco),
          _row(context, 'Cuenta', PaymentConfig.tipoCuenta),
          _row(
            context,
            'Número',
            PaymentConfig.numeroCuenta,
            copyValue: PaymentConfig.numeroCuenta,
          ),
          _row(
            context,
            'Referencia',
            reference,
            copyValue: reference,
          ),
          const SizedBox(height: 8),
          const Text(
            'Realiza la transferencia o el QR Simple y luego sube tu comprobante '
            'desde "Mis pedidos" para validar el pago.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    String? copyValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (copyValue != null && copyValue.isNotEmpty)
            GestureDetector(
              onTap: () => _copy(context, copyValue, label),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
