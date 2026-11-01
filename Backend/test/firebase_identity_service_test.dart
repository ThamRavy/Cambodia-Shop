import 'dart:convert';

import 'package:ecommerce_api/services/firebase_identity_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('validates the ID token with Firebase and returns verified identity',
      () async {
    late http.Request request;
    final service = FirebaseIdentityService(
      apiKey: 'web-api-key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'users': [
              {
                'localId': 'firebase-user-id',
                'email': 'customer@example.com',
                'emailVerified': true,
                'displayName': 'Shop Customer',
              },
            ],
          }),
          200,
        );
      }),
    );

    final identity = await service.verifyIdToken('firebase-id-token');

    expect(
      request.url.origin,
      'https://identitytoolkit.googleapis.com',
    );
    expect(request.url.path, '/v1/accounts:lookup');
    expect(request.url.queryParameters['key'], 'web-api-key');
    expect(jsonDecode(request.body), {'idToken': 'firebase-id-token'});
    expect(identity.uid, 'firebase-user-id');
    expect(identity.email, 'customer@example.com');
    expect(identity.emailVerified, isTrue);
    expect(identity.displayName, 'Shop Customer');
  });

  test('rejects invalid ID tokens without exposing provider response',
      () async {
    final service = FirebaseIdentityService(
      apiKey: 'web-api-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'INVALID_ID_TOKEN'},
          }),
          400,
        ),
      ),
    );

    await expectLater(
      service.verifyIdToken('invalid-token'),
      throwsA(
        isA<FirebaseIdentityException>()
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('reports Firebase configuration errors as unavailable', () async {
    final service = FirebaseIdentityService(
      apiKey: 'web-api-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'API_KEY_INVALID'},
          }),
          400,
        ),
      ),
    );

    await expectLater(
      service.verifyIdToken('firebase-id-token'),
      throwsA(
        isA<FirebaseIdentityException>()
            .having((error) => error.statusCode, 'statusCode', 503),
      ),
    );
  });

  test('reports unverified Firebase email state for the caller to enforce',
      () async {
    final service = FirebaseIdentityService(
      apiKey: 'web-api-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'users': [
              {
                'localId': 'firebase-user-id',
                'email': 'customer@example.com',
                'emailVerified': false,
              },
            ],
          }),
          200,
        ),
      ),
    );

    final identity = await service.verifyIdToken('firebase-id-token');

    expect(identity.emailVerified, isFalse);
  });
}
