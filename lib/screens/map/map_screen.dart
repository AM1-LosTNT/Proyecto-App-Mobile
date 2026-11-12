import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../details/details_screen.dart';
import '../route/route_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _selectedCategory = 'all';
  String _query = '';
  DestinoLugar? _selectedDestino;
  LatLng? _myLocation;
  bool _locating = false;
  bool _showResults = false;

  static const LatLng _santaCruz = LatLng(-17.7833, -63.1821);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation({bool showMessage = true}) async {
    setState(() => _locating = true);
    final position = await LocationService.currentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() => _locating = false);
      if (showMessage) {
        _snack('No pudimos obtener tu ubicación. Revisa los permisos.');
      }
      return;
    }

    setState(() {
      _myLocation = position;
      _locating = false;
    });
    _mapController.move(position, 15.5);
    if (showMessage) _snack('Ubicación actualizada.', success: true);
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

  void _selectPlace(DestinoLugar destino) {
    _searchFocus.unfocus();
    setState(() {
      _selectedDestino = destino;
      _showResults = false;
    });
    _mapController.move(destino.ubicacion, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categorias = appState.categoriasSinTodo;
    final destinos = appState.filterDestinos(
      categorySlug: _selectedCategory,
      query: _query,
    );

    final markers = <Marker>[
      if (_myLocation != null)
        Marker(
          point: _myLocation!,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ...destinos.map((destino) {
        final isSelected = _selectedDestino?.id == destino.id;
        final markerColor = _markerColor(destino.tipo);
        final markerIcon = _markerIcon(destino.tipo);
        return Marker(
          point: destino.ubicacion,
          width: isSelected ? 56 : 46,
          height: isSelected ? 56 : 46,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedDestino = destino);
              _mapController.move(destino.ubicacion, 15.5);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 3.5 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                markerIcon,
                color: Colors.white,
                size: isSelected ? 28 : 22,
              ),
            ),
          ),
        );
      }),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _santaCruz,
              initialZoom: 12.5,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, __) {
                _searchFocus.unfocus();
                setState(() {
                  _selectedDestino = null;
                  _showResults = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.turisapp.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Controles superiores respetando notch / cámara / barra de estado.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                          _showResults = value.trim().isNotEmpty;
                          _selectedDestino = null;
                        });
                      },
                      onTap: () {
                        if (_query.trim().isNotEmpty) {
                          setState(() => _showResults = true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar un lugar en el mapa...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.textSecondary),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _showResults = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categorias.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final cat = isAll ? null : categorias[index - 1];
                        final slug = isAll ? 'all' : cat!.slug;
                        final label = isAll ? 'Todos' : cat!.nombre;
                        final selected = _selectedCategory == slug;

                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppTheme.textPrimary,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          elevation: 3,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade200,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = slug;
                              _selectedDestino = null;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  if (_showResults)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: destinos.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                    'No encontramos lugares con ese nombre.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: destinos.take(8).length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final destino = destinos[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(_markerIcon(destino.tipo),
                                          color: _markerColor(destino.tipo)),
                                      title: Text(
                                        destino.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        destino.direccion.isNotEmpty
                                            ? destino.direccion
                                            : destino.tipoLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        destino.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      onTap: () => _selectPlace(destino),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Botón de ubicación actual.
          Positioned(
            right: 14,
            bottom: _selectedDestino != null ? 190 : 24,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'location_fab',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                onPressed: _locating ? null : () => _goToMyLocation(),
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
          ),

          // Tarjeta del lugar seleccionado.
          if (_selectedDestino != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlaceSheet(
                    destino: _selectedDestino!,
                    onClose: () => setState(() => _selectedDestino = null),
                    onDetails: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsScreen(destino: _selectedDestino!),
                        ),
                      );
                    },
                    onRoute: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteScreen(destination: _selectedDestino!),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          if (appState.loadingData && appState.destinos.isEmpty)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Cargando lugares...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _markerColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'hotel':
        return Colors.indigo;
      case 'restaurant':
        return Colors.orange;
      case 'hospital':
        return Colors.redAccent;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _markerIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'hotel':
        return Icons.hotel_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}

class _PlaceSheet extends StatelessWidget {
  final DestinoLugar destino;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onRoute;

  const _PlaceSheet({
    required this.destino,
    required this.onClose,
    required this.onDetails,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: destino.imagenPrincipal.isEmpty
                      ? Container(
                          width: 74,
                          height: 74,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.landscape_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          destino.imagenPrincipal,
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 74,
                            height: 74,
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(Icons.landscape_rounded,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        destino.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        destino.direccion.isNotEmpty
                            ? destino.direccion
                            : destino.tipoLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            destino.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${destino.totalReviews})',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            destino.precioTexto.isNotEmpty
                                ? destino.precioTexto
                                : (destino.precio > 0
                                    ? 'Bs. ${destino.precio.toStringAsFixed(0)}'
                                    : 'Gratis'),
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.directions_bus_rounded, size: 18),
                    label: const Text('Cómo llegar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDetails,
                    child: const Text('Ver detalles'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
