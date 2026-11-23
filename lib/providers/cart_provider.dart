import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  List<ProductModel> _products = [];
  bool _loading = false;
  String? _error;

  Map<String, CartItem> get items => {..._items};
  List<CartItem> get cartList => _items.values.toList();
  List<ProductModel> get products => [..._products];
  bool get loading => _loading;
  String? get error => _error;

  int get totalItemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  Future<void> loadProducts() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await SupabaseService().fetchProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void addItem(ProductModel product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

