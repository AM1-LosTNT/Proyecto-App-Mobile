import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_error.dart';
import '../../models/order_model.dart';
import '../../services/receipt_verification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/payment_details.dart';

class PaymentProofScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentProofScreen({super.key, required this.order});

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  final _picker = ImagePicker();
  final _bank = TextEditingController();
  final _reference = TextEditingController();
  final _amount = TextEditingController();

  Uint8List? _bytes;
  String? _fileName;
  ReceiptParseResult? _parseResult;

  bool _analyzing = false;
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.order.total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _bank.dispose();
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_analyzing) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) setState(() => _analyzing = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final result = await ReceiptVerificationService().analyzeReceiptBytes(
        bytes: bytes,
        fileName: picked.name,
      );

      if (!mounted) return;
      setState(() {
        _analyzing = false;
        if (result.success) {
          _bytes = bytes;
          _fileName = picked.name;
          _parseResult = result;
          _error = null;
        } else {
          _bytes = null;
          _fileName = null;
          _parseResult = null;
          _error = result.errorMessage;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = friendlyError(
          e,
          fallback:
              'No pudimos leer el archivo. Elige otra imagen e inténtalo de nuevo.',
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_bytes == null || _parseResult == null) {
      setState(() => _error = 'Primero selecciona la imagen de tu comprobante.');
      return;
    }
    if (_reference.text.trim().isEmpty) {
      setState(
        () => _error =
            'Ingresa el número de referencia u operación que aparece en el comprobante.',
      );
      return;
    }

    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto transferido válido.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ReceiptVerificationService().submitAndVerifyPayment(
        orderId: widget.order.id,
        orderTotal: widget.order.total,
        bytes: _bytes!,
        fileName: _fileName ?? 'comprobante.jpg',
        parseResult: _parseResult!,
        manualReferenceIfAny: _reference.text,
        manualAmountIfAny: amount,
        manualBankIfAny: _bank.text,
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(
          e,
          fallback:
              'No pudimos validar el pago. Revisa los datos e inténtalo de nuevo.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Comprobante de pago')),
      body: _done
          ? _SuccessView(onDone: () => Navigator.pop(context, true))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaymentDetails(
                    total: widget.order.total,
                    reference: widget.order.codigoReferencia,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Sube tu comprobante',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecciona una captura o foto del comprobante de '
                    'transferencia. Validaremos que el monto y la referencia '
                    'no hayan sido usados antes.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _analyzing ? null : _pick,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          if (_analyzing)
                            const CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            )
                          else
                            Icon(
                              _bytes == null
                                  ? Icons.upload_file_rounded
                                  : Icons.check_circle_rounded,
                              size: 34,
                              color: AppTheme.primaryColor,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _bytes == null
                                ? 'Seleccionar comprobante'
                                : (_fileName ?? 'Comprobante seleccionado'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_bytes != null)
                            const Text(
                              'Toca para reemplazarlo',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bank,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Banco de origen',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reference,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'N° de referencia u operación',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto transferido (Bs.)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InlineAlert(
                      message: _error!,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        _submitting ? 'Validando...' : 'Verificar pago',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 88,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Pago verificado!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu comprobante quedó registrado y el pedido cambió a estado '
              'Pagado. Podrás seguir su entrega desde "Mis pedidos".',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDone,
              child: const Text('Volver a mis pedidos'),
            ),
          ],
        ),
      ),
    );
  }
}
