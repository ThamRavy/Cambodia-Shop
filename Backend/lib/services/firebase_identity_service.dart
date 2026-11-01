import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

class FirebaseIdentityException implements Exception {
  const FirebaseIdentityException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;
}

class FirebaseIdentity {
  const FirebaseIdentity({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.displayName,
  });

  final String uid;
  final String email;
  final bool emailVerified;
  final String displayName;
}

class FirebaseIdentityService {
  FirebaseIdentityService({http.Client? client, String? apiKey})
      : _client = client,
        _apiKey = apiKey;

  static final _sharedClient = http.Client();
  final http.Client? _client;
  final String? _apiKey;

  Future<FirebaseIdentity> verifyIdToken(String idToken) async {
    if (idToken.trim().isEmpty) {
      throw const FirebaseIdentityException(
        'A Firebase ID token is required.',
        statusCode: 401,
      );
    }

    final apiKey = _apiKey ?? Env.firebaseWebApiKey;
    late final http.Response response;
    try {
      response = await (_client ?? _sharedClient)
          .post(
            Uri.https(
              'identitytoolkit.googleapis.com',
              '/v1/accounts:lookup',
              {'key': apiKey},
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 10));
    } on http.ClientException {
      throw const FirebaseIdentityException(
        'Could not verify the Firebase sign-in. Please try again.',
        statusCode: 503,
      );
    } on TimeoutException {
      throw const FirebaseIdentityException(
        'Firebase sign-in verification timed out. Please try again.',
        statusCode: 503,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isInvalidIdTokenResponse(response)) {
        throw const FirebaseIdentityException(
          'The Firebase sign-in token is invalid or expired.',
          statusCode: 401,
        );
      }
      throw FirebaseIdentityException(
        'Firebase could not verify the sign-in right now.',
        statusCode: 503,
      );
    }

    late final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const FirebaseIdentityException(
        'Firebase returned an invalid sign-in response.',
        statusCode: 503,
      );
    } on TypeError {
      throw const FirebaseIdentityException(
        'Firebase returned an invalid sign-in response.',
        statusCode: 503,
      );
    }

    final accounts = body['users'];
    if (accounts is! List || accounts.isEmpty || accounts.first is! Map) {
      throw const FirebaseIdentityException(
        'The Firebase sign-in token is invalid or expired.',
        statusCode: 401,
      );
    }
    final user = Map<String, dynamic>.from(accounts.first as Map);
    final uid = user['localId'];
    final email = user['email'];
    if (uid is! String || uid.isEmpty || email is! String || email.isEmpty) {
      throw const FirebaseIdentityException(
        'The Firebase account is missing its email address.',
        statusCode: 401,
      );
    }

    return FirebaseIdentity(
      uid: uid,
      email: email,
      emailVerified: user['emailVerified'] == true,
      displayName:
          user['displayName'] is String ? user['displayName'] as String : '',
    );
  }

  bool _isInvalidIdTokenResponse(http.Response response) {
    if (response.statusCode == 401) return true;
    if (response.statusCode != 400) return false;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'];
      final message = error is Map ? error['message'] : null;
      return message == 'INVALID_ID_TOKEN' ||
          message == 'TOKEN_EXPIRED' ||
          message == 'USER_DISABLED';
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }
}
