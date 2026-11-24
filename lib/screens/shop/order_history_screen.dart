import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../models/order_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/payment_details.dart';
import 'payment_proof_screen.dart';
import 'qr_static_cobro_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _service = SupabaseService();

  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.getMisPedidos();
      if (!mounted) return;
      setState(() {
        _orders = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(
          e,
          fallback:
              'No pudimos cargar tus pedidos. Revisa tu conexión e inténtalo de nuevo.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(OrderModel order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InlineAlert(message: _error!),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aún no tienes pedidos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cuando compres un souvenir aparecerá aquí con su estado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Ir a la tienda'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderCard(
            order: order,
            onTap: () => _openDetail(order),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.cantidad,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido ${order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _StatusChip(estado: order.estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(order.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'artículo' : 'artículos'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Bs. ${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final OrderModel order;

  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final canPay = order.estado.toLowerCase() == 'pendiente';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido ${order.id}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(estado: order.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const Divider(height: 28),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.cantidad}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.nombreProducto,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    Text(
                      'Bs. ${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bs. ${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            if (order.direccionEntrega != null &&
                order.direccionEntrega!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.direccionEntrega!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PaymentDetails(
              total: order.total,
              reference: order.codigoReferencia,
            ),
            if (canPay) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QrStaticCobroScreen(
                          monto: order.total,
                          idPedido: order.id,
                          glosa: 'Pedido #${order.codigoReferencia}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Pagar con QR de Bs 0 (Yape)'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final done = await navigator.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => PaymentProofScreen(order: order),
                      ),
                    );
                    if (done == true && navigator.canPop()) {
                      navigator.pop();
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Subir comprobante manual'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String estado;

  const _StatusChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = _statusStyle(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            estado,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

(Color, Color, IconData) _statusStyle(String estado) {
  switch (estado.toLowerCase()) {
    case 'pagado':
      return (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
        Icons.verified_rounded,
      );
    case 'en camino':
      return (
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        Icons.local_shipping_outlined,
      );
    case 'entregado':
      return (
        const Color(0xFFCCFBF1),
        const Color(0xFF0F766E),
        Icons.inventory_2_outlined,
      );
    case 'cancelado':
      return (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        Icons.cancel_outlined,
      );
    default:
      return (
        const Color(0xFFFFF7ED),
        const Color(0xFFC2410C),
        Icons.hourglass_top_rounded,
      );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}
