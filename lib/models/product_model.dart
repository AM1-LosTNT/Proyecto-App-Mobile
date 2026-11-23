class ProductModel {
  final String id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int stock;
  final String imagenUrl;
  final String categoria;
  final bool activo;

  ProductModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stock,
    required this.imagenUrl,
    this.categoria = 'souvenir',
    this.activo = true,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      imagenUrl: map['imagen_url'] ?? '',
      categoria: map['categoria'] ?? 'souvenir',
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'activo': activo,
    };
  }
}

