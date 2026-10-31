import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../utils/payway_hash.dart';

class AbaPayWayService {
  static const supportedPaymentOptions = {
    'cards',
    'abapay_khqr',
    'abapay_khqr_deeplink',
    'alipay',
    'wechat',
  };

  final http.Client client;
  final String merchantId;
  final String hmacKey;
  final String baseUrl;
  final String purchaseUrl;
  final String checkTransactionUrl;
  final String returnUrl;
  final String cancelUrl;
  final String successUrl;
  final DateTime Function() clock;

  AbaPayWayService({
    http.Client? client,
    String? merchantId,
    String? hmacKey,
    String? baseUrl,
    String? purchaseUrl,
    String? checkTransactionUrl,
    String? returnUrl,
    String? cancelUrl,
    String? successUrl,
    DateTime Function()? clock,
  })  : client = client ?? http.Client(),
        merchantId = merchantId ?? Env.abaMerchantId,
        hmacKey = hmacKey ?? Env.abaHmacKey,
        baseUrl = baseUrl ?? Env.abaBaseUrl,
        purchaseUrl = purchaseUrl ??
            (baseUrl == null
                ? Env.abaPurchaseUrl
                : '${baseUrl.replaceFirst(RegExp(r'/$'), '')}'
                    '/api/payment-gateway/v1/payments/purchase'),
        checkTransactionUrl = checkTransactionUrl ??
            (baseUrl == null
                ? Env.abaCheckTransactionUrl
                : '${baseUrl.replaceFirst(RegExp(r'/$'), '')}'
                    '/api/payment-gateway/v1/payments/check-transaction-2'),
        returnUrl =
            returnUrl ?? '${Env.publicApiBaseUrl}/api/v1/payments/return',
        cancelUrl = cancelUrl ?? Env.cancelUrl,
        successUrl = successUrl ?? Env.successUrl,
        clock = clock ?? DateTime.now;

  Future<Map<String, dynamic>> createCheckout({
    required String tranId,
    required int amountCents,
    required int shippingCents,
    required String currency,
    required String paymentOption,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required List<Map<String, dynamic>> items,
    Map<String, String>? returnDeeplink,
  }) async {
    if (merchantId.isEmpty || hmacKey.isEmpty) {
      throw StateError('ABA PayWay credentials are not configured');
    }
    if (amountCents <= 0 || shippingCents < 0) {
      throw FormatException('Invalid payment amount');
    }
    if (!supportedPaymentOptions.contains(paymentOption)) {
      throw FormatException(
        'Unsupported payment option. Use one of: '
        '${supportedPaymentOptions.join(', ')}',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9]{1,20}$').hasMatch(tranId)) {
      throw FormatException('Invalid transaction ID');
    }
    if (currency != 'USD') {
      throw FormatException('PayWay checkout currently supports USD orders');
    }
    final encodedReturnDeeplink = _encodeReturnDeeplink(returnDeeplink);

    final reqTime = _requestTime(clock().toUtc());
    final encodedItems = base64.encode(utf8.encode(jsonEncode(
      items
          .map((item) => {
                'name': item['name'],
                'quantity': item['quantity'],
                'price': (item['unitPriceCents'] as int) / 100,
              })
          .toList(),
    )));
    final encodedReturnUrl = base64.encode(utf8.encode(returnUrl));
    final fields = <String, String>{
      'req_time': reqTime,
      'merchant_id': merchantId,
      'tran_id': tranId,
      'amount': (amountCents / 100).toStringAsFixed(2),
      'items': encodedItems,
      'shipping': (shippingCents / 100).toStringAsFixed(2),
      'firstname': firstName,
      'lastname': lastName,
      'email': email,
      'phone': phone,
      'type': 'purchase',
      'payment_option': paymentOption,
      'return_url': encodedReturnUrl,
      'cancel_url': cancelUrl,
      'continue_success_url': successUrl,
      'return_deeplink': encodedReturnDeeplink,
      'currency': currency,
      'custom_fields': '',
      'return_params': '',
      'payout': '',
      'lifetime': '',
      'additional_params': '',
      'google_pay_token': '',
      'skip_success_page': '0',
      'view_type': 'hosted',
    };
    fields['hash'] = PaywayHash.purchase(fields: fields, hmacKey: hmacKey);

    final uri = Uri.parse(purchaseUrl);
    final response = await client.post(uri, body: fields);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'ABA PayWay checkout request failed (${response.statusCode})',
      );
    }

    final responseBody = response.body.trimLeft();
    if (responseBody.startsWith('{')) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        throw StateError(
          'ABA PayWay returned invalid JSON: ${error.message}',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw StateError('ABA PayWay returned an invalid JSON response');
      }
      return {
        ...decoded,
        'provider': 'aba_payway',
        'tranId': tranId,
        'paymentOption': paymentOption,
      };
    }
    return {
      'provider': 'aba_payway',
      'tranId': tranId,
      'paymentOption': paymentOption,
      'checkoutHtml': response.body,
      'contentType': response.headers['content-type'] ?? 'text/html',
    };
  }

  Future<Map<String, dynamic>> checkTransaction(String tranId) async {
    if (merchantId.isEmpty || hmacKey.isEmpty) {
      throw StateError('ABA PayWay credentials are not configured');
    }
    if (!RegExp(r'^[A-Za-z0-9]{1,20}$').hasMatch(tranId)) {
      throw FormatException('Invalid transaction ID');
    }

    final reqTime = _requestTime(clock().toUtc());
    final fields = <String, String>{
      'req_time': reqTime,
      'merchant_id': merchantId,
      'tran_id': tranId,
      'hash': PaywayHash.checkTransaction(
        reqTime: reqTime,
        merchantId: merchantId,
        tranId: tranId,
        hmacKey: hmacKey,
      ),
    };
    final uri = Uri.parse(checkTransactionUrl);
    final response = await client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(fields),
    );
    if (response.statusCode == 429) {
      throw StateError('ABA PayWay transaction check rate limit reached');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'ABA PayWay transaction check failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw StateError('ABA PayWay returned an invalid transaction status');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final apiStatus = decoded['status'];
    if (apiStatus is Map && '${apiStatus['code']}' == '429') {
      throw StateError('ABA PayWay transaction check rate limit reached');
    }
    if (apiStatus is! Map || '${apiStatus['code']}' != '00') {
      final message = apiStatus is Map
          ? '${apiStatus['message'] ?? 'Unknown provider error'}'
          : 'Missing provider status';
      throw StateError('ABA PayWay transaction check failed: $message');
    }
    if (apiStatus['tran_id'] != null && apiStatus['tran_id'] != tranId) {
      throw StateError('ABA PayWay returned a mismatched transaction ID');
    }
    return data;
  }

  String _requestTime(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}'
      '${time.month.toString().padLeft(2, '0')}'
      '${time.day.toString().padLeft(2, '0')}'
      '${time.hour.toString().padLeft(2, '0')}'
      '${time.minute.toString().padLeft(2, '0')}'
      '${time.second.toString().padLeft(2, '0')}';

  String _encodeReturnDeeplink(Map<String, String>? deepLink) {
    if (deepLink == null) return '';
    final iosScheme = deepLink['ios_scheme'];
    final androidScheme = deepLink['android_scheme'];
    if (iosScheme == null ||
        androidScheme == null ||
        !_isAppLink(iosScheme) ||
        !_isAppLink(androidScheme)) {
      throw FormatException(
        'returnDeeplink must include valid ios_scheme and android_scheme URLs',
      );
    }
    return base64.encode(utf8.encode(jsonEncode({
      'ios_scheme': iosScheme,
      'android_scheme': androidScheme,
    })));
  }

  bool _isAppLink(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://[^\s]+$').hasMatch(value);
}
