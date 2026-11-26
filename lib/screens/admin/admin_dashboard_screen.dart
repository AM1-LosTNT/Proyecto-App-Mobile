import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/pago_qr_model.dart';
import '../../models/place_model.dart';
import '../../models/product_model.dart';
import '../../models/reserva.dart';
import '../../models/user_profile.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../../services/yape_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reservation_status_chip.dart';
import '../business/place_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = SupabaseService();

  List<AppUserProfile> _users = [];
  List<DestinoLugar> _places = [];
  List<CategoriaItem> _categorias = [];
  List<Reserva> _reservas = [];
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<PaymentRecordModel> _payments = [];
  List<PagoQrModel> _pagosQr = [];
  bool _loading = true;

  Timer? _pagosDebounce;
  Timer? _pagosPoll;
  final _yapeService = YapeNotificationService();

  /// Evita repetir el aviso de error de pedidos en cada refresco.
  DateTime? _lastOrdersErrorSnack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AppState>().isAdmin) {
        _yapeService.init();
        _yapeService.addListener(_onYapeEvent);

        // Respaldo por si Realtime se cae: refresco silencioso cada 20 s.
        _pagosPoll = Timer.periodic(const Duration(seconds: 20), (_) {
          if (!mounted) return;
          _reloadPagosQr();
          _reloadOrders();
        });
      }
      _loadAll();
    });
  }

  /// Refresca cobros y pedidos cuando Realtime avisa de un cambio.
  void _onYapeEvent() {
    _pagosDebounce?.cancel();
    _pagosDebounce = Timer(
      const Duration(milliseconds: 700),
      () {
        _reloadPagosQr();
        _reloadOrders();
      },
    );
  }

  Future<void> _reloadPagosQr() async {
    try {
      final pagos = await _service.adminGetAllPagosQr();
      if (mounted) setState(() => _pagosQr = pagos);
    } catch (_) {}
  }

  Future<void> _reloadOrders() async {
    try {
      final orders = await _service.adminGetAllOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
        });
      }
    } catch (e) {
      // Antes se ignoraba el error y el admin veía "Pedidos (0)" sin saber por
      // qué. Ahora se avisa una vez por minuto para no llenar la pantalla.
      final now = DateTime.now();
      final last = _lastOrdersErrorSnack;
      if (last == null || now.difference(last) > const Duration(minutes: 1)) {
        _lastOrdersErrorSnack = now;
        _snack(
          'No se pudieron cargar los pedidos: $e\n'
          'Ejecuta supabase/parche_admin_pedidos.sql si persiste.',
        );
      }
    }
  }

  @override
  void dispose() {
    _pagosDebounce?.cancel();
    _pagosPoll?.cancel();
    _yapeService.removeListener(_onYapeEvent);
    super.dispose();
  }

  /// Carga un futuro y, si falla, devuelve un valor vacío en lugar de tumbar
  /// toda la pantalla. Así un problema puntual (p. ej. RLS de pedidos) no deja
  /// el panel completo en blanco.
  Future<T> _safe<T>(Future<T> future, T fallback) async {
    try {
      return await future;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    Object? ordersError;
    final results = await Future.wait<dynamic>([
      _safe(_service.adminGetUsers(), <AppUserProfile>[]),
      _safe(_service.getDestinos(includeInactive: true), <DestinoLugar>[]),
      _safe(_service.getCategorias(), <CategoriaItem>[]),
      _safe(_service.getAllReservas(), <Reserva>[]),
      _safe(_service.adminGetProducts(includeInactive: true), <ProductModel>[]),
      () async {
        try {
          return await _service.adminGetAllOrders();
        } catch (e) {
          ordersError = e;
          return <OrderModel>[];
        }
      }(),
      _safe(_service.adminGetAllPayments(), <PaymentRecordModel>[]),
      _safe(_service.adminGetAllPagosQr(), <PagoQrModel>[]),
    ]);

    if (!mounted) return;
    setState(() {
      _users = results[0] as List<AppUserProfile>;
      _places = results[1] as List<DestinoLugar>;
      _categorias = results[2] as List<CategoriaItem>;
      _reservas = results[3] as List<Reserva>;
      _products = results[4] as List<ProductModel>;
      _orders = results[5] as List<OrderModel>;
      _payments = results[6] as List<PaymentRecordModel>;
      _pagosQr = results[7] as List<PagoQrModel>;
      _loading = false;
    });

    if (ordersError != null) {
      _snack(
        'No se pudieron cargar los pedidos: $ordersError\n'
        'Ejecuta supabase/parche_admin_pedidos.sql si persiste.',
      );
    }
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

  Future<void> _editUser(AppUserProfile user) async {
    final nombre = TextEditingController(text: user.nombre);
    final telefono = TextEditingController(text: user.telefono);
    final negocio = TextEditingController(text: user.nombreNegocio);
    var rol = user.rol;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar ${user.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: negocio,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del negocio'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Turista')),
                    DropdownMenuItem(
                        value: 'business', child: Text('Dueño de negocio')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => rol = value ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await _service.adminUpdateUser(user.id, {
        'nombre': nombre.text.trim(),
        'telefono': telefono.text.trim(),
        'nombre_negocio': negocio.text.trim(),
        'rol': rol,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _loadAll();
      _snack('Usuario actualizado.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<void> _deleteUser(AppUserProfile user) async {
    final confirm = await _confirm(
      'Eliminar usuario',
      '¿Eliminar la cuenta de ${user.nombre}? Se eliminarán sus datos asociados.',
    );
    if (confirm != true) return;

    try {
      await _service.adminDeleteUser(user.id);
      await _loadAll();
      _snack('Usuario eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _deletePlace(DestinoLugar place) async {
    final confirm = await _confirm(
      'Eliminar lugar',
      '¿Eliminar "${place.nombre}" definitivamente?',
    );
    if (confirm != true) return;

    try {
      await _service.deletePlace(place.id);
      if (mounted) context.read<AppState>().removePlaceById(place.id);
      await _loadAll();
      _snack('Lugar eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _togglePlace(DestinoLugar place, bool active) async {
    try {
      await _service.setPlaceActive(place.id, active);
      if (!mounted) return;
      context.read<AppState>().upsertPlace(place.copyWith(activo: active));
      await _loadAll();
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<bool?> _confirm(
    String title,
    String content, {
    String confirmText = 'Eliminar',
    Color confirmColor = Colors.redAccent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategoria({CategoriaItem? categoria}) async {
    final nombre = TextEditingController(text: categoria?.nombre ?? '');
    final slug = TextEditingController(text: categoria?.slug ?? '');
    final descripcion =
        TextEditingController(text: categoria?.descripcion ?? '');
    final icono = TextEditingController(text: categoria?.icono ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoria == null ? 'Nueva categoría' : 'Editar categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: slug,
                decoration: const InputDecoration(
                    labelText: 'Identificador', hintText: 'ej. parques'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: icono,
                decoration:
                    const InputDecoration(labelText: 'Icono (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (nombre.text.trim().isEmpty || slug.text.trim().isEmpty) {
      _snack('Nombre e identificador son obligatorios.');
      return;
    }

    try {
      if (categoria == null) {
        await _service.createCategoria(
          nombre: nombre.text,
          slug: slug.text,
          descripcion: descripcion.text,
          icono: icono.text,
        );
      } else {
        await _service.updateCategoria(CategoriaItem(
          id: categoria.id,
          slug: slug.text.trim().toLowerCase(),
          nombre: nombre.text.trim(),
          descripcion: descripcion.text.trim(),
          icono: icono.text.trim(),
        ));
      }
      if (mounted) await context.read<AppState>().refreshAll();
      await _loadAll();
      _snack('Categoría guardada.', success: true);
    } catch (e) {
      _snack('No se pudo guardar: $e');
    }
  }

  Future<void> _deleteCategoria(CategoriaItem categoria) async {
    final confirm = await _confirm(
      'Eliminar categoría',
      '¿Eliminar "${categoria.nombre}"? Los lugares quedarán sin categoría.',
    );
    if (confirm != true) return;

    try {
      await _service.deleteCategoria(categoria.id);
      if (mounted) await context.read<AppState>().refreshAll();
      await _loadAll();
      _snack('Categoría eliminada.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _changeReservaEstado(String id, ReservationStatus estado) async {
    try {
      await _service.updateReservaEstado(id, estado);
      await _loadAll();
      _snack('Reserva actualizada.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar: $e');
    }
  }

  Future<void> _deleteReserva(String id) async {
    final confirm =
        await _confirm('Eliminar reserva', '¿Eliminar esta reserva?');
    if (confirm != true) return;

    try {
      await _service.deleteReserva(id);
      await _loadAll();
      _snack('Reserva eliminada.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  Future<void> _updateStock(String id, int newStock) async {
    if (newStock < 0) return;
    try {
      await _service.adminUpdateProductStock(id, newStock);
      setState(() {
        final idx = _products.indexWhere((p) => p.id == id);
        if (idx != -1) {
          final old = _products[idx];
          _products[idx] = ProductModel(
            id: old.id,
            nombre: old.nombre,
            descripcion: old.descripcion,
            precio: old.precio,
            stock: newStock,
            imagenUrl: old.imagenUrl,
            categoria: old.categoria,
            activo: old.activo,
          );
        }
      });
      _snack('Stock actualizado a $newStock.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar el stock: $e');
    }
  }

  Future<void> _changeProductPhoto(ProductModel product) async {
    final picker = ImagePicker();
    final urlController = TextEditingController(text: product.imagenUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Cambiar foto de "${product.nombre}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urlController.text.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    urlController.text,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('Vista previa no disponible'),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Subir desde galería'),
                onPressed: () async {
                  final xFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1024,
                    imageQuality: 85,
                  );
                  if (xFile != null) {
                    try {
                      final bytes = await xFile.readAsBytes();
                      final url = await _service.uploadImage(
                        bucket: 'imagenes',
                        folder: 'productos',
                        bytes: bytes,
                        fileName: xFile.name,
                      );
                      setDialogState(() {
                        urlController.text = url;
                      });
                    } catch (e) {
                      _snack('Error al subir imagen: $e');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'O pega la URL de la imagen',
                  hintText: 'https://...',
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, urlController.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || result == product.imagenUrl) return;

    try {
      await _service.adminUpdateProduct(product.id, {'imagen_url': result});
      await _loadAll();
      _snack('Foto de producto actualizada.', success: true);
    } catch (e) {
      _snack('No se pudo actualizar la imagen: $e');
    }
  }

  Future<void> _editProduct({ProductModel? product}) async {
    final isNew = product == null;
    final nombre = TextEditingController(text: product?.nombre ?? '');
    final descripcion = TextEditingController(text: product?.descripcion ?? '');
    final precio = TextEditingController(
      text: product != null ? product.precio.toString() : '',
    );
    final stock = TextEditingController(
      text: product != null ? product.stock.toString() : '10',
    );
    final imagenUrl = TextEditingController(text: product?.imagenUrl ?? '');
    var categoria = product?.categoria ?? 'souvenir';
    var activo = product?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Nuevo producto' : 'Editar ${product.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: precio,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Precio (Bs.) *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imagenUrl,
                        decoration: const InputDecoration(
                          labelText: 'URL de imagen',
                          hintText: 'https://...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Subir desde dispositivo',
                      onPressed: () async {
                        final picker = ImagePicker();
                        final xFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          imageQuality: 85,
                        );
                        if (xFile != null) {
                          try {
                            final bytes = await xFile.readAsBytes();
                            final url = await _service.uploadImage(
                              bucket: 'imagenes',
                              folder: 'productos',
                              bytes: bytes,
                              fileName: xFile.name,
                            );
                            setDialogState(() {
                              imagenUrl.text = url;
                            });
                          } catch (e) {
                            _snack('Error subiendo imagen: $e');
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(
                        value: 'souvenir', child: Text('Souvenirs')),
                    DropdownMenuItem(
                        value: 'ropa', child: Text('Ropa y Textiles')),
                    DropdownMenuItem(
                        value: 'accesorios', child: Text('Accesorios')),
                    DropdownMenuItem(
                        value: 'artesanias', child: Text('Artesanías')),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => categoria = val ?? 'souvenir'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Producto Activo',
                      style: TextStyle(fontSize: 14)),
                  value: activo,
                  onChanged: (val) => setDialogState(() => activo = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    if (nombre.text.trim().isEmpty ||
        double.tryParse(precio.text.trim()) == null) {
      _snack('El nombre y el precio válido son obligatorios.');
      return;
    }

    try {
      final pVal = double.parse(precio.text.trim());
      final sVal = int.tryParse(stock.text.trim()) ?? 0;
      final img = imagenUrl.text.trim().isNotEmpty
          ? imagenUrl.text.trim()
          : 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=600';

      if (isNew) {
        await _service.adminCreateProduct({
          'nombre': nombre.text.trim(),
          'descripcion': descripcion.text.trim(),
          'precio': pVal,
          'stock': sVal,
          'imagen_url': img,
          'categoria': categoria,
          'activo': activo,
        });
        _snack('Producto creado exitosamente.', success: true);
      } else {
        await _service.adminUpdateProduct(product.id, {
          'nombre': nombre.text.trim(),
          'descripcion': descripcion.text.trim(),
          'precio': pVal,
          'stock': sVal,
          'imagen_url': img,
          'categoria': categoria,
          'activo': activo,
        });
        _snack('Producto actualizado exitosamente.', success: true);
      }
      await _loadAll();
    } catch (e) {
      _snack('Error guardando producto: $e');
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await _confirm(
      'Eliminar producto',
      '¿Deseas eliminar "${product.nombre}"? Si ya tiene pedidos históricos, se recomienda desactivarlo en su lugar.',
      confirmText: 'Eliminar',
    );
    if (confirm != true) return;

    try {
      await _service.adminDeleteProduct(product.id);
      await _loadAll();
      _snack('Producto eliminado.', success: true);
    } catch (e) {
      _snack('No se pudo eliminar el producto: $e');
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final ref = order.codigoReferencia.isNotEmpty
        ? order.codigoReferencia
        : (order.id.length > 8 ? order.id.substring(0, 8) : order.id);
    final confirm = await _confirm(
      'Cancelar Pedido',
      '¿Estás seguro de cancelar el pedido #$ref por Bs. ${order.total.toStringAsFixed(2)}? Esta acción cancelará el pedido y rechazará pagos pendientes.',
      confirmText: 'Sí, Cancelar Pedido',
      confirmColor: Colors.redAccent,
    );
    if (confirm != true) return;

    try {
      await _service.adminUpdateOrderStatus(order.id, 'Cancelado');
      await _loadAll();
      _snack('Pedido cancelado.', success: true);
    } catch (e) {
      _snack('Error cancelando pedido: $e');
    }
  }

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    try {
      await _service.adminUpdateOrderStatus(order.id, newStatus);
      await _loadAll();
      _snack('Estado de pedido actualizado a $newStatus.', success: true);
    } catch (e) {
      _snack('Error actualizando pedido: $e');
    }
  }

  Future<void> _updatePaymentStatus(
      PaymentRecordModel payment, String newStatus) async {
    try {
      await _service.adminUpdatePaymentStatus(payment.id, newStatus);
      if (newStatus == 'Rechazado' && payment.idPedido != null) {
        await _service.adminUpdateOrderStatus(payment.idPedido!, 'Cancelado');
      }
      await _loadAll();
      _snack('Pago actualizado a $newStatus.', success: true);
    } catch (e) {
      _snack('Error actualizando pago: $e');
    }
  }

  /// Respaldo manual: el pago ya se completa solo con la notificación de Yape.
  /// Esto solo se usa si la notificación no llegó al teléfono.
  Future<void> _confirmarPagoManual(PagoQrModel pago) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text('Marcar pago como completado',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cobro #${pago.referenciaInterna}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monto: Bs. ${pago.montoEsperado.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if ((pago.pagadoPor ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Remitente: ${pago.pagadoPor}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Normalmente el pago se completa solo cuando llega la notificación '
              'de Yape. Usa esto únicamente si ya verificaste el saldo en tu '
              'banca y la notificación no llegó.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, marcar como pagado',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.adminConfirmarPagoManual(pago.id);
      await _reloadPagosQr();
      await _reloadOrders();
      _snack('Pago marcado como completado.', success: true);
    } catch (e) {
      _snack('No se pudo confirmar el pago: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Esta sección está disponible solo para administradores.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final negocios = _users.where((u) => u.isBusiness).length;

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Usuarios'),
              Tab(text: 'Lugares'),
              Tab(text: 'Categorías'),
              Tab(text: 'Reservas'),
              Tab(text: 'Tienda & Stock'),
              Tab(text: 'Pedidos & Pagos'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryColor))
            : TabBarView(
                children: [
                  _OverviewTab(
                    users: _users.length,
                    businesses: negocios,
                    places: _places.length,
                    categories: _categorias.length,
                    reservations: _reservas.length,
                    products: _products.length,
                    orders: _orders.length,
                    onRefresh: _loadAll,
                  ),
                  _UsersTab(
                    users: _users,
                    onEdit: _editUser,
                    onDelete: _deleteUser,
                  ),
                  _PlacesTab(
                    places: _places,
                    onEdit: (place) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceFormScreen(existing: place),
                        ),
                      ).then((_) => _loadAll());
                    },
                    onDelete: _deletePlace,
                    onToggle: _togglePlace,
                  ),
                  _CategoriesTab(
                    categorias: _categorias,
                    onCreate: () => _editCategoria(),
                    onEdit: (categoria) => _editCategoria(categoria: categoria),
                    onDelete: _deleteCategoria,
                  ),
                  _ReservationsTab(
                    reservas: _reservas,
                    onStatusChanged: _changeReservaEstado,
                    onDelete: _deleteReserva,
                  ),
                  _StoreStockTab(
                    products: _products,
                    onEdit: _editProduct,
                    onChangePhoto: _changeProductPhoto,
                    onUpdateStock: _updateStock,
                    onDelete: _deleteProduct,
                  ),
                  _OrdersPaymentsTab(
                    orders: _orders,
                    payments: _payments,
                    pagosQr: _pagosQr,
                    onCancelOrder: _cancelOrder,
                    onUpdateOrderStatus: _updateOrderStatus,
                    onUpdatePaymentStatus: _updatePaymentStatus,
                    onConfirmarPagoManual: _confirmarPagoManual,
                    onRefresh: _loadAll,
                  ),
                ],
              ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final int users;
  final int businesses;
  final int places;
  final int categories;
  final int reservations;
  final int products;
  final int orders;
  final Future<void> Function() onRefresh;

  const _OverviewTab({
    required this.users,
    required this.businesses,
    required this.places,
    required this.categories,
    required this.reservations,
    required this.products,
    required this.orders,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData('Usuarios', '$users', Icons.people_alt_rounded, Colors.indigo),
      _StatData('Negocios', '$businesses', Icons.storefront_rounded,
          AppTheme.secondaryColor),
      _StatData('Lugares', '$places', Icons.place_rounded,
          AppTheme.primaryColor),
      _StatData('Categorías', '$categories', Icons.category_rounded,
          Colors.purple),
      _StatData('Reservas', '$reservations', Icons.receipt_long_rounded,
          Colors.teal),
      _StatData('Productos', '$products', Icons.inventory_2_rounded,
          Colors.orange),
      _StatData('Pedidos', '$orders', Icons.shopping_bag_rounded,
          Colors.deepPurple),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Resumen general',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Controla toda la actividad de TurisApp desde un solo lugar.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(card.icon, color: card.color, size: 26),
                    const Spacer(),
                    Text(
                      card.value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      card.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Como administrador puedes editar roles, ocultar o eliminar lugares, gestionar categorías y reservas.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData(this.label, this.value, this.icon, this.color);
}

class _UsersTab extends StatelessWidget {
  final List<AppUserProfile> users;
  final void Function(AppUserProfile) onEdit;
  final void Function(AppUserProfile) onDelete;

  const _UsersTab({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final color = user.isAdmin
            ? Colors.indigo
            : user.isBusiness
                ? AppTheme.secondaryColor
                : AppTheme.primaryColor;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? Text(user.inicial,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(user.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '${user.rolLabel}${user.nombreNegocio.isNotEmpty ? ' · ${user.nombreNegocio}' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit(user);
                if (value == 'delete') onDelete(user);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlacesTab extends StatelessWidget {
  final List<DestinoLugar> places;
  final void Function(DestinoLugar) onEdit;
  final void Function(DestinoLugar) onDelete;
  final void Function(DestinoLugar, bool) onToggle;

  const _PlacesTab({
    required this.places,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: place.imagenPrincipal.isEmpty
                      ? Container(
                          width: 56,
                          height: 56,
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded,
                              color: AppTheme.primaryColor),
                        )
                      : Image.network(
                          place.imagenPrincipal,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: const Icon(Icons.storefront_rounded,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${place.categoriaNombre ?? place.tipoLabel} · ${place.rating.toStringAsFixed(1)} ⭐ (${place.totalReviews})',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text(
                        place.activo ? 'Visible' : 'Oculto',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: place.activo ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: place.activo,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) => onToggle(place, value),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(place);
                    if (value == 'delete') onDelete(place);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final List<CategoriaItem> categorias;
  final VoidCallback onCreate;
  final void Function(CategoriaItem) onEdit;
  final void Function(CategoriaItem) onDelete;

  const _CategoriesTab({
    required this.categorias,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: categorias.length,
          itemBuilder: (context, index) {
            final categoria = categorias[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.category_rounded,
                      color: AppTheme.primaryColor, size: 18),
                ),
                title: Text(categoria.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  categoria.slug,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit(categoria);
                    if (value == 'delete') onDelete(categoria);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: onCreate,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Categoría'),
          ),
        ),
      ],
    );
  }
}

class _ReservationsTab extends StatelessWidget {
  final List<Reserva> reservas;
  final void Function(String, ReservationStatus) onStatusChanged;
  final void Function(String) onDelete;

  const _ReservationsTab({
    required this.reservas,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) {
      return const Center(
        child: Text(
          'No hay reservas registradas.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reservas.length,
      itemBuilder: (context, index) {
        final reserva = reservas[index];
        final id = reserva.id;
        final estado = reserva.estado;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reserva.destinoNombre.isNotEmpty ? reserva.destinoNombre : 'Reserva',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    PopupMenuButton<ReservationStatus>(
                      initialValue: estado,
                      onSelected: (value) => onStatusChanged(id, value),
                      itemBuilder: (_) => ReservationStatus.values
                          .map((e) =>
                              PopupMenuItem(value: e, child: Text(e.label)))
                          .toList(),
                      child: ReservationStatusChip(status: estado),
                    ),
                    IconButton(
                      onPressed: () => onDelete(id),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                    ),
                  ],
                ),
                Text(
                  'Cliente: ${reserva.clienteNombre} · ${reserva.clienteEmail}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reserva.personasTexto} · ${reserva.fechaHoraTexto} · ${reserva.totalTexto}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (estado == ReservationStatus.rechazada && reserva.motivoRechazo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Motivo rechazo: ${reserva.motivoRechazo}',
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoreStockTab extends StatelessWidget {
  final List<ProductModel> products;
  final void Function({ProductModel? product}) onEdit;
  final void Function(ProductModel) onChangePhoto;
  final void Function(String id, int newStock) onUpdateStock;
  final void Function(ProductModel) onDelete;

  const _StoreStockTab({
    required this.products,
    required this.onEdit,
    required this.onChangePhoto,
    required this.onUpdateStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Nuevo producto', style: TextStyle(color: Colors.white)),
        onPressed: () => onEdit(),
      ),
      body: products.isEmpty
          ? const Center(
              child: Text(
                'No hay productos registrados en la tienda.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail with button to change
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade100,
                                child: Image.network(
                                  product.imagenUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => onChangePhoto(product),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: product.activo
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      product.activo ? 'Activo' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: product.activo
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bs. ${product.precio.toStringAsFixed(2)} · ${product.categoria}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Stock controls: - Stock +
                              Row(
                                children: [
                                  const Text(
                                    'Stock:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: product.stock > 0
                                              ? () => onUpdateStock(
                                                    product.id,
                                                    product.stock - 1,
                                                  )
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            '${product.stock}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: product.stock == 0
                                                  ? Colors.red
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => onUpdateStock(
                                            product.id,
                                            product.stock + 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions Popup
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') onEdit(product: product);
                            if (val == 'photo') onChangePhoto(product);
                            if (val == 'delete') onDelete(product);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Editar datos'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'photo',
                              child: Row(
                                children: [
                                  Icon(Icons.photo_camera, size: 18),
                                  SizedBox(width: 8),
                                  Text('Cambiar foto'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _OrdersPaymentsTab extends StatefulWidget {
  final List<OrderModel> orders;
  final List<PaymentRecordModel> payments;
  final List<PagoQrModel> pagosQr;
  final void Function(OrderModel) onCancelOrder;
  final void Function(OrderModel, String) onUpdateOrderStatus;
  final void Function(PaymentRecordModel, String) onUpdatePaymentStatus;
  final void Function(PagoQrModel) onConfirmarPagoManual;
  final Future<void> Function() onRefresh;

  const _OrdersPaymentsTab({
    required this.orders,
    required this.payments,
    required this.pagosQr,
    required this.onCancelOrder,
    required this.onUpdateOrderStatus,
    required this.onUpdatePaymentStatus,
    required this.onConfirmarPagoManual,
    required this.onRefresh,
  });

  @override
  State<_OrdersPaymentsTab> createState() => _OrdersPaymentsTabState();
}

class _OrdersPaymentsTabState extends State<_OrdersPaymentsTab> {
  final _adminService = SupabaseService();
  int _subTabIndex = 0; // 0: Pedidos, 1: Comprobantes, 2: Yape QR

  Widget _qrPlaceholder() {
    return Container(
      height: 170,
      width: 170,
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded,
              size: 64, color: AppTheme.primaryColor),
          SizedBox(height: 6),
          Text(
            'Sin QR configurado',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _subirQrEstatico(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 90,
    );
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final url = await _adminService.uploadImage(
        bucket: 'imagenes',
        folder: 'qrs',
        bytes: bytes,
        fileName: file.name,
      );
      await YapeNotificationService().actualizarQrEstatico(url);
      await widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR estático actualizado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo subir el QR: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text('Pedidos (${widget.orders.length})', style: const TextStyle(fontSize: 11)),
                  ),
                  selected: _subTabIndex == 0,
                  onSelected: (_) => setState(() => _subTabIndex = 0),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _subTabIndex == 0
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text('Comprobantes (${widget.payments.length})', style: const TextStyle(fontSize: 11)),
                  ),
                  selected: _subTabIndex == 1,
                  onSelected: (_) => setState(() => _subTabIndex = 1),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _subTabIndex == 1
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text('Yape QR (${widget.pagosQr.length})', style: const TextStyle(fontSize: 11)),
                  ),
                  selected: _subTabIndex == 2,
                  onSelected: (_) => setState(() => _subTabIndex = 2),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _subTabIndex == 2
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _subTabIndex == 0
              ? _buildOrdersTab()
              : _subTabIndex == 1
                  ? _buildPaymentsList()
                  : _buildYapeQrList(),
        ),
      ],
    );
  }

  Widget _buildYapeQrList() {
    final yapeService = YapeNotificationService();

    return ListenableBuilder(
      listenable: yapeService,
      builder: (context, _) {
        final escucha = yapeService.escuchaActiva;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // QR estático de Bs 0 (configurable sin recompilar la app)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'QR estático de Bs 0',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Esta es la imagen que verán los clientes al pagar. '
                      'Debe ser tu QR personal de Yape/Banca SIN monto fijo.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: (yapeService.qrEstaticoUrl ?? '').isNotEmpty
                            ? Image.network(
                                yapeService.qrEstaticoUrl!,
                                height: 170,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _qrPlaceholder(),
                              )
                            : _qrPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: Text(
                          (yapeService.qrEstaticoUrl ?? '').isEmpty
                              ? 'Subir mi QR (Yape / Banca)'
                              : 'Cambiar imagen del QR',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _subirQrEstatico(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Permiso de acceso a notificaciones (Android)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: yapeService.nativeAccessGranted
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: yapeService.nativeAccessGranted
                        ? Colors.green.shade300
                        : Colors.amber.shade400,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          yapeService.nativeAccessGranted
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_outlined,
                          color: yapeService.nativeAccessGranted
                              ? Colors.green
                              : Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            yapeService.nativeAccessGranted
                                ? 'Acceso a notificaciones CONCEDIDO'
                                : 'Falta conceder acceso a notificaciones',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: yapeService.nativeAccessGranted
                                  ? Colors.green.shade900
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      yapeService.nativeAccessGranted
                          ? 'Este teléfono lee las notificaciones de Yape y completa los pagos automáticamente, aunque la app esté cerrada.'
                          : 'Abre los ajustes de Android y activa "TurisApp" en Acceso a notificaciones. Sin esto, el sistema no puede detectar los pagos.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: yapeService.nativeAccessGranted
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('Abrir ajustes',
                              style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            await yapeService.abrirAjustesNotificaciones();
                          },
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Ya lo activé, verificar',
                              style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            await yapeService.reactivarEscuchaNativa(
                              isAdmin: context.read<AppState>().isAdmin,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Estado del Listener en el dispositivo Admin (Ahorro de Batería)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: escucha ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: escucha ? Colors.green.shade400 : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: escucha ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          escucha
                              ? '🟢 Escucha ACTIVA en tu teléfono'
                              : '⚪ Escucha en REPOSO (Batería protegida)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: escucha ? Colors.green.shade900 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      escucha
                          ? 'Hay al menos un cobro pendiente. Cuando llegue la notificación de Yape con el monto exacto, el pago se completa solo.'
                          : 'No hay cobros pendientes vigentes. El servicio está dormido para no gastar batería ni dar falsos positivos.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: escucha ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: escucha ? Colors.green.shade700 : Colors.grey.shade700,
                        ),
                      ),
                      icon: const Icon(Icons.notifications_active_outlined, size: 16),
                      label: const Text('Diagnóstico: simular notificación'),
                      onPressed: () => _mostrarDialogoSimularNotificacion(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (widget.pagosQr.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay cobros registrados en la tabla pagos_qr.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                ...widget.pagosQr.map((pago) => _buildPagoQrCard(pago)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPagoQrCard(PagoQrModel pago) {
    Color statusColor = Colors.orange;
    if (pago.isPagado) {
      statusColor = Colors.green;
    } else if (pago.isValidadoNotif) {
      statusColor = Colors.blue;
    } else if (pago.isExpirado || pago.isRechazado) {
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pago.referenciaInterna,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    pago.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Monto esperado: Bs. ${pago.montoEsperado.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.primaryColor,
              ),
            ),
            if (pago.usuarioNombre != null && pago.usuarioNombre!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Cliente registrado: ${pago.usuarioNombre}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
            if (pago.glosa != null && pago.glosa!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Glosa: ${pago.glosa}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
            if (pago.pagadoPor != null) ...[
              const SizedBox(height: 2),
              Text(
                'Pagado por: ${pago.pagadoPor}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            if (pago.notificacionTexto != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Notificación: "${pago.notificacionTexto}"',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                ),
              ),
            ],

            if (pago.isPagado && pago.saldoAnterior != null && pago.saldoNuevo != null) ...[
              const SizedBox(height: 6),
              Text(
                'Auditoría: Saldo Bs. ${pago.saldoAnterior!.toStringAsFixed(2)} ➔ Bs. ${pago.saldoNuevo!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 10),

            // PAGADO: confirmado solo, sin intervención del admin.
            if (pago.isPagado)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pago.isPagadoAutomatico
                            ? 'Pago completado automáticamente por la notificación de Yape.'
                            : 'Pago marcado como completado por el administrador.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            // PENDIENTE: respaldo manual, un toque, sin escribir saldos.
            else if (pago.isPendiente)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.textSecondary,
                  ),
                  icon: const Icon(Icons.touch_app_outlined, size: 16),
                  label: const Text(
                    'Marcar como pagado (solo si no llegó la notificación)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => widget.onConfirmarPagoManual(pago),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoSimularNotificacion(BuildContext context) {
    final primerPendiente =
        widget.pagosQr.where((p) => p.isPendiente).firstOrNull;
    final nombreSugerido = primerPendiente?.usuarioNombre ?? 'Juan Pérez';
    final montoSugerido = primerPendiente != null
        ? primerPendiente.montoEsperado.toStringAsFixed(2)
        : '25.00';

    final remitente = TextEditingController(text: '$nombreSugerido (Yape)');
    final texto = TextEditingController(
      text:
          '¡Te yapearon Bs $montoSugerido! $nombreSugerido te envió un pago en Yape.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnóstico: simular notificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Prueba cómo tu app captura las notificaciones de Yape sin tener que hacer transferencias reales:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remitente,
              decoration: const InputDecoration(labelText: 'Título / Remitente'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: texto,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Texto de la notificación'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await YapeNotificationService().procesarNotificacion(
                titulo: remitente.text.trim(),
                texto: texto.text.trim(),
              );
              await widget.onRefresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '¡Pago completado automáticamente!'
                          : 'No se encontró cobro pendiente que coincida con el monto.',
                    ),
                    backgroundColor: ok ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Simular Llegada'),
          ),
        ],
      ),
    );
  }

  /// Cobro QR asociado a un pedido (si existe).
  PagoQrModel? _pagoDePedido(String idPedido) {
    for (final pago in widget.pagosQr) {
      if (pago.idPedido != null && pago.idPedido == idPedido) return pago;
    }
    return null;
  }

  /// Banner compacto con el estado del vigilador de notificaciones de Yape.
  Widget _buildEscuchaBanner() {
    final yapeService = YapeNotificationService();
    return ListenableBuilder(
      listenable: yapeService,
      builder: (context, _) {
        final escucha = yapeService.escuchaActiva;
        final acceso = yapeService.nativeAccessGranted;
        final pendientes =
            widget.pagosQr.where((p) => p.isPendiente).length;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: escucha ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: escucha ? Colors.green.shade400 : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                escucha
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                size: 18,
                color:
                    escucha ? Colors.green.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  escucha
                      ? 'Vigilador de Yape ACTIVO · $pendientes cobro(s) pendiente(s)'
                      : 'Vigilador de Yape en espera · sin cobros pendientes',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: escucha
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
              ),
              if (!acceso)
                Tooltip(
                  message: 'Falta el permiso de acceso a notificaciones',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Colors.orange.shade800,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        _buildEscuchaBanner(),
        Expanded(child: _buildOrdersList()),
      ],
    );
  }

  Widget _buildPagoEstadoChip(PagoQrModel pago) {
    Color color;
    String texto;
    IconData icono;
    if (pago.isPagado) {
      color = Colors.green;
      texto = pago.isPagadoAutomatico
          ? 'Yape QR · PAGADO automáticamente'
          : 'Yape QR · PAGADO';
      icono = Icons.check_circle_rounded;
    } else if (pago.isPendiente) {
      color = Colors.orange;
      texto = 'Yape QR · esperando transferencia';
      icono = Icons.qr_code_2_rounded;
    } else if (pago.isExpirado) {
      color = Colors.grey;
      texto = 'Yape QR · expirado';
      icono = Icons.timer_off_rounded;
    } else {
      color = Colors.redAccent;
      texto = 'Yape QR · ${pago.estado}';
      icono = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (widget.orders.isEmpty) {
      return const Center(
        child: Text(
          'No hay pedidos registrados en la tienda.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.orders.length,
      itemBuilder: (context, index) {
        final order = widget.orders[index];
        final ref = order.codigoReferencia.isNotEmpty
            ? order.codigoReferencia
            : (order.id.length > 8 ? order.id.substring(0, 8) : order.id);

        Color statusColor = Colors.orange;
        if (order.estado.toLowerCase() == 'pagado' ||
            order.estado.toLowerCase() == 'entregado') {
          statusColor = Colors.green;
        } else if (order.estado.toLowerCase() == 'cancelado') {
          statusColor = Colors.red;
        }

        final isPending = order.estado.toLowerCase() == 'pendiente';
        final pago = _pagoDePedido(order.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pedido #$ref',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    PopupMenuButton<String>(
                      initialValue: order.estado,
                      onSelected: (val) =>
                          widget.onUpdateOrderStatus(order, val),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'Pendiente', child: Text('Pendiente')),
                        PopupMenuItem(value: 'Pagado', child: Text('Pagado')),
                        PopupMenuItem(
                            value: 'Entregado', child: Text('Entregado')),
                        PopupMenuItem(
                            value: 'Cancelado', child: Text('Cancelado')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              order.estado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (pago != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildPagoEstadoChip(pago),
                  ),
                  const SizedBox(height: 6),
                ],
                if (order.turistaNombre != null || order.turistaEmail != null)
                  Text(
                    'Cliente: ${order.turistaNombre ?? 'Usuario'} · ${order.turistaEmail ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                if (order.telefonoContacto != null &&
                    order.telefonoContacto!.isNotEmpty)
                  Text(
                    'Teléfono: ${order.telefonoContacto}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                if (order.direccionEntrega != null &&
                    order.direccionEntrega!.isNotEmpty)
                  Text(
                    'Dirección: ${order.direccionEntrega}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                const SizedBox(height: 8),
                // Items
                if (order.items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  '${item.cantidad}x ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.nombreProducto,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  'Bs. ${item.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: Bs. ${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    if (isPending)
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Cancelar',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => widget.onCancelOrder(order),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Aprobar',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => widget.onUpdateOrderStatus(
                                order, 'Pagado'),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList() {
    if (widget.payments.isEmpty) {
      return const Center(
        child: Text(
          'No hay comprobantes de pago registrados.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.payments.length,
      itemBuilder: (context, index) {
        final payment = widget.payments[index];
        final isPending = payment.estado.toLowerCase() == 'pendiente';
        Color statusColor = Colors.orange;
        if (payment.estado.toLowerCase() == 'verificado' ||
            payment.estado.toLowerCase() == 'aprobado') {
          statusColor = Colors.green;
        } else if (payment.estado.toLowerCase() == 'rechazado') {
          statusColor = Colors.red;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ref: ${payment.numeroReferenciaBanco}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payment.estado,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Monto: Bs. ${payment.montoValidado.toStringAsFixed(2)} · Banco: ${payment.bancoOrigen ?? 'QR'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryColor),
                ),
                if (payment.usuarioNombre != null ||
                    payment.usuarioEmail != null)
                  Text(
                    'Usuario: ${payment.usuarioNombre ?? ''} (${payment.usuarioEmail ?? ''})',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                if (payment.idPedido != null)
                  Text(
                    'Pedido ID: ${payment.idPedido}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                if (payment.idReserva != null)
                  Text(
                    'Reserva ID: ${payment.idReserva}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (payment.comprobanteUrl.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.receipt, size: 16),
                        label: const Text('Ver comprobante',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Comprobante de Pago'),
                              content: Image.network(
                                payment.comprobanteUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                      'No se pudo previsualizar el comprobante'),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    if (isPending)
                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Rechazar',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => widget.onUpdatePaymentStatus(
                                payment, 'Rechazado'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Aprobar',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => widget.onUpdatePaymentStatus(
                                payment, 'Verificado'),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
