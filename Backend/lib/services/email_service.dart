import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

class EmailDeliveryException implements Exception {
  const EmailDeliveryException(this.message);

  final String message;
}

class ResendEmailService {
  ResendEmailService({
    http.Client? client,
    String? apiKey,
    String? from,
  })  : _client = client,
        _apiKey = apiKey,
        _from = from;

  static final _sharedClient = http.Client();
  final http.Client? _client;
  final String? _apiKey;
  final String? _from;

  Future<void> sendVerificationCode(String email, String code) async {
    late final String apiKey;
    late final String from;
    try {
      apiKey = _apiKey ?? Env.resendApiKey;
      from = _from ?? Env.emailFrom;
    } on StateError {
      throw const EmailDeliveryException(
        'Email delivery is not configured on the server.',
      );
    }

    late final http.Response response;
    try {
      response = await (_client ?? _sharedClient)
          .post(
            Uri.https('api.resend.com', '/emails'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': from,
              'to': [email],
              'subject': 'Verify your Cambodia Shop account',
              'text': 'Your Cambodia Shop verification code is $code. '
                  'It expires in 10 minutes.',
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw const EmailDeliveryException(
        'Could not connect to the email delivery service.',
      );
    } on TimeoutException {
      throw const EmailDeliveryException(
        'Email delivery timed out. Please try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmailDeliveryException(
        'Email provider rejected the verification email '
        '(status ${response.statusCode}).',
      );
    }
  }
}
