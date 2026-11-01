import 'dart:convert';

import 'package:ecommerce_api/services/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('sends verification email through Resend', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', 200);
    });
    final service = ResendEmailService(
      client: client,
      apiKey: 'test-api-key',
      from: 'Cambodia Shop <accounts@example.com>',
    );

    await service.sendVerificationCode('customer@example.com', '012345');

    expect(request.url, Uri.https('api.resend.com', '/emails'));
    expect(request.headers['authorization'], 'Bearer test-api-key');
    expect(jsonDecode(request.body), {
      'from': 'Cambodia Shop <accounts@example.com>',
      'to': ['customer@example.com'],
      'subject': 'Verify your Cambodia Shop account',
      'text':
          'Your Cambodia Shop verification code is 012345. It expires in 10 minutes.',
    });
    client.close();
  });

  test('reports rejected email delivery without exposing provider response',
      () async {
    final client =
        MockClient((_) async => http.Response('secret details', 401));
    final service = ResendEmailService(
      client: client,
      apiKey: 'test-api-key',
      from: 'accounts@example.com',
    );

    await expectLater(
      service.sendVerificationCode('customer@example.com', '012345'),
      throwsA(isA<EmailDeliveryException>()),
    );
    client.close();
  });
}
