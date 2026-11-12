import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../models/review_model.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../route/route_screen.dart';

class DetailsScreen extends StatefulWidget {
  final DestinoLugar destino;

  const DetailsScreen({super.key, required this.destino});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _supabaseService = SupabaseService();
  final _commentController = TextEditingController();
  final _pageController = PageController();

  late DestinoLugar _destino;
  int _currentImageIndex = 0;
  int _userRating = 5;
  List<Resena> _resenas = [];
  bool _isLoadingReviews = true;
  bool _savingReview = false;

  @override
  void initState() {
    super.initState();
    _destino = widget.destino;
    _loadResenas();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Resena? get _miResena {
    final user = _supabaseService.currentUser;
    if (user == null) return null;
    for (final resena in _resenas) {
      if (resena.idUsuario == user.id) return resena;
    }
    return null;
  }

  Future<void> _loadResenas() async {
    if (mounted) setState(() => _isLoadingReviews = true);
    final reviews = await _supabaseService.getResenas(_destino.id);

    if (!mounted) return;

    var updated = _destino;
    if (reviews.isNotEmpty) {
      final sum = reviews.fold<int>(0, (acc, r) => acc + r.calificacion);
      final average = sum / reviews.length;
      updated = _destino.copyWith(
        rating: double.parse(average.toStringAsFixed(1)),
        totalReviews: reviews.length,
      );
    } else {
      updated = _destino.copyWith(rating: 0, totalReviews: 0);
    }
    context.read<AppState>().applyLocalRating(
          _destino.id,
          updated.rating,
          updated.totalReviews,
        );

    final mine = _supabaseService.currentUser == null
        ? null
        : reviews.cast<Resena?>().firstWhere(
              (r) => r?.idUsuario == _supabaseService.currentUser!.id,
              orElse: () => null,
            );

    setState(() {
      _resenas = reviews;
      _destino = updated;
      _isLoadingReviews = false;
      if (mine != null) {
        _userRating = mine.calificacion;
        _commentController.text = mine.comentario;
      }
    });
  }

  void _showAddReviewDialog() {
    final user = _supabaseService.currentUser;
    if (user == null) {
      _showSnack('Inicia sesión para publicar una reseña.');
      return;
    }

    final existing = _miResena;
    if (existing != null) {
      _userRating = existing.calificacion;
      _commentController.text = existing.comentario;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null ? 'Escribir una reseña' : 'Editar mi reseña',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('¿Qué te pareció este lugar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return IconButton(
                        icon: Icon(
                          starVal <= _userRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setSheetState(() => _userRating = starVal);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Cuéntanos tu experiencia en este lugar...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _savingReview
                        ? null
                        : () async {
                            final comment = _commentController.text.trim();
                            if (comment.isEmpty) {
                              _showSnack('Escribe un comentario para continuar.');
                              return;
                            }
                            setSheetState(() => _savingReview = true);
                            try {
                              await _supabaseService.saveResena(
                                idDestino: _destino.id,
                                calificacion: _userRating,
                                comentario: comment,
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              await _loadResenas();
                              _showSnack(
                                existing == null
                                    ? '¡Gracias por tu opinión!'
                                    : 'Tu reseña se actualizó correctamente.',
                                success: true,
                              );
                            } catch (e) {
                              _showSnack(
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => _savingReview = false);
                              }
                            }
                          },
                    child: _savingReview
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(existing == null
                            ? 'Publicar reseña'
                            : 'Guardar cambios'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingDialog() {
    final user = _supabaseService.currentUser;
    if (user == null) {
      _showSnack('Inicia sesión para realizar una reserva.');
      return;
    }

    int personas = 1;
    final precio = _destino.precio > 0 ? _destino.precio : 50.0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final total = precio * personas;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Confirmar reserva'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _destino.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text('Precio por persona: Bs. ${precio.toStringAsFixed(2)}'),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Personas:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: personas > 1
                                ? () => setDialogState(() => personas--)
                                : null,
                          ),
                          Text('$personas',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setDialogState(() => personas++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a pagar:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'Bs. ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      final fechaHoy =
                          DateTime.now().toIso8601String().split('T').first;
                      await _supabaseService.crearReserva(
                        idDestino: _destino.id,
                        fechaReserva: fechaHoy,
                        cantidadPersonas: personas,
                        precioUnitario: precio,
                        total: total,
                      );
                      _showSnack('¡Reserva confirmada! Te esperamos.',
                          success: true);
                    } catch (e) {
                      _showSnack('No se pudo reservar: $e');
                    }
                  },
                  child: const Text('Confirmar reserva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isFavorite = appState.isFavorite(_destino.id);
    final images = _destino.imagenes.isNotEmpty
        ? _destino.imagenes
        : (_destino.imagenPrincipal.isNotEmpty ? [_destino.imagenPrincipal] : <String>[]);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                leading: _RoundAction(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _RoundAction(
                      icon: isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: isFavorite ? AppTheme.secondaryColor : Colors.white,
                      onTap: () async {
                        try {
                          await appState.toggleFavorite(_destino);
                        } catch (e) {
                          _showSnack(e.toString());
                        }
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isEmpty)
                        Container(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          child: const Icon(Icons.landscape_rounded,
                              size: 70, color: AppTheme.primaryColor),
                        )
                      else
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (index) =>
                              setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.terrain_rounded,
                                    size: 60, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              final selected = _currentImageIndex == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: selected ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : Colors.white54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _destino.precioTexto.isNotEmpty
                                ? _destino.precioTexto
                                : (_destino.precio > 0
                                    ? 'Bs. ${_destino.precio.toStringAsFixed(0)}'
                                    : 'Entrada gratuita'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  _destino.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${_destino.totalReviews})',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _destino.nombre,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _destino.categoriaNombre ?? _destino.tipoLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppTheme.secondaryColor, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _destino.direccion.isNotEmpty
                                  ? _destino.direccion
                                  : 'Santa Cruz de la Sierra',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteScreen(destination: _destino),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_bus_rounded,
                                  color: AppTheme.primaryColor),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cómo llegar en micro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Calcula las líneas desde tu ubicación',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _destino.descripcion.isNotEmpty
                            ? _destino.descripcion
                            : 'Sin descripción disponible.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_destino.serviciosIncluidos.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Servicios incluidos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _destino.serviciosIncluidos.map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: AppTheme.primaryColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    amenity,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Opiniones de viajeros',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddReviewDialog,
                            icon: const Icon(Icons.rate_review_outlined, size: 18),
                            label: Text(_miResena == null ? 'Opinar' : 'Editar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_isLoadingReviews)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_resenas.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text(
                              'Aún no hay opiniones. ¡Sé el primero en calificar este lugar!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _resenas.map((rev) {
                            final isMine = rev.idUsuario ==
                                _supabaseService.currentUser?.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMine
                                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primaryColor
                                            .withValues(alpha: 0.12),
                                        backgroundImage: rev.avatarUsuario.isNotEmpty
                                            ? NetworkImage(rev.avatarUsuario)
                                            : null,
                                        child: rev.avatarUsuario.isEmpty
                                            ? Text(
                                                rev.nombreUsuario.isNotEmpty
                                                    ? rev.nombreUsuario[0]
                                                        .toUpperCase()
                                                    : 'T',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rev.nombreUsuario,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              _formatDate(rev.createdAt),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Colors.amber, size: 16),
                                          Text(
                                            '${rev.calificacion}.0',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      if (isMine)
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert,
                                              size: 18,
                                              color: AppTheme.textSecondary),
                                          onSelected: (value) async {
                                            if (value == 'delete') {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Eliminar reseña'),
                                                  content: const Text(
                                                      '¿Deseas eliminar tu opinión?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, false),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.redAccent),
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, true),
                                                      child: const Text('Eliminar'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await _supabaseService
                                                    .deleteResena(rev.id);
                                                _commentController.clear();
                                                _userRating = 5;
                                                await _loadResenas();
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    rev.comentario,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RouteScreen(destination: _destino),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions_bus_rounded),
                          label: const Text('Cómo llegar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _showBookingDialog,
                          child: const Text('Reservar ahora'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
  }
}
