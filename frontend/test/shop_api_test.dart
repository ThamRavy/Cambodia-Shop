import 'dart:convert';

import 'package:cambodia_shop_app/api/shop_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the deployed API by default', () async {
    late http.Request request;
    final api = ShopApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({'error': 'invalid_firebase_token'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.exchangeFirebaseToken('firebase-id-token'),
      throwsA(isA<ApiException>()),
    );

    expect(request.url.origin, 'https://ecommerce-backend-man4.onrender.com');
    expect(request.url.path, '/api/v1/auth/login');
  });

  test('exchanges a Firebase ID token for a shop API session', () async {
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

    final result = await api.exchangeFirebaseToken('firebase-id-token');

    expect(request.url.path, '/api/v1/auth/login');
    expect(jsonDecode(request.body), {'idToken': 'firebase-id-token'});
    expect(result['token'], 'customer-token');
  });

  test('preserves Firebase verification errors from the API', () async {
    final api = ShopApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'email_not_verified',
            'message': 'Verify your email address before signing in.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.exchangeFirebaseToken('unverified-firebase-id-token'),
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
