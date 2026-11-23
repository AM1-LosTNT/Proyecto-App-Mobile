import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get subtotal => product.precio * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id_producto': product.id,
      'nombre_producto': product.nombre,
      'cantidad': quantity,
      'precio_unitario': product.precio,
      'subtotal': subtotal,
    };
  }
}

