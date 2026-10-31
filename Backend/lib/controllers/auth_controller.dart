import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/services/auth_service.dart';

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
    } on FormatException {
      return Response.json(
        statusCode: 401,
        body: {
          'error': 'invalid_credentials',
          'message': 'Invalid email or password',
        },
      );
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'bad_request'});
    }
  }

  static Future<Response> register(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final result = await AuthService(context.read<Db>()).register(
        '${body['email'] ?? ''}',
        '${body['password'] ?? ''}',
        '${body['name'] ?? ''}',
      );
      return Response.json(statusCode: 201, body: result);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on StateError catch (error) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'conflict', 'message': error.message},
      );
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'bad_request'});
    }
  }
}
