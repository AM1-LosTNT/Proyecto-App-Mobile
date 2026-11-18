import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../models/place_model.dart';
import '../../models/review_model.dart';
import '../../models/user_profile.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
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
  AppUserProfile? _duenoPerfil;

  @override
  void initState() {
    super.initState();
    _destino = widget.destino;
    _loadResenas();
    _loadDuenoPerfil();
  }

  Future<void> _loadDuenoPerfil() async {
    final ownerId = _destino.idUsuario;
    if (ownerId != null && ownerId.isNotEmpty) {
      final perfil = await _supabaseService.getUserProfile(ownerId);
      if (mounted && perfil != null) {
        setState(() => _duenoPerfil = perfil);
      }
    }
  }

  Future<void> _abrirWhatsApp() async {
    final rawPhone = _duenoPerfil?.telefono.isNotEmpty == true
        ? _duenoPerfil!.telefono
        : _destino.telefono;

    if (rawPhone.trim().isEmpty) {
      AppFeedback.info(context, 'El dueño del negocio aún no registró un número de teléfono.');
      return;
    }

    var cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('591') && cleanPhone.length == 8) {
      cleanPhone = '591$cleanPhone';
    }

    final message = Uri.encodeComponent(
      'Hola, vi tu local "${_destino.nombre}" en TurisApp y quisiera consultar información.',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.error(context, 'No se pudo abrir WhatsApp. Verifica que la app esté instalada.');
      }
    }
  }

  Future<void> _abrirCorreo() async {
    final rawEmail = _duenoPerfil?.email.isNotEmpty == true
        ? _duenoPerfil!.email.trim()
        : '';

    if (rawEmail.isEmpty) {
      AppFeedback.info(context, 'El negocio no tiene un correo de contacto registrado.');
      return;
    }

    final subject = 'Consulta sobre ${_destino.nombre} - TurisApp';
    final body =
        'Hola,\n\nTe escribo desde TurisApp porque me interesa tu local "${_destino.nombre}".\n\nSaludos!';

    // Intentar primero URI directo mailto
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: rawEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    // Fallback directo a Gmail Web (compose)
    try {
      final gmailWebUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=$rawEmail&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      final launchedWeb = await launchUrl(
        gmailWebUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedWeb) return;
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.email_outlined, color: Color(0xFFEA4335)),
              SizedBox(width: 8),
              Text('Correo de contacto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No se pudo abrir automáticamente tu gestor de correo. Puedes escribir directamente a:'),
              const SizedBox(height: 10),
              SelectableText(
                rawEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
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
      AppFeedback.info(context, 'Inicia sesión para publicar una reseña.');
      return;
    }

    final existing = _miResena;
    if (existing != null) {
      _userRating = existing.calificacion;
      _commentController.text = existing.comentario;
    }

    String? formError;

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
                top: 12,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null
                              ? 'Escribir una reseña'
                              : 'Editar mi reseña',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) {
                        if (formError != null) {
                          setSheetState(() => formError = null);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cuéntanos tu experiencia en este lugar...',
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 4),
                      InlineAlert(
                        message: formError!,
                        onDismiss: () => setSheetState(() => formError = null),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _savingReview
                          ? null
                          : () async {
                              final comment = _commentController.text.trim();
                              if (comment.isEmpty) {
                                setSheetState(() => formError =
                                    'Escribe un comentario antes de publicar tu reseña.');
                                return;
                              }
                              if (comment.length < 5) {
                                setSheetState(() => formError =
                                    'Tu comentario es muy corto. Cuéntanos un poco más.');
                                return;
                              }

                              setSheetState(() {
                                _savingReview = true;
                                formError = null;
                              });
                              try {
                                await _supabaseService.saveResena(
                                  idDestino: _destino.id,
                                  calificacion: _userRating,
                                  comentario: comment,
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                await _loadResenas();
                                if (mounted) {
                                  AppFeedback.success(
                                    this.context,
                                    existing == null
                                        ? '¡Gracias por tu opinión!'
                                        : 'Tu reseña se actualizó correctamente.',
                                  );
                                }
                              } catch (e) {
                                if (!sheetContext.mounted) return;
                                setSheetState(() => formError = friendlyError(
                                      e,
                                      fallback:
                                          'No se pudo publicar tu reseña. Inténtalo de nuevo.',
                                    ));
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBookingDialog() async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      AppFeedback.info(context, 'Inicia sesión para realizar una reserva.');
      return;
    }

    final precio = _destino.precio > 0 ? _destino.precio : 0.0;

    DateTime? fechaSeleccionada;
    TimeOfDay? horaSeleccionada;
    var personas = 1;
    var guardando = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final total = precio * personas;

            Future<void> elegirFecha() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: sheetContext,
                initialDate: fechaSeleccionada ?? now,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 1, now.month, now.day),
                helpText: 'Fecha de la reserva',
                cancelText: 'Cancelar',
                confirmText: 'Aceptar',
              );
              if (picked != null && sheetContext.mounted) {
                setSheetState(() {
                  fechaSeleccionada = picked;
                  formError = null;
                });
              }
            }

            Future<void> elegirHora() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: horaSeleccionada ?? TimeOfDay.now(),
                helpText: 'Hora de la reserva',
                cancelText: 'Cancelar',
                confirmText: 'Aceptar',
                builder: (ctx, child) => MediaQuery(
                  data: MediaQuery.of(ctx)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null && sheetContext.mounted) {
                setSheetState(() {
                  horaSeleccionada = picked;
                  formError = null;
                });
              }
            }

            Future<void> enviarSolicitud() async {
              final fecha = fechaSeleccionada;
              final hora = horaSeleccionada;

              if (fecha == null) {
                setSheetState(() => formError =
                    'Selecciona la fecha en la que quieres visitar el lugar.');
                return;
              }
              if (hora == null) {
                setSheetState(() => formError =
                    'Selecciona la hora de tu reserva para continuar.');
                return;
              }

              final fechaHora = DateTime(
                fecha.year,
                fecha.month,
                fecha.day,
                hora.hour,
                hora.minute,
              );

              if (!fechaHora.isAfter(DateTime.now())) {
                setSheetState(() => formError =
                    'La fecha y la hora ya pasaron. Elige un momento posterior.');
                return;
              }

              // Consultar clima para alertar al usuario antes de confirmar la reserva
              final forecastClima = WeatherService.getForecastForDate(fechaHora);
              if (forecastClima != null && sheetContext.mounted) {
                final confirmacionClima = await showDialog<bool>(
                  context: sheetContext,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(Icons.wb_sunny_rounded, color: Colors.orangeAccent),
                        SizedBox(width: 8),
                        Text('Pronóstico del clima', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(forecastClima.weatherIcon, size: 36, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      forecastClima.weatherDescription,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${forecastClima.tempMin.toStringAsFixed(0)}°C a ${forecastClima.tempMax.toStringAsFixed(0)}°C · ${forecastClima.precipitationProbability}% lluvia',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      'Viento: ${forecastClima.windSpeedMax.toStringAsFixed(0)} km/h',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '¿Estás seguro de que deseas confirmar tu solicitud de reserva para esta fecha y hora?',
                          style: TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Revisar fecha'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sí, confirmar'),
                      ),
                    ],
                  ),
                );

                if (confirmacionClima != true) return;
              }

              setSheetState(() {
                guardando = true;
                formError = null;
              });

              try {
                await _supabaseService.crearReserva(
                  idDestino: _destino.id,
                  fechaHora: fechaHora,
                  cantidadPersonas: personas,
                  precioUnitario: precio,
                  total: total,
                );
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (mounted) {
                  AppFeedback.success(
                    this.context,
                    'Solicitud enviada. El negocio debe confirmarla; puedes seguir el estado en "Mis reservas".',
                  );
                }
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => formError = friendlyError(
                      e,
                      fallback:
                          'No se pudo enviar la solicitud de reserva. Inténtalo de nuevo.',
                    ));
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => guardando = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_available_rounded,
                                color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Solicitar reserva',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _destino.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      precio > 0
                          ? 'Precio por persona: Bs. ${precio.toStringAsFixed(2)}'
                          : 'Este lugar no cobra entrada.',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '¿Cuándo quieres ir?',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Fecha',
                            value: fechaSeleccionada == null
                                ? 'Elegir fecha'
                                : _formatDate(fechaSeleccionada!),
                            selected: fechaSeleccionada != null,
                            onTap: elegirFecha,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.access_time_rounded,
                            label: 'Hora',
                            value: horaSeleccionada == null
                                ? 'Elegir hora'
                                : _formatTime(horaSeleccionada!),
                            selected: horaSeleccionada != null,
                            onTap: elegirHora,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Personas',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: personas > 1
                                  ? () => setSheetState(() {
                                        personas--;
                                        formError = null;
                                      })
                                  : null,
                            ),
                            Text(
                              '$personas',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: personas < 50
                                  ? () => setSheetState(() {
                                        personas++;
                                        formError = null;
                                      })
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total estimado:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          total > 0
                              ? 'Bs. ${total.toStringAsFixed(2)}'
                              : 'Sin costo',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 14),
                      InlineAlert(
                        message: formError!,
                        onDismiss: () => setSheetState(() => formError = null),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: guardando ? null : enviarSolicitud,
                      child: guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Enviar solicitud'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu reserva quedará "En espera" hasta que el negocio la acepte o la rechace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                          if (!context.mounted) return;
                          AppFeedback.errorFrom(
                            context,
                            e,
                            fallback:
                                'No se pudo actualizar tus lugares guardados.',
                          );
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

                      // Tarjeta de Contacto Directo con el Dueño del Negocio (WhatsApp / Gmail)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded,
                                    color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _duenoPerfil?.nombreNegocio.isNotEmpty == true
                                      ? 'Contacto con ${_duenoPerfil!.nombreNegocio}'
                                      : 'Mensaje directo con el anfitrión',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _duenoPerfil != null
                                  ? 'Atendido por ${_duenoPerfil!.nombre}. Consulta dudas sobre servicios, horarios o promociones.'
                                  : 'Comunícate directamente por WhatsApp o Correo para resolver tus dudas.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Botón WhatsApp
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _abrirWhatsApp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_rounded, size: 18),
                                    label: const Text(
                                      'WhatsApp',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Botón Correo / Gmail
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _abrirCorreo,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEA4335),
                                      side: const BorderSide(color: Color(0xFFEA4335)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.email_outlined, size: 18),
                                    label: const Text(
                                      'Correo',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
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
                                                try {
                                                  await _supabaseService
                                                      .deleteResena(rev.id);
                                                  _commentController.clear();
                                                  _userRating = 5;
                                                  await _loadResenas();
                                                  if (!context.mounted) return;
                                                  AppFeedback.success(
                                                    context,
                                                    'Tu reseña se eliminó correctamente.',
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  AppFeedback.errorFrom(
                                                    context,
                                                    e,
                                                    fallback:
                                                        'No se pudo eliminar tu reseña. Inténtalo de nuevo.',
                                                  );
                                                }
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
                          child: const Text('Solicitar reserva'),
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

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppTheme.primaryColor : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.textPrimary : color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
