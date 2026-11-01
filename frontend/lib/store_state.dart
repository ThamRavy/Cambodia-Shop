import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api/shop_api.dart';
import 'models/product.dart';

class EmailVerificationPendingException implements Exception {
  const EmailVerificationPendingException();
}

class StoreState extends ChangeNotifier {
  StoreState(this.api, {this._firebaseAuth});

  final ShopApi api;
  final FirebaseAuth? _firebaseAuth;
  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
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

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return the newly created account.');
    }
    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in again before requesting a verification link.');
    }
    await user.sendEmailVerification();
  }

  Future<void> verifyEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in again after opening your verification email.');
    }
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      throw const EmailVerificationPendingException();
    }
    await _exchangeFirebaseToken(refreshedUser);
  }

  Future<void> authenticate({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return the signed-in account.');
    }
    if (!user.emailVerified) {
      throw const EmailVerificationPendingException();
    }
    await _exchangeFirebaseToken(user);
  }

  Future<void> _exchangeFirebaseToken(User user) async {
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Firebase did not return a valid sign-in token.');
    }
    final result = await api.exchangeFirebaseToken(idToken);
    _setAuthenticatedUser(result);
  }

  void _setAuthenticatedUser(Map<String, dynamic> result) {
    final user = result['user'] as Map<String, dynamic>;
    token = result['token'] as String;
    email = user['email'] as String?;
    name = user['name'] as String?;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
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
