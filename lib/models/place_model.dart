import 'package:latlong2/latlong.dart';

class DestinoLugar {
  final String id;
  final String? idUsuario;
  final int? idCategoria;
  final String nombre;
  final String tipo; // 'hotel', 'restaurant', 'attraction', 'hospital'
  final String descripcion;
  final String direccion;
  final String telefono;
  final double precio;
  final String precioTexto;
  final double rating;
  final int totalReviews;
  final String imagenPrincipal;
  final List<String> imagenes;
  final List<String> serviciosIncluidos;
  final double latitud;
  final double longitud;
  final bool activo;
  final String? categoriaNombre;

  DestinoLugar({
    required this.id,
    this.idUsuario,
    this.idCategoria,
    required this.nombre,
    required this.tipo,
    required this.descripcion,
    required this.direccion,
    required this.telefono,
    required this.precio,
    required this.precioTexto,
    required this.rating,
    required this.totalReviews,
    required this.imagenPrincipal,
    required this.imagenes,
    required this.serviciosIncluidos,
    required this.latitud,
    required this.longitud,
    this.activo = true,
    this.categoriaNombre,
  });

  LatLng get ubicacion => LatLng(latitud, longitud);

  factory DestinoLugar.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    String? categoriaNombre;
    final categorias = map['categorias'];
    if (categorias is Map) {
      categoriaNombre = categorias['nombre']?.toString();
    } else if (categorias is List && categorias.isNotEmpty) {
      final first = categorias.first;
      if (first is Map) categoriaNombre = first['nombre']?.toString();
    }

    return DestinoLugar(
      id: map['id']?.toString() ?? '',
      idUsuario: map['id_usuario']?.toString(),
      idCategoria: (map['id_categoria'] as num?)?.toInt(),
      nombre: map['nombre']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'attraction',
      descripcion: map['descripcion']?.toString() ?? '',
      direccion: map['direccion']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      precioTexto: map['precio_texto']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['total_reviews'] as num?)?.toInt() ?? 0,
      imagenPrincipal: map['imagen_principal']?.toString() ?? '',
      imagenes: parseList(map['imagenes']),
      serviciosIncluidos: parseList(map['servicios_incluidos']),
      latitud: (map['latitud'] as num?)?.toDouble() ?? -17.7833,
      longitud: (map['longitud'] as num?)?.toDouble() ?? -63.1821,
      activo: map['activo'] as bool? ?? true,
      categoriaNombre: categoriaNombre,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      if (idUsuario != null) 'id_usuario': idUsuario,
      if (idCategoria != null) 'id_categoria': idCategoria,
      'nombre': nombre,
      'tipo': tipo,
      'descripcion': descripcion,
      'direccion': direccion,
      'telefono': telefono,
      'precio': precio,
      'precio_texto': precioTexto,
      'imagen_principal': imagenPrincipal,
      'imagenes': imagenes,
      'servicios_incluidos': serviciosIncluidos,
      'latitud': latitud,
      'longitud': longitud,
      'activo': activo,
    };
  }

  DestinoLugar copyWith({
    String? id,
    String? idUsuario,
    int? idCategoria,
    String? nombre,
    String? tipo,
    String? descripcion,
    String? direccion,
    String? telefono,
    double? precio,
    String? precioTexto,
    double? rating,
    int? totalReviews,
    String? imagenPrincipal,
    List<String>? imagenes,
    List<String>? serviciosIncluidos,
    double? latitud,
    double? longitud,
    bool? activo,
    String? categoriaNombre,
  }) {
    return DestinoLugar(
      id: id ?? this.id,
      idUsuario: idUsuario ?? this.idUsuario,
      idCategoria: idCategoria ?? this.idCategoria,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      precio: precio ?? this.precio,
      precioTexto: precioTexto ?? this.precioTexto,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      imagenPrincipal: imagenPrincipal ?? this.imagenPrincipal,
      imagenes: imagenes ?? this.imagenes,
      serviciosIncluidos: serviciosIncluidos ?? this.serviciosIncluidos,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      activo: activo ?? this.activo,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
    );
  }

  String get tipoLabel {
    switch (tipo.toLowerCase()) {
      case 'hotel':
        return 'Hotel';
      case 'restaurant':
        return 'Restaurante';
      case 'hospital':
        return 'Salud';
      case 'attraction':
        return 'Atracción';
      default:
        return tipo;
    }
  }
}

class CategoriaItem {
  final int id;
  final String slug;
  final String nombre;
  final String descripcion;
  final String icono;

  CategoriaItem({
    required this.id,
    required this.slug,
    this.descripcion = '',
    required this.nombre,
    this.icono = '',
  });

  factory CategoriaItem.fromMap(Map<String, dynamic> map) {
    return CategoriaItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? 'all',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      icono: map['icono']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': icono,
    };
  }
}
