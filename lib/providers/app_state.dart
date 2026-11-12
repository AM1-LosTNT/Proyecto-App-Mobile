import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_model.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  final SupabaseService service = SupabaseService();

  StreamSubscription<AuthState>? _authSubscription;

  User? _user;
  AppUserProfile? _profile;
  bool _initialized = false;
  bool _loadingData = false;
  String? _error;

  List<CategoriaItem> _categorias = [];
  List<DestinoLugar> _destinos = [];
  Set<String> _favoritos = {};
  List<Map<String, dynamic>> _misReservas = [];
  List<Map<String, dynamic>> _reservasNegocio = [];

  User? get user => _user;
  AppUserProfile? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get initialized => _initialized;
  bool get loadingData => _loadingData;
  String? get error => _error;

  List<CategoriaItem> get categorias => List.unmodifiable(_categorias);
  List<DestinoLugar> get destinos => List.unmodifiable(_destinos);
  Set<String> get favoritos => Set.unmodifiable(_favoritos);
  List<Map<String, dynamic>> get misReservas => List.unmodifiable(_misReservas);
  List<Map<String, dynamic>> get reservasNegocio =>
      List.unmodifiable(_reservasNegocio);

  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get isBusiness => _profile?.isBusiness ?? false;
  bool get isTourist => !isAdmin && !isBusiness;

  String get displayName =>
      _profile?.nombre ??
      _user?.userMetadata?['nombre']?.toString() ??
      _user?.email?.split('@').first ??
      'Viajero';

  Future<void> initialize() async {
    _authSubscription = service.authStateChanges.listen(_handleAuthChange);
    _user = service.currentUser;

    if (_user != null) {
      await _loadUserData();
    } else {
      await _loadPublicData();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _handleAuthChange(AuthState state) async {
    if (state.event == AuthChangeEvent.signedOut) {
      _user = null;
      _profile = null;
      _favoritos = {};
      _misReservas = [];
      _reservasNegocio = [];
      notifyListeners();
      return;
    }

    final newUser = state.session?.user;
    if (newUser == null) return;

    final isNewLogin = _user?.id != newUser.id ||
        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession;

    if (isNewLogin) {
      _user = newUser;
      await _loadUserData();
      notifyListeners();
    }
  }

  Future<void> _loadPublicData() async {
    final results = await Future.wait<dynamic>([
      service.getCategorias(),
      service.getDestinos(includeInactive: true),
    ]);
    _categorias = results[0] as List<CategoriaItem>;
    _destinos = results[1] as List<DestinoLugar>;
  }

  Future<void> _loadUserData() async {
    final current = _user;
    if (current == null) return;

    _loadingData = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _loadProfile(current),
        service.getFavoritosIds(current.id),
        service.getDestinos(includeInactive: true),
        service.getCategorias(),
      ]);

      _profile = results[0] as AppUserProfile?;
      _favoritos = results[1] as Set<String>;
      _destinos = results[2] as List<DestinoLugar>;
      _categorias = results[3] as List<CategoriaItem>;
    } catch (e) {
      _error = 'No se pudieron cargar los datos. Desliza para reintentar.';
      debugPrint('Error cargando datos: $e');
    } finally {
      _loadingData = false;
      notifyListeners();
    }
  }

  Future<AppUserProfile?> _loadProfile(User user) async {
    AppUserProfile? profile;

    // El trigger de la base de datos puede tardar unos milisegundos.
    for (var attempt = 0; attempt < 3; attempt++) {
      profile = await service.getUserProfile(user.id);
      if (profile != null) break;
      await Future.delayed(const Duration(milliseconds: 350));
    }

    if (profile == null) {
      final meta = user.userMetadata ?? const <String, dynamic>{};
      final role = meta['rol'] == 'business' ? 'business' : 'user';
      try {
        profile = await service.ensureProfile(
          userId: user.id,
          nombre: meta['nombre']?.toString() ??
              user.email?.split('@').first ??
              'Viajero',
          email: user.email ?? '',
          rol: role,
          nombreNegocio: meta['nombre_negocio']?.toString(),
          telefono: meta['telefono']?.toString(),
        );
      } catch (_) {
        profile = service.profileFromSession(user);
      }
    }

    return profile;
  }

  Future<void> refreshAll() async {
    if (_user != null) {
      await _loadUserData();
    } else {
      await _loadPublicData();
      notifyListeners();
    }
  }

  Future<void> refreshDestinos() async {
    try {
      _destinos = await service.getDestinos(includeInactive: true);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    final current = _user;
    if (current == null) return;
    _profile = await _loadProfile(current);
    notifyListeners();
  }

  Future<void> refreshReservas() async {
    if (_user == null) return;
    final results = await Future.wait<dynamic>([
      service.getMisReservas(),
      isBusiness ? service.getReservasNegocio(_user!.id) : Future.value(<Map<String, dynamic>>[]),
    ]);
    _misReservas = results[0] as List<Map<String, dynamic>>;
    _reservasNegocio = results[1] as List<Map<String, dynamic>>;
    notifyListeners();
  }

  DestinoLugar? placeById(String id) {
    for (final place in _destinos) {
      if (place.id == id) return place;
    }
    return null;
  }

  List<DestinoLugar> get favoriteDestinos =>
      _destinos.where((d) => _favoritos.contains(d.id)).toList();

  List<DestinoLugar> get myPlaces {
    if (_user == null) return [];
    return _destinos.where((d) => d.idUsuario == _user!.id).toList();
  }

  List<CategoriaItem> get categoriasSinTodo =>
      _categorias.where((c) => c.slug != 'all').toList();

  List<DestinoLugar> filterDestinos({
    String categorySlug = 'all',
    String query = '',
    String? tipo,
  }) {
    Iterable<DestinoLugar> items = _destinos.where((d) => d.activo);

    if (tipo != null && tipo.isNotEmpty) {
      items = items.where((d) => d.tipo.toLowerCase() == tipo.toLowerCase());
    }

    if (categorySlug.isNotEmpty && categorySlug != 'all') {
      CategoriaItem? categoria;
      for (final c in _categorias) {
        if (c.slug == categorySlug) {
          categoria = c;
          break;
        }
      }
      final slug = categorySlug.toLowerCase();
      items = items.where((d) {
        final matchesId = categoria != null && d.idCategoria == categoria.id;
        final matchesNombre =
            (d.categoriaNombre ?? '').toLowerCase().contains(slug);
        final matchesTipo = d.tipo.toLowerCase() == slug;
        final slugContieneNombre =
            categoria != null && slug.contains(categoria.slug);
        return matchesId || matchesNombre || matchesTipo || slugContieneNombre;
      });
    }

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((d) {
        return d.nombre.toLowerCase().contains(q) ||
            d.direccion.toLowerCase().contains(q) ||
            d.descripcion.toLowerCase().contains(q) ||
            (d.categoriaNombre ?? '').toLowerCase().contains(q) ||
            d.tipo.toLowerCase().contains(q);
      });
    }

    final list = items.toList();
    list.sort((a, b) => b.rating.compareTo(a.rating));
    return list;
  }

  bool isFavorite(String destinoId) => _favoritos.contains(destinoId);

  Future<void> toggleFavorite(DestinoLugar destino) async {
    final current = _user;
    if (current == null) throw 'Inicia sesión para guardar lugares.';

    final wasFavorite = _favoritos.contains(destino.id);
    if (wasFavorite) {
      _favoritos.remove(destino.id);
    } else {
      _favoritos.add(destino.id);
    }
    notifyListeners();

    try {
      await service.setFavorito(
        userId: current.id,
        idDestino: destino.id,
        isFavorite: !wasFavorite,
      );
    } catch (e) {
      // Revertimos el cambio optimista si el servidor falló.
      if (wasFavorite) {
        _favoritos.add(destino.id);
      } else {
        _favoritos.remove(destino.id);
      }
      notifyListeners();
      rethrow;
    }
  }

  void applyLocalRating(String destinoId, double rating, int totalReviews) {
    final index = _destinos.indexWhere((d) => d.id == destinoId);
    if (index == -1) return;
    _destinos[index] = _destinos[index].copyWith(
      rating: rating,
      totalReviews: totalReviews,
    );
    notifyListeners();
  }

  void upsertPlace(DestinoLugar place) {
    final index = _destinos.indexWhere((d) => d.id == place.id);
    if (index == -1) {
      _destinos.insert(0, place);
    } else {
      _destinos[index] = place;
    }
    notifyListeners();
  }

  void removePlaceById(String id) {
    _destinos.removeWhere((d) => d.id == id);
    _favoritos.remove(id);
    notifyListeners();
  }

  Future<void> saveProfile({
    String? nombre,
    String? telefono,
    String? nombreNegocio,
    String? avatarUrl,
    String? portadaUrl,
  }) async {
    final current = _user;
    if (current == null) throw 'Debes iniciar sesión.';

    final updated = await service.updateProfile(
      userId: current.id,
      nombre: nombre,
      telefono: telefono,
      nombreNegocio: nombreNegocio,
      avatarUrl: avatarUrl,
      portadaUrl: portadaUrl,
    );

    _profile = updated;

    try {
      await service.client.auth.updateUser(UserAttributes(data: {
        if (nombre != null) 'nombre': nombre.trim(),
        if (telefono != null) 'telefono': telefono.trim(),
        if (nombreNegocio != null) 'nombre_negocio': nombreNegocio.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (portadaUrl != null) 'portada_url': portadaUrl,
      }));
    } catch (_) {
      // El perfil público ya quedó actualizado; los metadatos son secundarios.
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    await service.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
