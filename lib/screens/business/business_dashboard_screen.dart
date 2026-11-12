import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../details/details_screen.dart';
import 'place_form_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _service = SupabaseService();
  List<Map<String, dynamic>> _reservas = [];
  bool _loadingReservas = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReservas());
  }

  Future<void> _loadReservas() async {
    final appState = context.read<AppState>();
    if (appState.user == null) return;
    setState(() => _loadingReservas = true);
    final data = await _service.getReservasNegocio(appState.user!.id);
    if (!mounted) return;
    setState(() {
      _reservas = data;
      _loadingReservas = false;
    });
  }

  Future<void> _deletePlace(DestinoLugar place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lugar'),
        content: Text('¿Deseas eliminar "${place.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _service.deletePlace(place.id);
      if (!mounted) return;
      context.read<AppState>().removePlaceById(place.id);
      _snack('Lugar eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _toggleActive(DestinoLugar place, bool active) async {
    try {
      await _service.setPlaceActive(place.id, active);
      if (!mounted) return;
      context.read<AppState>().upsertPlace(place.copyWith(activo: active));
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.primaryColor : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final places = appState.myPlaces;

    if (!appState.isBusiness && !appState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi negocio')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Esta sección está disponible para cuentas de dueño de negocio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final totalReviews = places.fold<int>(0, (sum, p) => sum + p.totalReviews);
    final avgRating = places.isEmpty
        ? 0.0
        : places.fold<double>(0, (sum, p) => sum + p.rating) / places.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _DashboardHeader(
                businessName: appState.profile?.nombreNegocio.isNotEmpty == true
                    ? appState.profile!.nombreNegocio
                    : 'Mi negocio',
                coverUrl: appState.profile?.portadaUrl ?? '',
                placesCount: places.length,
                rating: avgRating,
                reviews: totalReviews,
                reservas: _reservas.length,
                onAdd: () => _openForm(context),
              ),
              const TabBar(
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primaryColor,
                tabs: [
                  Tab(text: 'Mis lugares'),
                  Tab(text: 'Reservas'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: appState.refreshDestinos,
                      color: AppTheme.primaryColor,
                      child: places.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.12),
                                Icon(Icons.storefront_outlined,
                                    size: 72, color: Colors.grey.shade400),
                                const SizedBox(height: 14),
                                const Text(
                                  'Aún no has publicado tu negocio',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Agrega tu primer lugar para que los turistas puedan encontrarlo en el mapa.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openForm(context),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Publicar mi negocio'),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: places.length,
                              itemBuilder: (context, index) {
                                final place = places[index];
                                return _PlaceTile(
                                  place: place,
                                  onTap: () => _openForm(context, place: place),
                                  onView: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetailsScreen(destino: place),
                                      ),
                                    );
                                  },
                                  onDelete: () => _deletePlace(place),
                                  onActiveChanged: (value) =>
                                      _toggleActive(place, value),
                                );
                              },
                            ),
                    ),
                    _ReservasTab(
                      loading: _loadingReservas,
                      reservas: _reservas,
                      onRefresh: _loadReservas,
                      onStatusChanged: (id, estado) async {
                        try {
                          await _service.updateReservaEstado(id, estado);
                          await _loadReservas();
                          _snack('Estado actualizado.', success: true);
                        } catch (e) {
                          _snack('No se pudo actualizar: $e');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Nuevo lugar'),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {DestinoLugar? place}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceFormScreen(existing: place),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String businessName;
  final String coverUrl;
  final int placesCount;
  final double rating;
  final int reviews;
  final int reservas;
  final VoidCallback onAdd;

  const _DashboardHeader({
    required this.businessName,
    required this.coverUrl,
    required this.placesCount,
    required this.rating,
    required this.reviews,
    required this.reservas,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Stack(
        children: [
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(26)),
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(26)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Panel de mi negocio',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: onAdd,
                      tooltip: 'Agregar lugar',
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeaderStat(label: 'Lugares', value: '$placesCount'),
                    _HeaderStat(label: 'Reservas', value: '$reservas'),
                    _HeaderStat(
                      label: 'Calificación',
                      value: placesCount == 0
                          ? '—'
                          : '${rating.toStringAsFixed(1)} ⭐',
                    ),
                    _HeaderStat(label: 'Opiniones', value: '$reviews'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final DestinoLugar place;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  const _PlaceTile({
    required this.place,
    required this.onTap,
    required this.onView,
    required this.onDelete,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: place.imagenPrincipal.isEmpty
                      ? Container(
                          width: 74,
                          height: 74,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          place.imagenPrincipal,
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 74,
                            height: 74,
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(Icons.storefront_rounded,
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
                        place.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place.categoriaNombre ?? place.tipoLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${place.totalReviews} opiniones)',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: place.activo,
                  activeColor: AppTheme.primaryColor,
                  onChanged: onActiveChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Ver'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservasTab extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> reservas;
  final Future<void> Function() onRefresh;
  final void Function(String id, String estado) onStatusChanged;

  const _ReservasTab({
    required this.loading,
    required this.reservas,
    required this.onRefresh,
    required this.onStatusChanged,
  });

  static const List<String> _estados = [
    'Pendiente',
    'Confirmada',
    'Completada',
    'Cancelada',
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: reservas.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Todavía no hay reservas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                final destino = reserva['destinos_lugares'] as Map?;
                final usuario = reserva['usuarios'] as Map?;
                final id = reserva['id']?.toString() ?? '';
                final estado =
                    reserva['estado']?.toString() ?? 'Confirmada';
                final total =
                    (reserva['total'] as num?)?.toDouble() ?? 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                destino?['nombre']?.toString() ??
                                    'Lugar reservado',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            PopupMenuButton<String>(
                              initialValue: estado,
                              onSelected: (value) =>
                                  onStatusChanged(id, value),
                              itemBuilder: (_) => _estados
                                  .map((e) => PopupMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ))
                                  .toList(),
                              child: _StatusBadge(estado: estado),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cliente: ${usuario?['nombre'] ?? 'Turista'}'
                          '${usuario?['telefono'] != null ? ' · ${usuario!['telefono']}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reserva['cantidad_personas'] ?? 1} personas · '
                          'Fecha: ${reserva['fecha_reserva'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Bs. ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            estado,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: color),
        ],
      ),
    );
  }
}
