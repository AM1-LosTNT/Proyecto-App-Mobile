import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_error.dart';
import '../models/cart_item.dart';
import '../models/micro_route.dart';
import '../models/order_model.dart';
import '../models/place_model.dart';
import '../models/product_model.dart';
import '../models/reserva.dart';
import '../models/review_model.dart';
import '../models/user_profile.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ==========================================
  // AUTENTICACIÓN
  // ==========================================
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? nombreNegocio,
    String? telefono,
  }) async {
    try {
      return await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre': name.trim(),
          'rol': role == 'business' ? 'business' : 'user',
          if (nombreNegocio != null && nombreNegocio.trim().isNotEmpty)
            'nombre_negocio': nombreNegocio.trim(),
          if (telefono != null && telefono.trim().isNotEmpty)
            'telefono': telefono.trim(),
        },
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'No se pudo crear la cuenta: $e';
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'No se pudo iniciar sesión: $e';
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ==========================================
  // PERFIL DE USUARIO
  // ==========================================
  Future<AppUserProfile?> getUserProfile(String userId) async {
    try {
      final data = await client
          .from('usuarios')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return AppUserProfile.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Perfil de respaldo usando los metadatos de la sesión, para que la app
  /// funcione incluso si el trigger de la base de datos aún no creó la fila.
  AppUserProfile? profileFromSession(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AppUserProfile(
      id: user.id,
      nombre: meta['nombre']?.toString() ?? user.email?.split('@').first ?? 'Viajero',
      email: user.email ?? '',
      rol: meta['rol'] == 'business' ? 'business' : (meta['rol'] == 'admin' ? 'admin' : 'user'),
      nombreNegocio: meta['nombre_negocio']?.toString() ?? '',
      telefono: meta['telefono']?.toString() ?? '',
    );
  }

  Future<AppUserProfile> updateProfile({
    required String userId,
    String? nombre,
    String? telefono,
    String? nombreNegocio,
    String? avatarUrl,
    String? portadaUrl,
  }) async {
    final payload = <String, dynamic>{
      if (nombre != null) 'nombre': nombre.trim(),
      if (telefono != null) 'telefono': telefono.trim(),
      if (nombreNegocio != null) 'nombre_negocio': nombreNegocio.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (portadaUrl != null) 'portada_url': portadaUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final data = await client
        .from('usuarios')
        .update(payload)
        .eq('id', userId)
        .select()
        .single();

    return AppUserProfile.fromMap(data);
  }

  Future<AppUserProfile> ensureProfile({
    required String userId,
    required String nombre,
    required String email,
    required String rol,
    String? nombreNegocio,
    String? telefono,
  }) async {
    final existing = await getUserProfile(userId);
    if (existing != null) {
      // Completa los datos de negocio si el registro se creó sin ellos.
      if ((rol == 'business') &&
          (existing.nombreNegocio.isEmpty || existing.telefono.isEmpty)) {
        try {
          return await updateProfile(
            userId: userId,
            nombreNegocio:
                existing.nombreNegocio.isEmpty ? nombreNegocio : null,
            telefono: existing.telefono.isEmpty ? telefono : null,
          );
        } catch (_) {
          return existing;
        }
      }
      return existing;
    }

    final payload = {
      'id': userId,
      'nombre': nombre,
      'email': email,
      'rol': rol == 'business' ? 'business' : 'user',
      'nombre_negocio': nombreNegocio,
      'telefono': telefono,
    };

    final data = await client.from('usuarios').insert(payload).select().single();
    return AppUserProfile.fromMap(data);
  }

  // ==========================================
  // ALMACENAMIENTO DE IMÁGENES
  // ==========================================
  Future<String> uploadImage({
    required String bucket,
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_\-/]'), '_');
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final path =
        '$safeFolder/${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.$extension';

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }

  String _randomSuffix() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36);
  }

  // ==========================================
  // CATEGORÍAS
  // ==========================================
  Future<List<CategoriaItem>> getCategorias() async {
    try {
      final data = await client
          .from('categorias')
          .select()
          .order('id', ascending: true);
      return (data as List)
          .map((e) => CategoriaItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CategoriaItem> createCategoria({
    required String nombre,
    required String slug,
    String descripcion = '',
    String icono = '',
  }) async {
    final data = await client
        .from('categorias')
        .insert({
          'nombre': nombre.trim(),
          'slug': slug.trim().toLowerCase(),
          'descripcion': descripcion.trim(),
          'icono': icono.trim(),
        })
        .select()
        .single();
    return CategoriaItem.fromMap(data);
  }

  Future<void> updateCategoria(CategoriaItem categoria) async {
    await client.from('categorias').update(categoria.toMap()).eq('id', categoria.id);
  }

  Future<void> deleteCategoria(int id) async {
    await client.from('categorias').delete().eq('id', id);
  }

  // ==========================================
  // DESTINOS / LUGARES
  // ==========================================
  Future<List<DestinoLugar>> getDestinos({bool includeInactive = false}) async {
    var query = client.from('destinos_lugares').select('*, categorias(*)');
    if (!includeInactive) {
      query = query.eq('activo', true);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((e) => DestinoLugar.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<DestinoLugar?> getDestinoById(String id) async {
    try {
      final data = await client
          .from('destinos_lugares')
          .select('*, categorias(*)')
          .eq('id', id)
          .maybeSingle();
      return data == null ? null : DestinoLugar.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<DestinoLugar> createPlace(DestinoLugar place) async {
    final payload = place.toMap();
    payload['id_usuario'] = currentUser?.id;
    final data = await client
        .from('destinos_lugares')
        .insert(payload)
        .select('*, categorias(*)')
        .single();
    return DestinoLugar.fromMap(data);
  }

  Future<DestinoLugar> updatePlace(DestinoLugar place) async {
    final data = await client
        .from('destinos_lugares')
        .update(place.toMap())
        .eq('id', place.id)
        .select('*, categorias(*)')
        .single();
    return DestinoLugar.fromMap(data);
  }

  Future<void> deletePlace(String id) async {
    await client.from('destinos_lugares').delete().eq('id', id);
  }

  Future<void> setPlaceActive(String id, bool activo) async {
    await client
        .from('destinos_lugares')
        .update({'activo': activo}).eq('id', id);
  }

  // ==========================================
  // FAVORITOS
  // ==========================================
  Future<Set<String>> getFavoritosIds(String userId) async {
    try {
      final data = await client
          .from('favoritos')
          .select('id_destino')
          .eq('id_usuario', userId);
      return (data as List)
          .map((e) => e['id_destino'].toString())
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setFavorito({
    required String userId,
    required String idDestino,
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      await client.from('favoritos').upsert({
        'id_usuario': userId,
        'id_destino': idDestino,
      }, onConflict: 'id_usuario,id_destino');
    } else {
      await client
          .from('favoritos')
          .delete()
          .eq('id_usuario', userId)
          .eq('id_destino', idDestino);
    }
  }

  // ==========================================
  // RESEÑAS
  // ==========================================
  Future<List<Resena>> getResenas(String idDestino) async {
    try {
      final data = await client
          .from('resenas')
          .select('*, usuarios(nombre, avatar_url)')
          .eq('id_destino', idDestino)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => Resena.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Crea o actualiza la reseña del usuario actual (una por lugar).
  Future<void> saveResena({
    required String idDestino,
    required int calificacion,
    required String comentario,
  }) async {
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para publicar una reseña.';

    await client.from('resenas').upsert({
      'id_destino': idDestino,
      'id_usuario': user.id,
      'calificacion': calificacion,
      'comentario': comentario.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id_destino,id_usuario');
  }

  Future<void> deleteResena(int id) async {
    await client.from('resenas').delete().eq('id', id);
  }

  // ==========================================
  // RESERVAS
  // ==========================================
  /// Crea una solicitud de reserva en estado "En espera".
  ///
  /// El negocio es quien decide si la acepta o la rechaza.
  Future<void> crearReserva({
    required String idDestino,
    required DateTime fechaHora,
    required int cantidadPersonas,
    required double precioUnitario,
    required double total,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AppMessageException(
        'Debes iniciar sesión para realizar una reserva.',
      );
    }
    if (idDestino.trim().isEmpty) {
      throw const AppMessageException(
        'No pudimos identificar el lugar. Vuelve a intentarlo.',
      );
    }
    if (fechaHora.isBefore(DateTime.now())) {
      throw const AppMessageException(
        'La fecha y la hora de la reserva deben ser posteriores al momento actual.',
      );
    }
    if (cantidadPersonas < 1) {
      throw const AppMessageException(
        'Selecciona al menos una persona para la reserva.',
      );
    }
    if (precioUnitario < 0 || total < 0) {
      throw const AppMessageException(
        'El precio de la reserva no es válido.',
      );
    }

    final fecha = _fechaCorta(fechaHora);
    final hora = _horaCorta(fechaHora);

    final base = <String, dynamic>{
      'id_destino': idDestino,
      'id_turista': user.id,
      'cantidad_personas': cantidadPersonas,
      'precio_unitario': precioUnitario,
      'total': total,
    };

    try {
      await client.from('reservas').insert({
        ...base,
        'fecha_reserva': fecha,
        'hora_reserva': hora,
        'estado': ReservationStatus.pendiente.dbValue,
      });
      return;
    } on PostgrestException catch (e) {
      // Compatibilidad con bases de datos que aún no tienen la migración de
      // reservas: se guarda la hora dentro de fecha_reserva.
      if (!_faltaColumna(e, 'hora_reserva') && !_estadoNoPermitido(e)) {
        rethrow;
      }
    }

    await client.from('reservas').insert({
      ...base,
      'fecha_reserva': '${fecha}T$hora:00',
      'estado': 'Pendiente',
    });
  }

  Future<List<Reserva>> getMisReservas() async {
    final user = currentUser;
    if (user == null) {
      throw const AppMessageException(
        'Debes iniciar sesión para ver tus reservas.',
      );
    }

    final data = await client
        .from('reservas')
        .select('*, destinos_lugares(nombre, imagen_principal, direccion)')
        .eq('id_turista', user.id)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reserva.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reserva>> getReservasNegocio(String ownerId) async {
    final data = await client
        .from('reservas')
        .select(
            '*, destinos_lugares!inner(nombre, imagen_principal, direccion, id_usuario), usuarios(nombre, email, telefono)')
        .eq('destinos_lugares.id_usuario', ownerId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reserva.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reserva>> getAllReservas() async {
    final data = await client
        .from('reservas')
        .select(
            '*, destinos_lugares(nombre, imagen_principal, direccion, id_usuario), usuarios(nombre, email, telefono)')
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reserva.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Cambia el estado de una reserva. Solo el negocio dueño del lugar o un
  /// administrador deberían poder hacerlo (lo controlan las políticas de la
  /// base de datos).
  Future<void> updateReservaEstado(
    String id,
    ReservationStatus estado, {
    String? motivoRechazo,
  }) async {
    if (id.trim().isEmpty) {
      throw const AppMessageException(
        'No pudimos identificar la reserva. Actualiza la pantalla e inténtalo de nuevo.',
      );
    }

    final motivo = estado == ReservationStatus.rechazada
        ? (motivoRechazo ?? '').trim()
        : null;

    try {
      await client.from('reservas').update({
        'estado': estado.dbValue,
        if (motivo != null) 'motivo_rechazo': motivo,
      }).eq('id', id);
      return;
    } on PostgrestException catch (e) {
      final sinMotivo = _faltaColumna(e, 'motivo_rechazo');
      if (!sinMotivo && !_estadoNoPermitido(e)) rethrow;

      final legacy = _estadoLegacy(estado);
      if (legacy == null) {
        throw const AppMessageException(
          'La base de datos necesita la actualización de reservas para usar este estado. Contacta al administrador.',
        );
      }

      await client
          .from('reservas')
          .update({'estado': legacy}).eq('id', id);
    }
  }

  Future<void> cancelarReserva(String id) =>
      updateReservaEstado(id, ReservationStatus.cancelada);

  Future<void> deleteReserva(String id) async {
    if (id.trim().isEmpty) {
      throw const AppMessageException(
        'No pudimos identificar la reserva que deseas eliminar.',
      );
    }
    await client.from('reservas').delete().eq('id', id);
  }

  static String _fechaCorta(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _horaCorta(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static bool _faltaColumna(PostgrestException error, String column) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST204' ||
        (message.contains(column.toLowerCase()) &&
            (message.contains('column') || message.contains('could not find')));
  }

  static bool _estadoNoPermitido(PostgrestException error) {
    return error.code == '23514' ||
        error.message.toLowerCase().contains('reservas_estado_check');
  }

  static String? _estadoLegacy(ReservationStatus estado) {
    switch (estado) {
      case ReservationStatus.pendiente:
        return 'Pendiente';
      case ReservationStatus.aceptada:
        return 'Confirmada';
      case ReservationStatus.completada:
        return 'Completada';
      case ReservationStatus.cancelada:
        return 'Cancelada';
      case ReservationStatus.rechazada:
        return null;
    }
  }

  // ==========================================
  // TIENDA DE SOUVENIRS Y PEDIDOS
  // ==========================================
  /// Catálogo de productos activos de la tienda.
  Future<List<ProductModel>> fetchProducts() async {
    final data = await client
        .from('productos')
        .select()
        .eq('activo', true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea el pedido y su detalle en una sola transacción.
  Future<OrderModel> crearPedido({
    required List<CartItem> items,
    String? direccionEntrega,
    String? telefonoContacto,
    String? notas,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AppMessageException(
        'Debes iniciar sesión para finalizar tu compra.',
      );
    }
    if (items.isEmpty) {
      throw const AppMessageException(
        'Tu carrito está vacío. Agrega productos antes de continuar.',
      );
    }

    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    for (final item in items) {
      if (!uuid.hasMatch(item.product.id)) {
        throw const AppMessageException(
          'Uno de los productos de tu carrito ya no está disponible. '
          'Elimínalo y vuelve a intentarlo.',
        );
      }
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    try {
      final data = await client.rpc('crear_pedido_completo', params: {
        'p_id_turista': user.id,
        'p_total': total,
        'p_direccion': (direccionEntrega ?? '').trim(),
        'p_telefono': (telefonoContacto ?? '').trim(),
        'p_notas': (notas ?? '').trim(),
        'p_items': items.map((item) => item.toMap()).toList(),
      });

      final map = (data as Map).cast<String, dynamic>();
      final idPedido = map['id_pedido']?.toString() ?? '';

      return OrderModel(
        id: idPedido,
        idTurista: user.id,
        total: (map['total'] as num?)?.toDouble() ?? total,
        estado: 'Pendiente',
        metodoPago: 'QR_SIMPLE',
        codigoReferencia: map['codigo_referencia']?.toString() ?? '',
        direccionEntrega: direccionEntrega,
        telefonoContacto: telefonoContacto,
        notas: notas,
        createdAt: DateTime.now(),
        items: [
          for (final item in items)
            OrderItemModel(
              id: 0,
              idPedido: idPedido,
              idProducto: item.product.id,
              nombreProducto: item.product.nombre,
              cantidad: item.quantity,
              precioUnitario: item.product.precio,
              subtotal: item.subtotal,
            ),
        ],
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' ||
          e.message.toLowerCase().contains('crear_pedido_completo')) {
        throw const AppMessageException(
          'La tienda necesita una actualización en la base de datos. '
          'Contacta al administrador.',
        );
      }
      rethrow;
    }
  }

  /// Pedidos del usuario actual, con el detalle de cada uno.
  Future<List<OrderModel>> getMisPedidos() async {
    final user = currentUser;
    if (user == null) {
      throw const AppMessageException(
        'Debes iniciar sesión para ver tus pedidos.',
      );
    }

    final data = await client
        .from('pedidos')
        .select('*, detalle_pedidos(*)')
        .eq('id_turista', user.id)
        .order('created_at', ascending: false);

    return (data as List).map((row) {
      final map = row as Map<String, dynamic>;
      final rawItems = (map['detalle_pedidos'] as List?) ?? const [];
      final items = rawItems
          .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
          .toList();
      return OrderModel.fromMap(map, items);
    }).toList();
  }

  // ==========================================
  // ADMINISTRACIÓN
  // ==========================================
  Future<List<AppUserProfile>> adminGetUsers() async {
    final data = await client
        .from('usuarios')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => AppUserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> adminUpdateUser(String id, Map<String, dynamic> fields) async {
    await client.from('usuarios').update(fields).eq('id', id);
  }

  Future<void> adminDeleteUser(String id) async {
    try {
      await client.rpc('admin_eliminar_usuario', params: {'p_id': id});
    } catch (_) {
      // Si la función aún no está instalada, al menos se elimina el perfil.
      await client.from('usuarios').delete().eq('id', id);
    }
  }

  // ==========================================
  // TRANSPORTE PÚBLICO (MICROS)
  // ==========================================
  Future<List<NearbyMicroLine>> getMicrosCercanos({
    required double lat,
    required double lng,
    double distanciaMetros = 700,
  }) async {
    try {
      final data = await client.rpc('obtener_micros_cercanos', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_distancia_metros': distanciaMetros,
      });
      return (data as List)
          .map((e) => NearbyMicroLine.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MicroRouteSuggestion>> planificarRutaMicros({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    double distanciaMetros = 700,
  }) async {
    try {
      final data = await client.rpc('planificar_ruta_micros', params: {
        'o_lat': origenLat,
        'o_lng': origenLng,
        'd_lat': destinoLat,
        'd_lng': destinoLng,
        'p_dist': distanciaMetros,
      });
      return (data as List)
          .map((e) => MicroRouteSuggestion.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, MicroLineInfo>> getLineasInfo(Set<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final data = await client
          .from('lineas_micros')
          .select()
          .inFilter('id', ids.toList());
      final result = <String, MicroLineInfo>{};
      for (final row in data as List) {
        final info = MicroLineInfo.fromMap(row as Map<String, dynamic>);
        result[info.id] = info;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<List<List<LatLngPoint>>> getLineaTrazado(String lineaId) async {
    try {
      final data = await client
          .from('tramos_micros')
          .select('coordenadas, sentido')
          .eq('id_linea', lineaId)
          .order('sentido', ascending: true);
      final result = <List<LatLngPoint>>[];
      for (final row in data as List) {
        final points = _parseGeoJsonCoordinates(row['coordenadas']);
        if (points.isNotEmpty) result.add(points);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  List<LatLngPoint> _parseGeoJsonCoordinates(dynamic raw) {
    final points = <LatLngPoint>[];

    void addPair(dynamic pair) {
      if (pair is List && pair.length >= 2) {
        final lng = (pair[0] as num?)?.toDouble();
        final lat = (pair[1] as num?)?.toDouble();
        if (lat != null && lng != null) points.add(LatLngPoint(lat, lng));
      }
    }

    void walk(dynamic node) {
      if (node is Map) {
        if (node['coordinates'] != null) {
          walk(node['coordinates']);
        }
      } else if (node is List) {
        if (node.isEmpty) return;
        if (node.first is num && node.length >= 2) {
          addPair(node);
        } else {
          for (final child in node) {
            walk(child);
          }
        }
      }
    }

    walk(raw);
    return points;
  }

  String _handleAuthException(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('user already registered') ||
        message.contains('already registered')) {
      return 'Este correo ya está registrado. Inicia sesión.';
    }
    if (message.contains('password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirma tu correo electrónico antes de iniciar sesión.';
    }
    return e.message;
  }
}

/// Punto simple usado para dibujar los trazados de las líneas de micro.
class LatLngPoint {
  final double latitude;
  final double longitude;
  const LatLngPoint(this.latitude, this.longitude);
}
