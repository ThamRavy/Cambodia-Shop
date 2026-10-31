import 'dart:convert';

import 'package:crypto/crypto.dart';

class PaywayHash {
  static const _purchaseFields = [
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

  static String purchase({
    required Map<String, String> fields,
    required String hmacKey,
  }) {
    final payload = _purchaseFields.map((field) => fields[field] ?? '').join();
    return _sign(payload, hmacKey);
  }

  static String checkTransaction({
    required String reqTime,
    required String merchantId,
    required String tranId,
    required String hmacKey,
  }) =>
      _sign('$reqTime$merchantId$tranId', hmacKey);

  static String _sign(String payload, String hmacKey) {
    final digest =
        Hmac(sha512, utf8.encode(hmacKey)).convert(utf8.encode(payload));
    return base64.encode(digest.bytes);
  }
}
