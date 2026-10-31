import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ShopApi {
  ShopApi({http.Client? client})
    : _client = client ?? http.Client(),
      _baseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8080/api/v1',
      ).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<List<Product>> getProducts({String? category}) async {
    final uri = Uri.parse('$_baseUrl/products').replace(
      queryParameters: category == null ? null : {'category': category},
    );
    final response = await _send(uri);
    final items = (response as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> login(String email, String password) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) {
    return _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> createOrder({
    required String token,
    required Map<String, int> items,
    required Map<String, String> shippingAddress,
  }) {
    return _post('/orders', {
      'items': items.entries
          .map((entry) => {'productId': entry.key, 'quantity': entry.value})
          .toList(),
      'shippingAddress': shippingAddress,
    }, token: token);
  }

  Future<List<Map<String, dynamic>>> getOrders(String token) async {
    final response = await _send(Uri.parse('$_baseUrl/orders'), token: token);
    final items = (response as Map<String, dynamic>)['items'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createQrCheckout({
    required String token,
    required String orderId,
  }) {
    return _post('/payments/checkout', {
      'orderId': orderId,
      'paymentOption': 'abapay_khqr',
    }, token: token);
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String token,
    required String tranId,
  }) {
    return _post('/payments/verify', {'tranId': tranId}, token: token);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _send(
      Uri.parse('$_baseUrl$path'),
      method: 'POST',
      body: body,
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<dynamic> _send(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';

    late final http.Response response;
    try {
      response = method == 'POST'
          ? await _client.post(uri, headers: headers, body: jsonEncode(body))
          : await _client.get(uri, headers: headers);
    } on http.ClientException catch (error) {
      throw ApiException(
        'Could not reach the shop API at $_baseUrl. Check the API address and that the server is running. ${error.message}',
      );
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'The shop API returned an unreadable response (${response.statusCode}).',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] ?? decoded['error']
          : null;
      throw ApiException(
        message?.toString() ?? 'Request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }
}
