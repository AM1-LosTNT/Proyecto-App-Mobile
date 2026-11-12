class AppUserProfile {
  final String id;
  final String nombre;
  final String email;
  final String rol; // 'user' | 'business' | 'admin'
  final String avatarUrl;
  final String portadaUrl;
  final String nombreNegocio;
  final String telefono;

  const AppUserProfile({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.avatarUrl = '',
    this.portadaUrl = '',
    this.nombreNegocio = '',
    this.telefono = '',
  });

  bool get isAdmin => rol == 'admin';
  bool get isBusiness => rol == 'business';
  bool get isTourist => !isAdmin && !isBusiness;

  String get rolLabel {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'business':
        return 'Dueño de negocio';
      default:
        return 'Turista';
    }
  }

  String get inicial => nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'T';

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    final rol = map['rol']?.toString();
    return AppUserProfile(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? 'Viajero',
      email: map['email']?.toString() ?? '',
      rol: (rol == 'admin' || rol == 'business') ? rol! : 'user',
      avatarUrl: map['avatar_url']?.toString() ?? '',
      portadaUrl: map['portada_url']?.toString() ?? '',
      nombreNegocio: map['nombre_negocio']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
    );
  }

  AppUserProfile copyWith({
    String? nombre,
    String? email,
    String? rol,
    String? avatarUrl,
    String? portadaUrl,
    String? nombreNegocio,
    String? telefono,
  }) {
    return AppUserProfile(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      portadaUrl: portadaUrl ?? this.portadaUrl,
      nombreNegocio: nombreNegocio ?? this.nombreNegocio,
      telefono: telefono ?? this.telefono,
    );
  }
}
