import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _service = SupabaseService();
  List<Map<String, dynamic>> _reservas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getMisReservas();
    if (!mounted) return;
    setState(() {
      _reservas = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _reservas.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                      Icon(Icons.receipt_long_outlined,
                          size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 14),
                      const Text(
                        'Todavía no tienes reservas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Cuando reserves un lugar aparecerá aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reservas.length,
                    itemBuilder: (context, index) {
                      final reserva = _reservas[index];
                      final destino = reserva['destinos_lugares'] as Map?;
                      final nombre =
                          destino?['nombre']?.toString() ?? 'Lugar reservado';
                      final imagen =
                          destino?['imagen_principal']?.toString() ?? '';
                      final estado =
                          reserva['estado']?.toString() ?? 'Confirmada';
                      final total =
                          (reserva['total'] as num?)?.toDouble() ?? 0.0;
                      final personas =
                          (reserva['cantidad_personas'] as num?)?.toInt() ?? 1;
                      final fecha = reserva['fecha_reserva']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imagen.isEmpty
                                    ? Container(
                                        width: 64,
                                        height: 64,
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.12),
                                        child: const Icon(
                                            Icons.landscape_rounded,
                                            color: AppTheme.primaryColor),
                                      )
                                    : Image.network(
                                        imagen,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 64,
                                          height: 64,
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.12),
                                          child: const Icon(
                                              Icons.landscape_rounded,
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
                                      nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Fecha: $fecha · $personas personas',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _StatusBadge(estado: estado),
                                        const Spacer(),
                                        Text(
                                          'Bs. ${total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String estado;

  const _StatusBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (estado.toLowerCase()) {
      case 'cancelada':
        color = Colors.redAccent;
        break;
      case 'pendiente':
        color = Colors.orange;
        break;
      case 'completada':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        estado,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
