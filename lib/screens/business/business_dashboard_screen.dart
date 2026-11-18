import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_error.dart';
import '../../models/place_model.dart';
import '../../models/reserva.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/reservation_status_chip.dart';
import '../details/details_screen.dart';
import 'place_form_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _service = SupabaseService();
  List<Reserva> _reservas = [];
  bool _loadingReservas = true;
  String? _reservasError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReservas());
  }

  Future<void> _loadReservas() async {
    final appState = context.read<AppState>();
    if (appState.user == null) return;

    setState(() {
      _loadingReservas = true;
      _reservasError = null;
    });

    try {
      final data = await _service.getReservasNegocio(appState.user!.id);
      if (!mounted) return;
      setState(() {
        _reservas = data;
        _loadingReservas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reservasError = friendlyError(
          e,
          fallback:
              'No pudimos cargar las reservas de tu negocio. Revisa tu conexión e inténtalo de nuevo.',
        );
        _loadingReservas = false;
      });
    }
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
      AppFeedback.success(context, 'Lugar eliminado.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback: 'No se pudo eliminar el lugar. Inténtalo de nuevo.',
      );
    }
  }

  Future<void> _toggleActive(DestinoLugar place, bool active) async {
    try {
      await _service.setPlaceActive(place.id, active);
      if (!mounted) return;
      context.read<AppState>().upsertPlace(place.copyWith(activo: active));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback: 'No se pudo actualizar la visibilidad del lugar.',
      );
    }
  }

  Future<void> _aceptarReserva(Reserva reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aceptar reserva'),
        content: Text(
          '¿Aceptar la reserva de ${reserva.clienteNombre} para el '
          '${reserva.fechaHoraTexto}? El turista verá que fue aceptada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _service.updateReservaEstado(
        reserva.id,
        ReservationStatus.aceptada,
      );
      await _loadReservas();
      if (!mounted) return;
      AppFeedback.success(context, 'Reserva aceptada. El turista ya puede verlo.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback: 'No se pudo aceptar la reserva. Inténtalo de nuevo.',
      );
    }
  }

  Future<void> _rechazarReserva(Reserva reserva) async {
    final motivoController = TextEditingController();

    final resultado = await showDialog<({String motivo})>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rechazar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reserva de ${reserva.clienteNombre} para el '
              '${reserva.fechaHoraTexto}.',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej. No hay disponibilidad para esa fecha',
                alignLabelWithHint: true,
              ),
            ),
            const Text(
              'El turista podrá leer el motivo en "Mis reservas".',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(
              ctx,
              (motivo: motivoController.text.trim()),
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    motivoController.dispose();

    if (resultado == null || !mounted) return;

    try {
      await _service.updateReservaEstado(
        reserva.id,
        ReservationStatus.rechazada,
        motivoRechazo: resultado.motivo,
      );
      await _loadReservas();
      if (!mounted) return;
      AppFeedback.success(context, 'Reserva rechazada. El turista verá el motivo.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback: 'No se pudo rechazar la reserva. Inténtalo de nuevo.',
      );
    }
  }

  Future<void> _completarReserva(Reserva reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Marcar como completada'),
        content: Text(
          '¿Confirmas que la reserva de ${reserva.clienteNombre} ya se realizó?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, completada'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _service.updateReservaEstado(
        reserva.id,
        ReservationStatus.completada,
      );
      await _loadReservas();
      if (!mounted) return;
      AppFeedback.success(context, 'Reserva marcada como completada.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorFrom(
        context,
        e,
        fallback: 'No se pudo actualizar la reserva. Inténtalo de nuevo.',
      );
    }
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
                      error: _reservasError,
                      reservas: _reservas,
                      onRefresh: _loadReservas,
                      onAccept: _aceptarReserva,
                      onReject: _rechazarReserva,
                      onComplete: _completarReserva,
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
  final String? error;
  final List<Reserva> reservas;
  final Future<void> Function() onRefresh;
  final void Function(Reserva) onAccept;
  final void Function(Reserva) onReject;
  final void Function(Reserva) onComplete;

  const _ReservasTab({
    required this.loading,
    required this.error,
    required this.reservas,
    required this.onRefresh,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          const Icon(Icons.cloud_off_rounded,
              size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar las reservas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cuando un turista solicite una reserva aparecerá aquí.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                return _BusinessReservaCard(
                  reserva: reserva,
                  onAccept: () => onAccept(reserva),
                  onReject: () => onReject(reserva),
                  onComplete: () => onComplete(reserva),
                );
              },
            ),
    );
  }
}

class _BusinessReservaCard extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;

  const _BusinessReservaCard({
    required this.reserva,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
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
            // Encabezado: imagen + nombre del lugar + estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: reserva.destinoImagen.isEmpty
                      ? Container(
                          width: 56,
                          height: 56,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.landscape_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          reserva.destinoImagen,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
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

            // Datos del cliente
            Row(
              children: [
                const Icon(Icons.person_outline, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reserva.clienteNombre +
                        (reserva.clienteTelefono.isNotEmpty
                            ? ' · ${reserva.clienteTelefono}'
                            : '') +
                        (reserva.clienteEmail.isNotEmpty
                            ? ' · ${reserva.clienteEmail}'
                            : ''),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Fecha y hora
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  reserva.fechaHoraTexto,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Personas
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  reserva.personasTexto,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),

            // Motivo de rechazo (si fue rechazada)
            if (estado == ReservationStatus.rechazada &&
                reserva.motivoRechazo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo: ${reserva.motivoRechazo}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 12),

            // Total + botones de acción
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

                // Botones solo si la reserva está en espera
                if (estado.puedeGestionarNegocio) ...[
                  TextButton.icon(
                    onPressed: onReject,
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Aceptar'),
                  ),
                ],

                // Marcar completada (solo si está aceptada)
                if (estado == ReservationStatus.aceptada)
                  OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt_rounded, size: 16),
                    label: const Text('Completar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
