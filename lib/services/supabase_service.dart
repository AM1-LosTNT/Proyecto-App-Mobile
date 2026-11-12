import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/micro_route.dart';
import '../models/place_model.dart';
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
  Future<void> crearReserva({
    required String idDestino,
    required String fechaReserva,
    required int cantidadPersonas,
    required double precioUnitario,
    required double total,
  }) async {
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para reservar.';

    await client.from('reservas').insert({
      'id_destino': idDestino,
      'id_turista': user.id,
      'fecha_reserva': fechaReserva,
      'cantidad_personas': cantidadPersonas,
      'precio_unitario': precioUnitario,
      'total': total,
      'estado': 'Confirmada',
    });
  }

  Future<List<Map<String, dynamic>>> getMisReservas() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final data = await client
          .from('reservas')
          .select('*, destinos_lugares(nombre, imagen_principal, direccion)')
          .eq('id_turista', user.id)
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReservasNegocio(String ownerId) async {
    try {
      final data = await client
          .from('reservas')
          .select(
              '*, destinos_lugares!inner(nombre, imagen_principal, id_usuario), usuarios(nombre, email, telefono)')
          .eq('destinos_lugares.id_usuario', ownerId)
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllReservas() async {
    try {
      final data = await client
          .from('reservas')
          .select(
              '*, destinos_lugares(nombre, imagen_principal, id_usuario), usuarios(nombre, email, telefono)')
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateReservaEstado(String id, String estado) async {
    await client.from('reservas').update({'estado': estado}).eq('id', id);
  }

  Future<void> deleteReserva(String id) async {
    await client.from('reservas').delete().eq('id', id);
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
