import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:ecommerce_api/services/auth_service.dart';
import 'package:ecommerce_api/services/firebase_identity_service.dart';

class AuthController {
  static Future<Response> login(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }

    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(await context.request.body());
      if (decoded is! Map<String, dynamic>) {
        return _invalidRequest();
      }
      body = decoded;
    } on FormatException {
      return _invalidRequest();
    }

    final idToken = body['idToken'];
    if (idToken is! String || idToken.isEmpty) return _invalidRequest();

    try {
      final result =
          await AuthService(context.read<Db>()).loginWithFirebase(idToken);
      return Response.json(body: result);
    } on FirebaseIdentityException catch (error) {
      return Response.json(
        statusCode: error.statusCode,
        body: {
          'error': error.statusCode == 401
              ? 'invalid_firebase_token'
              : 'firebase_unavailable',
          'message': error.message,
        },
      );
    } on FirebaseEmailNotVerifiedException {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'email_not_verified',
          'message': 'Verify your email address before signing in.',
        },
      );
    } on AuthConflictException catch (error) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'account_conflict', 'message': error.message},
      );
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_firebase_account', 'message': error.message},
      );
    } on StateError {
      return Response.json(
        statusCode: 503,
        body: {
          'error': 'firebase_not_configured',
          'message': 'Firebase sign-in is not configured on the API server.',
        },
      );
    }
  }

  static Future<Response> register(RequestContext context) =>
      _legacyEndpoint(context);

  static Future<Response> verifyEmail(RequestContext context) =>
      _legacyEndpoint(context);

  static Future<Response> _legacyEndpoint(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    return Response.json(
      statusCode: 410,
      body: {
        'error': 'auth_provider_migrated',
        'message': 'Use Firebase email/password sign-in in the storefront.',
      },
    );
  }

  static Response _invalidRequest() => Response.json(
        statusCode: 400,
        body: {
          'error': 'invalid_request',
          'message': 'A Firebase ID token is required.',
        },
      );
}
