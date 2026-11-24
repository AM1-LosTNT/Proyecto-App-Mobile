import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_error.dart';
import '../../models/cart_item.dart';
import '../../models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/payment_details.dart';
import 'order_history_screen.dart';
import 'qr_static_cobro_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    if (cart.cartList.isEmpty) return;

    final order = await showModalBottomSheet<OrderModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(items: cart.cartList),
    );

    if (order == null) return;
    cart.clearCart();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _OrderSuccessDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mi carrito'),
        actions: [
          if (cart.cartList.isNotEmpty)
            TextButton(
              onPressed: cart.clearCart,
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: cart.cartList.isEmpty
          ? _EmptyCart(onGoShopping: () => Navigator.pop(context))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: cart.cartList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _CartItemCard(item: cart.cartList[index]),
                  ),
                ),
                _CartSummary(
                  totalItems: cart.totalItemCount,
                  total: cart.totalAmount,
                  onCheckout: () => _checkout(context),
                ),
              ],
            ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onGoShopping;

  const _EmptyCart({required this.onGoShopping});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explora la tienda y agrega tus souvenirs favoritos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onGoShopping,
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Ir a la tienda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 82,
              height: 82,
              child: item.product.imagenUrl.isEmpty
                  ? _imageFallback()
                  : Image.network(
                      item.product.imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => cart.removeItem(item.product.id),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Bs. ${item.product.precio.toStringAsFixed(2)} c/u',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () => cart.removeSingleItem(item.product.id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () => cart.addItem(item.product),
                    ),
                    const Spacer(),
                    Text(
                      'Bs. ${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.10),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.primaryColor,
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final int totalItems;
  final double total;
  final VoidCallback onCheckout;

  const _CartSummary({
    required this.totalItems,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalItems ${totalItems == 1 ? 'producto' : 'productos'}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Bs. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: const Text('Continuar con el pago'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final List<CartItem> items;

  const _CheckoutSheet({required this.items});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _notas = TextEditingController();

  bool _sending = false;
  String? _error;

  double get _total =>
      widget.items.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void dispose() {
    _direccion.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_direccion.text.trim().isEmpty) {
      setState(() => _error = 'Escribe la dirección donde recibirás tu pedido.');
      return;
    }
    if (_telefono.text.trim().length < 6) {
      setState(() => _error = 'Ingresa un teléfono de contacto válido.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final order = await SupabaseService().crearPedido(
        items: widget.items,
        direccionEntrega: _direccion.text,
        telefonoContacto: _telefono.text,
        notas: _notas.text,
      );
      if (!mounted) return;
      Navigator.pop(context, order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyError(
          e,
          fallback: 'No pudimos crear tu pedido. Inténtalo de nuevo.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
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
            const Text(
              'Finalizar compra',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.items.length} '
              '${widget.items.length == 1 ? 'producto' : 'productos'} · '
              'Bs. ${_total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _direccion,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Dirección de entrega',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              InlineAlert(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Bs. ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar pedido'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Al confirmar se generará tu código de referencia para el pago por QR.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSuccessDialog extends StatelessWidget {
  final OrderModel order;

  const _OrderSuccessDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Expanded(child: Text('¡Pedido registrado!')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu pedido quedó en estado Pendiente. Realiza el pago para que '
              'podamos prepararlo.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 14),
            PaymentDetails(
              total: order.total,
              reference: order.codigoReferencia,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        OutlinedButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const OrderHistoryScreen(),
              ),
            );
          },
          child: const Text('Mis pedidos'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
          label: const Text('Pagar con QR (Yape)'),
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => QrStaticCobroScreen(
                  monto: order.total,
                  idPedido: order.id,
                  glosa: 'Pedido #${order.codigoReferencia}',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
