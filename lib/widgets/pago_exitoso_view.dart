import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla de pago completado con animación de check.
///
/// Se muestra automáticamente en cuanto el cobro pasa a `PAGADO`, sin que el
/// cliente tenga que refrescar nada.
class PagoExitosoView extends StatefulWidget {
  const PagoExitosoView({
    super.key,
    required this.monto,
    required this.referencia,
    this.remitente,
    this.pagadoEn,
    this.automatico = true,
    required this.onVerPedidos,
    required this.onVolver,
  });

  final double monto;
  final String referencia;
  final String? remitente;
  final DateTime? pagadoEn;

  /// `true` si lo confirmó la notificación de Yape, `false` si fue manual.
  final bool automatico;

  final VoidCallback onVerPedidos;
  final VoidCallback onVolver;

  @override
  State<PagoExitosoView> createState() => _PagoExitosoViewState();
}

class _PagoExitosoViewState extends State<PagoExitosoView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ring;
  late final Animation<double> _check;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic),
    );
    _check = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _hora {
    final d = widget.pagadoEn?.toLocal() ?? DateTime.now();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FBF7),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F8EF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(),
                      const SizedBox(height: 22),
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: _buildTexts(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: SizedBox(
            width: 172,
            height: 172,
            child: CustomPaint(
              painter: _PagoBadgePainter(
                ring: _ring.value,
                check: _check.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTexts(BuildContext context) {
    return Column(
      children: [
        const Text(
          '¡Pago completado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF065F46),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.automatico
              ? 'Yape confirmó tu transferencia automáticamente.'
              : 'El administrador confirmó tu pago.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppTheme.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD1FAE5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Monto pagado',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Bs. ${widget.monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                  letterSpacing: -0.8,
                ),
              ),
              const Divider(height: 24),
              _fila('Referencia', widget.referencia, mono: true),
              if ((widget.remitente ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                _fila('Recibido de', widget.remitente!),
              ],
              const SizedBox(height: 8),
              _fila('Hora', _hora),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF047857)),
              SizedBox(width: 6),
              Text(
                'Pedido actualizado a Pagado',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text(
              'Ver mis pedidos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            onPressed: widget.onVerPedidos,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: widget.onVolver,
          child: const Text(
            'Volver a la tienda',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fila(String label, String value, {bool mono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PagoBadgePainter extends CustomPainter {
  _PagoBadgePainter({required this.ring, required this.check});

  final double ring;
  final double check;

  static const _verde = Color(0xFF10B981);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.37;

    // Halo suave que crece con el anillo.
    canvas.drawCircle(
      center,
      radius * (1.0 + 0.20 * ring),
      Paint()..color = _verde.withValues(alpha: 0.12 * ring),
    );

    // Relleno del círculo.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _verde.withValues(alpha: 0.10),
    );

    // Chispas radiales.
    if (ring > 0.05) {
      final fade = ((ring - 0.35) / 0.65).clamp(0.0, 1.0);
      for (var i = 0; i < 12; i++) {
        final angle = (2 * math.pi / 12) * i + 0.26;
        final dist = radius * (1.02 + 0.42 * ring);
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
        final r = size.width * 0.016 * (1.0 - fade * 0.35);
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF34D399),
              const Color(0x0034D399),
              fade,
            )!,
        );
      }
    }

    // Anillo que se dibuja en sentido horario.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ring.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = _verde
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..strokeCap = StrokeCap.round,
    );

    // Check animado.
    if (check <= 0) return;

    final p0 = center + Offset(-radius * 0.44, radius * 0.02);
    final p1 = center + Offset(-radius * 0.11, radius * 0.34);
    final p2 = center + Offset(radius * 0.46, -radius * 0.30);

    final path = Path()..moveTo(p0.dx, p0.dy);
    if (check <= 0.45) {
      final mid = Offset.lerp(p0, p1, check / 0.45)!;
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.lineTo(p1.dx, p1.dy);
      final mid = Offset.lerp(p1, p2, (check - 0.45) / 0.55)!;
      path.lineTo(mid.dx, mid.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _verde
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PagoBadgePainter oldDelegate) {
    return oldDelegate.ring != ring || oldDelegate.check != check;
  }
}
