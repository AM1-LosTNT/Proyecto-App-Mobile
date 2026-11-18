import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../models/reserva.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/reservation_status_chip.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _service = SupabaseService();
  List<Reserva> _reservas = [];
  final Set<String> _procesando = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.getMisReservas();
      if (!mounted) return;
      setState(() {
        _reservas = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(
          e,
          fallback:
              'No pudimos cargar tus reservas. Revisa tu conexión e inténtalo de nuevo.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _cancelar(Reserva reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancelar reserva'),
        content: Text(
          '¿Deseas cancelar tu reserva en "${reserva.destinoNombre}" para el '
          '${reserva.fechaHoraTexto}? El negocio verá que la cancelaste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _procesando.add(reserva.id));
    try {
      await _service.cancelarReserva(reserva.id);
      await _load();
      if (!mounted) return;
      AppFeedback.success(context, 'Tu reserva fue cancelada correctamente.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback:
            'No se pudo cancelar la reserva. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _procesando.remove(reserva.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
          const Icon(Icons.cloud_off_rounded,
              size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar tus reservas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (_reservas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
          Icon(Icons.receipt_long_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text(
            'Todavía no tienes reservas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando solicites una reserva aparecerá aquí con su estado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reservas.length,
      itemBuilder: (context, index) {
        final reserva = _reservas[index];
        return _ReservaCard(
          reserva: reserva,
          procesando: _procesando.contains(reserva.id),
          onCancel: () => _cancelar(reserva),
        );
      },
    );
  }
}

class _ReservaCard extends StatelessWidget {
  final Reserva reserva;
  final bool procesando;
  final VoidCallback onCancel;

  const _ReservaCard({
    required this.reserva,
    required this.procesando,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final estado = reserva.estado;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: reserva.destinoImagen.isEmpty
                      ? Container(
                          width: 64,
                          height: 64,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.landscape_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          reserva.destinoImagen,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(Icons.landscape_rounded,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reserva.destinoNombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      ReservationStatusChip(status: estado),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.event_rounded,
              text: reserva.fechaHoraTexto,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.people_alt_outlined,
              text: reserva.personasTexto,
            ),
            if (estado == ReservationStatus.pendiente ||
                estado == ReservationStatus.rechazada) ...[
              const SizedBox(height: 8),
              Text(
                estado == ReservationStatus.rechazada &&
                        reserva.motivoRechazo.isNotEmpty
                    ? 'Motivo del negocio: ${reserva.motivoRechazo}'
                    : estado.description,
                style: TextStyle(
                  fontSize: 12,
                  color: estado == ReservationStatus.rechazada
                      ? Colors.redAccent
                      : AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  reserva.totalTexto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (estado.puedeCancelarTurista)
                  TextButton.icon(
                    onPressed: procesando ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: procesando
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.redAccent),
                          )
                        : const Icon(Icons.close_rounded, size: 16),
                    label: Text(procesando ? 'Cancelando...' : 'Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
