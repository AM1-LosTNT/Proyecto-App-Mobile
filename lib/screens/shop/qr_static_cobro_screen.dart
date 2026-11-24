import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/payment_config.dart';
import '../../models/pago_qr_model.dart';
import '../../services/yape_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pago_exitoso_view.dart';
import 'order_history_screen.dart';

class QrStaticCobroScreen extends StatefulWidget {
  final double monto;
  final String? idPedido;
  final String? idReserva;
  final String? glosa;

  const QrStaticCobroScreen({
    super.key,
    required this.monto,
    this.idPedido,
    this.idReserva,
    this.glosa,
  });

  @override
  State<QrStaticCobroScreen> createState() => _QrStaticCobroScreenState();
}

class _QrStaticCobroScreenState extends State<QrStaticCobroScreen> {
  final _service = YapeNotificationService();
  PagoQrModel? _pago;
  RealtimeChannel? _subscription;

  bool _loading = true;
  String? _error;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _celebrado = false;
  Duration _timeLeft = const Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _iniciarCobro();
  }

  Future<void> _iniciarCobro() async {
    setState(() {
      _loading = true;
      _error = null;
      _celebrado = false;
    });
    try {
      // Necesario para conocer el QR estático configurado por el admin.
      await _service.cargarConfiguracion();

      final pago = await _service.crearCobroQr(
        monto: widget.monto,
        idPedido: widget.idPedido,
        idReserva: widget.idReserva,
        glosa: widget.glosa,
      );

      if (!mounted) return;
      setState(() {
        _pago = pago;
        _loading = false;
        _calcularTiempoRestante(pago.expiraEn);
      });

      _iniciarTimer();
      _suscribirRealtime(pago.id);
      _iniciarPolling(pago.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo iniciar el cobro: $e';
      });
    }
  }

  /// Aplica un estado nuevo del cobro. Si pasa a PAGADO, lanza la celebración.
  void _aplicarPago(PagoQrModel nuevo) {
    if (!mounted) return;
    final anterior = _pago;
    if (anterior != null &&
        anterior.estado == nuevo.estado &&
        anterior.montoRecibido == nuevo.montoRecibido) {
      return;
    }

    setState(() => _pago = nuevo);

    if (nuevo.isPagado) {
      _countdownTimer?.cancel();
      _pollTimer?.cancel();
      _celebrar();
    }
  }

  void _celebrar() {
    if (_celebrado) return;
    _celebrado = true;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _calcularTiempoRestante(DateTime expira) {
    final diff = expira.difference(DateTime.now());
    _timeLeft = diff.isNegative ? Duration.zero : diff;
  }

  void _iniciarTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pago != null) {
        final diff = _pago!.expiraEn.difference(DateTime.now());
        if (diff.isNegative) {
          timer.cancel();
          setState(() => _timeLeft = Duration.zero);
        } else {
          setState(() => _timeLeft = diff);
        }
      }
    });
  }

  void _suscribirRealtime(String pagoId) {
    _subscription = Supabase.instance.client
        .channel('public:pagos_qr:$pagoId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pagos_qr',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: pagoId,
          ),
          callback: (payload) {
            final nuevo = payload.newRecord;
            if (nuevo.isNotEmpty) {
              _aplicarPago(PagoQrModel.fromMap(nuevo));
            }
          },
        )
        .subscribe();
  }

  /// Respaldo por si Realtime se cae (red móvil, app en segundo plano).
  /// Cada 3 segundos consulta el estado del cobro sin que el cliente haga nada.
  void _iniciarPolling(String pagoId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final actual = _pago;
      if (actual == null) return;
      if (actual.isPagado || actual.isExpirado || actual.isRechazado) {
        timer.cancel();
        return;
      }

      try {
        final data = await Supabase.instance.client
            .from('pagos_qr')
            .select()
            .eq('id', pagoId)
            .maybeSingle();

        if (data == null) return;
        _aplicarPago(PagoQrModel.fromMap(data));
      } catch (_) {
        // Sin conexión: se reintenta en el siguiente ciclo.
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _copiarTexto(String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagoActual = _pago;

    // Pago completado: pantalla animada, sin refrescar nada.
    if (pagoActual != null && pagoActual.isPagado) {
      return PagoExitosoView(
        monto: pagoActual.montoAcreditado,
        referencia: pagoActual.referenciaInterna,
        remitente: pagoActual.pagadoPor,
        pagadoEn: pagoActual.pagadoEn,
        automatico: pagoActual.isPagadoAutomatico,
        onVerPedidos: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
          );
        },
        onVolver: () => Navigator.of(context).maybePop(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Pago con QR (Bs 0)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 54, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _iniciarCobro,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final pago = _pago!;
    final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // Banner de estado
          _buildStatusBanner(pago),

          const SizedBox(height: 16),

          // Tarjeta de Cobro y QR
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monto a transferir:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      onTap: () => _copiarTexto(
                        widget.monto.toStringAsFixed(2),
                        'Monto copiado al portapapeles',
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bs. ${widget.monto.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 14, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Referencia / Glosa:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    InkWell(
                      onTap: () => _copiarTexto(
                        pago.referenciaInterna,
                        'Referencia copiada',
                      ),
                      child: Row(
                        children: [
                          Text(
                            pago.referenciaInterna,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 28),

                // Imagen del QR Estático de Bs 0
                _buildQrImage(),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este QR no tiene monto prefijado (Bs 0). '
                          'Al escanearlo en Yape o tu banca, digita exactamente Bs. ${widget.monto.toStringAsFixed(2)}.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Temporizador
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Tiempo restante: $minutes:$seconds',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _timeLeft.inMinutes < 2 ? Colors.redAccent : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Botón de finalización
          if (pago.isPagado)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text(
                  'Ver mis pedidos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                  );
                },
              ),
            )
          else
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver a la tienda'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(PagoQrModel pago) {
    if (pago.isPagado) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Pago Confirmado!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  Text(
                    'El saldo fue verificado por el administrador y tu compra ha sido confirmada.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (pago.isValidadoNotif) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pago detectado, confirmando…',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  Text(
                    'Estamos cerrando tu pago. Esta pantalla se actualizará sola.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (pago.isExpirado) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'El cobro expiró por tiempo límite. Genera un nuevo intento.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    }

    if (pago.estado == 'RECHAZADO') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este intento de cobro fue reemplazado por uno nuevo. '
                'Si ya pagaste, avisa al administrador.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    }

    // PENDIENTE
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Escucha activa en el receptor: Esperando que realices la transferencia...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage() {
    // Prioridad: URL guardada en Supabase (se puede cambiar sin recompilar).
    final url = (_service.qrEstaticoUrl ?? '').isNotEmpty
        ? _service.qrEstaticoUrl!
        : PaymentConfig.qrImageUrl;

    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 220,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackLocalImage(),
        ),
      );
    }

    return _fallbackLocalImage();
  }

  Widget _fallbackLocalImage() {
    if (PaymentConfig.qrAssetPath.isEmpty) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 72, color: AppTheme.primaryColor),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'El administrador aún no configuró\nla imagen del QR de Bs 0.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        PaymentConfig.qrAssetPath,
        width: 220,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 220,
          height: 220,
          color: Colors.grey.shade100,
          child: const Center(
            child: Icon(Icons.qr_code_2_rounded, size: 90, color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }
}
