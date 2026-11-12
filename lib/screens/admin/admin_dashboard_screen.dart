import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../models/user_profile.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../business/place_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = SupabaseService();

  List<AppUserProfile> _users = [];
  List<DestinoLugar> _places = [];
  List<CategoriaItem> _categorias = [];
  List<Map<String, dynamic>> _reservas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.adminGetUsers(),
        _service.getDestinos(includeInactive: true),
        _service.getCategorias(),
        _service.getAllReservas(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<AppUserProfile>;
        _places = results[1] as List<DestinoLugar>;
        _categorias = results[2] as List<CategoriaItem>;
        _reservas = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('No se pudieron cargar los datos: $e');
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

  Future<void> _editUser(AppUserProfile user) async {
    final nombre = TextEditingController(text: user.nombre);
    final telefono = TextEditingController(text: user.telefono);
    final negocio = TextEditingController(text: user.nombreNegocio);
    var rol = user.rol;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar ${user.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: negocio,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del negocio'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Turista')),
                    DropdownMenuItem(
                        value: 'business', child: Text('Dueño de negocio')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => rol = value ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await _service.adminUpdateUser(user.id, {
        'nombre': nombre.text.trim(),
        'telefono': telefono.text.trim(),
        'nombre_negocio': negocio.text.trim(),
        'rol': rol,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _loadAll();
      _snack('Usuario actualizado.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<void> _deleteUser(AppUserProfile user) async {
    final confirm = await _confirm(
      'Eliminar usuario',
      '¿Eliminar la cuenta de ${user.nombre}? Se eliminarán sus datos asociados.',
    );
    if (confirm != true) return;

    try {
      await _service.adminDeleteUser(user.id);
      await _loadAll();
      _snack('Usuario eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _deletePlace(DestinoLugar place) async {
    final confirm = await _confirm(
      'Eliminar lugar',
      '¿Eliminar "${place.nombre}" definitivamente?',
    );
    if (confirm != true) return;

    try {
      await _service.deletePlace(place.id);
      if (mounted) context.read<AppState>().removePlaceById(place.id);
      await _loadAll();
      _snack('Lugar eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _togglePlace(DestinoLugar place, bool active) async {
    try {
      await _service.setPlaceActive(place.id, active);
      if (!mounted) return;
      context.read<AppState>().upsertPlace(place.copyWith(activo: active));
      await _loadAll();
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<bool?> _confirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
  }

  Future<void> _editCategoria({CategoriaItem? categoria}) async {
    final nombre = TextEditingController(text: categoria?.nombre ?? '');
    final slug = TextEditingController(text: categoria?.slug ?? '');
    final descripcion =
        TextEditingController(text: categoria?.descripcion ?? '');
    final icono = TextEditingController(text: categoria?.icono ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoria == null ? 'Nueva categoría' : 'Editar categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: slug,
                decoration: const InputDecoration(
                    labelText: 'Identificador', hintText: 'ej. parques'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: icono,
                decoration:
                    const InputDecoration(labelText: 'Icono (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (nombre.text.trim().isEmpty || slug.text.trim().isEmpty) {
      _snack('Nombre e identificador son obligatorios.');
      return;
    }

    try {
      if (categoria == null) {
        await _service.createCategoria(
          nombre: nombre.text,
          slug: slug.text,
          descripcion: descripcion.text,
          icono: icono.text,
        );
      } else {
        await _service.updateCategoria(CategoriaItem(
          id: categoria.id,
          slug: slug.text.trim().toLowerCase(),
          nombre: nombre.text.trim(),
          descripcion: descripcion.text.trim(),
          icono: icono.text.trim(),
        ));
      }
      if (mounted) await context.read<AppState>().refreshAll();
      await _loadAll();
      _snack('Categoría guardada.', success: true);
    } catch (e) {
      _snack('No se pudo guardar: $e');
    }
  }

  Future<void> _deleteCategoria(CategoriaItem categoria) async {
    final confirm = await _confirm(
      'Eliminar categoría',
      '¿Eliminar "${categoria.nombre}"? Los lugares quedarán sin categoría.',
    );
    if (confirm != true) return;

    try {
      await _service.deleteCategoria(categoria.id);
      if (mounted) await context.read<AppState>().refreshAll();
      await _loadAll();
      _snack('Categoría eliminada.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _changeReservaEstado(String id, String estado) async {
    try {
      await _service.updateReservaEstado(id, estado);
      await _loadAll();
      _snack('Reserva actualizada.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<void> _deleteReserva(String id) async {
    final confirm =
        await _confirm('Eliminar reserva', '¿Eliminar esta reserva?');
    if (confirm != true) return;

    try {
      await _service.deleteReserva(id);
      await _loadAll();
      _snack('Reserva eliminada.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Esta sección está disponible solo para administradores.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final negocios = _users.where((u) => u.isBusiness).length;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Usuarios'),
              Tab(text: 'Lugares'),
              Tab(text: 'Categorías'),
              Tab(text: 'Reservas'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryColor))
            : TabBarView(
                children: [
                  _OverviewTab(
                    users: _users.length,
                    businesses: negocios,
                    places: _places.length,
                    categories: _categorias.length,
                    reservations: _reservas.length,
                    onRefresh: _loadAll,
                  ),
                  _UsersTab(
                    users: _users,
                    onEdit: _editUser,
                    onDelete: _deleteUser,
                  ),
                  _PlacesTab(
                    places: _places,
                    onEdit: (place) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceFormScreen(existing: place),
                        ),
                      ).then((_) => _loadAll());
                    },
                    onDelete: _deletePlace,
                    onToggle: _togglePlace,
                  ),
                  _CategoriesTab(
                    categorias: _categorias,
                    onCreate: () => _editCategoria(),
                    onEdit: (categoria) => _editCategoria(categoria: categoria),
                    onDelete: _deleteCategoria,
                  ),
                  _ReservationsTab(
                    reservas: _reservas,
                    onStatusChanged: _changeReservaEstado,
                    onDelete: _deleteReserva,
                  ),
                ],
              ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final int users;
  final int businesses;
  final int places;
  final int categories;
  final int reservations;
  final Future<void> Function() onRefresh;

  const _OverviewTab({
    required this.users,
    required this.businesses,
    required this.places,
    required this.categories,
    required this.reservations,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData('Usuarios', '$users', Icons.people_alt_rounded, Colors.indigo),
      _StatData('Negocios', '$businesses', Icons.storefront_rounded,
          AppTheme.secondaryColor),
      _StatData('Lugares', '$places', Icons.place_rounded,
          AppTheme.primaryColor),
      _StatData('Categorías', '$categories', Icons.category_rounded,
          Colors.purple),
      _StatData('Reservas', '$reservations', Icons.receipt_long_rounded,
          Colors.teal),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Resumen general',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Controla toda la actividad de TurisApp desde un solo lugar.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(card.icon, color: card.color, size: 26),
                    const Spacer(),
                    Text(
                      card.value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      card.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Como administrador puedes editar roles, ocultar o eliminar lugares, gestionar categorías y reservas.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData(this.label, this.value, this.icon, this.color);
}

class _UsersTab extends StatelessWidget {
  final List<AppUserProfile> users;
  final void Function(AppUserProfile) onEdit;
  final void Function(AppUserProfile) onDelete;

  const _UsersTab({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final color = user.isAdmin
            ? Colors.indigo
            : user.isBusiness
                ? AppTheme.secondaryColor
                : AppTheme.primaryColor;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? Text(user.inicial,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(user.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '${user.rolLabel}${user.nombreNegocio.isNotEmpty ? ' · ${user.nombreNegocio}' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit(user);
                if (value == 'delete') onDelete(user);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlacesTab extends StatelessWidget {
  final List<DestinoLugar> places;
  final void Function(DestinoLugar) onEdit;
  final void Function(DestinoLugar) onDelete;
  final void Function(DestinoLugar, bool) onToggle;

  const _PlacesTab({
    required this.places,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: place.imagenPrincipal.isEmpty
                      ? Container(
                          width: 56,
                          height: 56,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          place.imagenPrincipal,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(Icons.storefront_rounded,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${place.categoriaNombre ?? place.tipoLabel} · ${place.rating.toStringAsFixed(1)} ⭐ (${place.totalReviews})',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text(
                        place.activo ? 'Visible' : 'Oculto',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: place.activo ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: place.activo,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) => onToggle(place, value),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(place);
                    if (value == 'delete') onDelete(place);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final List<CategoriaItem> categorias;
  final VoidCallback onCreate;
  final void Function(CategoriaItem) onEdit;
  final void Function(CategoriaItem) onDelete;

  const _CategoriesTab({
    required this.categorias,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: categorias.length,
          itemBuilder: (context, index) {
            final categoria = categorias[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.category_rounded,
                      color: AppTheme.primaryColor, size: 18),
                ),
                title: Text(categoria.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  categoria.slug,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(categoria);
                    if (value == 'delete') onDelete(categoria);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: onCreate,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Categoría'),
          ),
        ),
      ],
    );
  }
}

class _ReservationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reservas;
  final void Function(String, String) onStatusChanged;
  final void Function(String) onDelete;

  const _ReservationsTab({
    required this.reservas,
    required this.onStatusChanged,
    required this.onDelete,
  });

  static const _estados = [
    'Pendiente',
    'Confirmada',
    'Completada',
    'Cancelada',
  ];

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) {
      return const Center(
        child: Text(
          'No hay reservas registradas.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reservas.length,
      itemBuilder: (context, index) {
        final reserva = reservas[index];
        final destino = reserva['destinos_lugares'] as Map?;
        final usuario = reserva['usuarios'] as Map?;
        final id = reserva['id']?.toString() ?? '';
        final estado = reserva['estado']?.toString() ?? 'Confirmada';
        final total = (reserva['total'] as num?)?.toDouble() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destino?['nombre']?.toString() ?? 'Reserva',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    PopupMenuButton<String>(
                      initialValue: estado,
                      onSelected: (value) => onStatusChanged(id, value),
                      itemBuilder: (_) => _estados
                          .map((e) =>
                              PopupMenuItem(value: e, child: Text(e)))
                          .toList(),
                      child: Text(
                        estado,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDelete(id),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                    ),
                  ],
                ),
                Text(
                  'Cliente: ${usuario?['nombre'] ?? 'Turista'} · ${usuario?['email'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reserva['cantidad_personas'] ?? 1} personas · ${reserva['fecha_reserva'] ?? ''} · Bs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
