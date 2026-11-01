import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/services/auth_service.dart';
import 'package:ecommerce_api/services/email_service.dart';

class AuthController {
  static Future<Response> login(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      return Response.json(
        body: await AuthService(context.read<Db>())
            .login('${body['email'] ?? ''}', '${body['password'] ?? ''}'),
      );
    } on EmailNotVerifiedException {
      return Response.json(
        statusCode: 403,
        body: {
          'error': 'email_not_verified',
          'message': 'We sent a verification code to your email address.',
        },
      );
    } on AuthRateLimitException catch (error) {
      return Response.json(
        statusCode: 429,
        body: {'error': 'rate_limited', 'message': error.message},
      );
    } on EmailDeliveryException catch (error) {
      return Response.json(
        statusCode: 503,
        body: {'error': 'email_delivery_failed', 'message': error.message},
      );
    } on FormatException {
      return Response.json(
        statusCode: 401,
        body: {
          'error': 'invalid_credentials',
          'message': 'Invalid email or password',
        },
      );
    } catch (_) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'internal_server_error'},
      );
    }
  }

  static Future<Response> register(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      await AuthService(context.read<Db>()).register(
        '${body['email'] ?? ''}',
        '${body['password'] ?? ''}',
        '${body['name'] ?? ''}',
      );
      return Response.json(
        statusCode: 202,
        body: {
          'email': '${body['email']}'.trim().toLowerCase(),
          'message': 'Check your email for a six-digit verification code.',
        },
      );
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on AuthConflictException catch (error) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'conflict', 'message': error.message},
      );
    } on AuthRateLimitException catch (error) {
      return Response.json(
        statusCode: 429,
        body: {'error': 'rate_limited', 'message': error.message},
      );
    } on EmailDeliveryException catch (error) {
      return Response.json(
        statusCode: 503,
        body: {'error': 'email_delivery_failed', 'message': error.message},
      );
    } catch (_) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'internal_server_error'},
      );
    }
  }

  static Future<Response> verifyEmail(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final result = await AuthService(context.read<Db>()).verifyEmail(
        '${body['email'] ?? ''}',
        '${body['code'] ?? ''}',
      );
      return Response.json(body: result);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on AuthConflictException catch (error) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'conflict', 'message': error.message},
      );
    } on AuthRateLimitException catch (error) {
      return Response.json(
        statusCode: 429,
        body: {'error': 'rate_limited', 'message': error.message},
      );
    } catch (_) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'internal_server_error'},
      );
    }
  }
}
