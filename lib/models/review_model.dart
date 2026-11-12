class Resena {
  final int id;
  final String idDestino;
  final String idUsuario;
  final String nombreUsuario;
  final String avatarUsuario;
  final int calificacion;
  final String comentario;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Resena({
    required this.id,
    required this.idDestino,
    required this.idUsuario,
    required this.nombreUsuario,
    required this.avatarUsuario,
    required this.calificacion,
    required this.comentario,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_destino': idDestino,
      'id_usuario': idUsuario,
      'calificacion': calificacion,
      'comentario': comentario,
    };
  }

  factory Resena.fromMap(Map<String, dynamic> map) {
    String nombre = 'Turista';
    String avatar = '';

    final usuarios = map['usuarios'];
    if (usuarios is Map) {
      nombre = usuarios['nombre']?.toString() ?? 'Turista';
      avatar = usuarios['avatar_url']?.toString() ?? '';
    }

    return Resena(
      id: (map['id'] as num?)?.toInt() ?? 0,
      idDestino: map['id_destino']?.toString() ?? '',
      idUsuario: map['id_usuario']?.toString() ?? '',
      nombreUsuario: nombre,
      avatarUsuario: avatar,
      calificacion: (map['calificacion'] as num?)?.toInt() ?? 5,
      comentario: map['comentario']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}
