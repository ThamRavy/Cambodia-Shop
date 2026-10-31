import 'package:flutter/foundation.dart';

import 'api/shop_api.dart';
import 'models/product.dart';

class StoreState extends ChangeNotifier {
  StoreState(this.api);

  final ShopApi api;
  final List<Product> products = [];
  final Map<String, int> cart = {};
  String? token;
  String? email;
  String? name;
  bool loadingProducts = false;
  String? productsError;
  int orderRevision = 0;

  int get cartCount => cart.values.fold(0, (total, count) => total + count);

  Future<void> loadProducts({String? category}) async {
    loadingProducts = true;
    productsError = null;
    notifyListeners();
    try {
      products
        ..clear()
        ..addAll(await api.getProducts(category: category));
    } catch (error) {
      productsError = error.toString();
    } finally {
      loadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> authenticate({
    required bool register,
    required String email,
    required String password,
    String name = '',
  }) async {
    final result = register
        ? await api.register(name, email, password)
        : await api.login(email, password);
    final user = result['user'] as Map<String, dynamic>;
    token = result['token'] as String;
    this.email = user['email'] as String?;
    this.name = user['name'] as String?;
    notifyListeners();
  }

  void signOut() {
    token = null;
    email = null;
    name = null;
    notifyListeners();
  }

  void addToCart(Product product) {
    cart.update(product.id, (quantity) => quantity + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final quantity = cart[product.id];
    if (quantity == null) return;
    if (quantity <= 1) {
      cart.remove(product.id);
    } else {
      cart[product.id] = quantity - 1;
    }
    notifyListeners();
  }

  int quantityFor(Product product) => cart[product.id] ?? 0;

  int get cartTotalCents => products.fold(
    0,
    (total, product) => total + product.priceCents * (cart[product.id] ?? 0),
  );

  Future<Map<String, dynamic>> placeOrder({
    required String recipient,
    required String phone,
    required String addressLine,
    required String city,
  }) async {
    final accessToken = token;
    if (accessToken == null) {
      throw const ApiException('Sign in before placing an order.');
    }
    final order = await api.createOrder(
      token: accessToken,
      items: Map.of(cart),
      shippingAddress: {
        'recipient': recipient,
        'phone': phone,
        'addressLine': addressLine,
        'city': city,
      },
    );
    cart.clear();
    orderRevision++;
    notifyListeners();
    return order;
  }

  Future<Map<String, dynamic>> createQrCheckout(String orderId) {
    final accessToken = token;
    if (accessToken == null) {
      throw const ApiException('Sign in before starting payment.');
    }
    return api.createQrCheckout(token: accessToken, orderId: orderId);
  }

  Future<Map<String, dynamic>> verifyPayment(String tranId) async {
    final accessToken = token;
    if (accessToken == null) {
      throw const ApiException('Sign in again to verify this payment.');
    }
    final result = await api.verifyPayment(token: accessToken, tranId: tranId);
    orderRevision++;
    notifyListeners();
    return result;
  }
}
