import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ecommerce_api/services/aba_payway_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AbaPayWayService', () {
    test('signs the purchase fields and returns the JSON transaction data',
        () async {
      late Map<String, String> fields;
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        baseUrl: 'https://checkout-sandbox.payway.com.kh/',
        returnUrl: 'https://shop.example.com/payments/return',
        cancelUrl: 'https://shop.example.com/payment/cancel',
        successUrl: 'https://shop.example.com/payment/success',
        clock: () => DateTime.utc(2025, 7, 28, 2, 20, 56),
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://checkout-sandbox.payway.com.kh/api/payment-gateway/v1/payments/purchase',
          );
          fields = request.bodyFields;
          return http.Response(
            jsonEncode({
              'status': {'code': '00', 'message': 'Success!'},
              'qr_string': 'sample-qr',
              'checkout_qr_url': 'https://checkout.example/qr',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.createCheckout(
        tranId: 'transaction123',
        amountCents: 1999,
        shippingCents: 0,
        currency: 'USD',
        paymentOption: 'abapay_khqr_deeplink',
        firstName: 'Shop',
        lastName: 'Customer',
        email: 'customer@example.com',
        phone: '012345678',
        returnDeeplink: {
          'ios_scheme': 'myapp://payment/complete',
          'android_scheme': 'myapp://payment/complete',
        },
        items: [
          {
            'name': 'Sample product',
            'quantity': 1,
            'unitPriceCents': 1999,
          },
        ],
      );

      expect(fields['req_time'], '20250728022056');
      expect(fields['amount'], '19.99');
      expect(fields['shipping'], '0.00');
      expect(fields['payment_option'], 'abapay_khqr_deeplink');
      expect(fields['view_type'], 'hosted');
      expect(
        jsonDecode(utf8.decode(base64.decode(fields['return_deeplink']!))),
        {
          'ios_scheme': 'myapp://payment/complete',
          'android_scheme': 'myapp://payment/complete',
        },
      );
      expect(
        utf8.decode(base64.decode(fields['return_url']!)),
        'https://shop.example.com/payments/return',
      );
      expect(
        jsonDecode(utf8.decode(base64.decode(fields['items']!))),
        [
          {'name': 'Sample product', 'quantity': 1, 'price': 19.99},
        ],
      );
      expect(fields['hash'], _expectedHash(fields, 'test-hmac-key'));
      expect(result['provider'], 'aba_payway');
      expect(result['tranId'], 'transaction123');
      expect(result['qr_string'], 'sample-qr');
    });

    test('returns the hosted checkout response as HTML', () async {
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        client: MockClient((_) async => http.Response(
              '<html>Checkout</html>',
              200,
              headers: {'content-type': 'text/html'},
            )),
      );

      final result = await service.createCheckout(
        tranId: 'transaction123',
        amountCents: 100,
        shippingCents: 0,
        currency: 'USD',
        paymentOption: 'cards',
        firstName: 'Shop',
        lastName: 'Customer',
        email: 'customer@example.com',
        phone: '012345678',
        items: const [],
      );

      expect(result['checkoutHtml'], '<html>Checkout</html>');
      expect(result['contentType'], 'text/html');
    });

    test('reports malformed provider JSON as a provider error', () async {
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        client: MockClient((_) async => http.Response('{"amount": 1.}', 200)),
      );

      await expectLater(
        service.createCheckout(
          tranId: 'transaction123',
          amountCents: 100,
          shippingCents: 0,
          currency: 'USD',
          paymentOption: 'cards',
          firstName: 'Shop',
          lastName: 'Customer',
          email: 'customer@example.com',
          phone: '012345678',
          items: const [],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            startsWith('ABA PayWay returned invalid JSON:'),
          ),
        ),
      );
    });

    test('rejects unsupported payment options', () {
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        client: MockClient((_) async => http.Response('', 200)),
      );

      expect(
        () => service.createCheckout(
          tranId: 'transaction123',
          amountCents: 100,
          shippingCents: 0,
          currency: 'USD',
          paymentOption: 'unsupported',
          firstName: 'Shop',
          lastName: 'Customer',
          email: 'customer@example.com',
          phone: '012345678',
          items: const [],
        ),
        throwsFormatException,
      );
    });

    test('checks transaction status with the documented signed JSON request',
        () async {
      late Map<String, dynamic> requestBody;
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        baseUrl: 'https://checkout-sandbox.payway.com.kh/',
        clock: () => DateTime.utc(2025, 7, 28, 2, 20, 56),
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://checkout-sandbox.payway.com.kh/api/payment-gateway/v1/payments/check-transaction-2',
          );
          expect(request.headers['content-type'], 'application/json');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'payment_status_code': 0,
                'total_amount': 19.99,
                'payment_currency': 'USD',
                'payment_status': 'APPROVED',
              },
              'status': {
                'code': '00',
                'message': 'Success!',
                'tran_id': 'transaction123',
              },
            }),
            200,
          );
        }),
      );

      final result = await service.checkTransaction('transaction123');

      expect(requestBody['req_time'], '20250728022056');
      expect(requestBody['merchant_id'], 'merchant');
      expect(requestBody['tran_id'], 'transaction123');
      expect(
        requestBody['hash'],
        _expectedCheckHash(
          '20250728022056',
          'merchant',
          'transaction123',
          'test-hmac-key',
        ),
      );
      expect(result['payment_status'], 'APPROVED');
      expect(result['total_amount'], 19.99);
    });

    test('rejects unsuccessful provider check responses', () async {
      final service = AbaPayWayService(
        merchantId: 'merchant',
        hmacKey: 'test-hmac-key',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'status': {
                  'code': 6,
                  'message': 'Transaction not found',
                  'tran_id': 'transaction123',
                },
              }),
              200,
            )),
      );

      await expectLater(
        service.checkTransaction('transaction123'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

String _expectedHash(Map<String, String> fields, String hmacKey) {
  const signedFields = [
    'req_time',
    'merchant_id',
    'tran_id',
    'amount',
    'items',
    'shipping',
    'firstname',
    'lastname',
    'email',
    'phone',
    'type',
    'payment_option',
    'return_url',
    'cancel_url',
    'continue_success_url',
    'return_deeplink',
    'currency',
    'custom_fields',
    'return_params',
    'payout',
    'lifetime',
    'additional_params',
    'google_pay_token',
    'skip_success_page',
  ];
  final payload = signedFields.map((field) => fields[field] ?? '').join();
  final signature =
      Hmac(sha512, utf8.encode(hmacKey)).convert(utf8.encode(payload));
  return base64.encode(signature.bytes);
}

String _expectedCheckHash(
  String reqTime,
  String merchantId,
  String tranId,
  String hmacKey,
) {
  final payload = '$reqTime$merchantId$tranId';
  final signature =
      Hmac(sha512, utf8.encode(hmacKey)).convert(utf8.encode(payload));
  return base64.encode(signature.bytes);
}
