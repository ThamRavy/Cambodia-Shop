import 'dart:convert';

import 'package:cambodia_shop_app/api/shop_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests an email verification code during registration', () async {
    late http.Request request;
    final api = ShopApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'email': 'customer@example.com',
            'message': 'Check your email.',
          }),
          202,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.register(
      'Shop Customer',
      'customer@example.com',
      'a-long-passphrase',
    );

    expect(request.url.path, '/api/v1/auth/register');
    expect(jsonDecode(request.body), {
      'name': 'Shop Customer',
      'email': 'customer@example.com',
      'password': 'a-long-passphrase',
    });
    expect(result['email'], 'customer@example.com');
  });

  test('verifies an email code and returns the signed-in customer', () async {
    late http.Request request;
    final api = ShopApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'user-id',
              'email': 'customer@example.com',
              'name': 'Shop Customer',
            },
            'token': 'customer-token',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.verifyEmail('customer@example.com', '012345');

    expect(request.url.path, '/api/v1/auth/verify_email');
    expect(jsonDecode(request.body), {
      'email': 'customer@example.com',
      'code': '012345',
    });
    expect(result['token'], 'customer-token');
  });

  test('preserves the email verification-required login response', () async {
    final api = ShopApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'email_not_verified',
            'message': 'We sent a verification code to your email address.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.login('customer@example.com', 'correct-password'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.code, 'code', 'email_not_verified'),
      ),
    );
  });

  test('creates an ABA KHQR checkout for the selected order', () async {
    late http.Request request;
    final api = ShopApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'provider': 'aba_payway',
            'tranId': 'tran123',
            'paymentOption': 'abapay_khqr',
            'qr_string': 'sample-qr-data',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final checkout = await api.createQrCheckout(
      token: 'customer-token',
      orderId: 'order-123',
    );

    expect(request.url.path, '/api/v1/payments/checkout');
    expect(request.headers['authorization'], 'Bearer customer-token');
    expect(jsonDecode(request.body), {
      'orderId': 'order-123',
      'paymentOption': 'abapay_khqr',
    });
    expect(checkout['tranId'], 'tran123');
    expect(checkout['qr_string'], 'sample-qr-data');
  });

  test('verifies a PayWay transaction through the authenticated API', () async {
    late http.Request request;
    final api = ShopApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({'tranId': 'tran123', 'status': 'approved'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.verifyPayment(
      token: 'customer-token',
      tranId: 'tran123',
    );

    expect(request.url.path, '/api/v1/payments/verify');
    expect(request.headers['authorization'], 'Bearer customer-token');
    expect(jsonDecode(request.body), {'tranId': 'tran123'});
    expect(result['status'], 'approved');
  });
}
