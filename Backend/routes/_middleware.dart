import 'dart:developer' as developer;

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/database/database.dart';
import 'package:ecommerce_api/config/env.dart';

Handler middleware(Handler handler) => (context) async {
      final origin = context.request.headers['origin'];
      final corsHeaders = _corsHeaders(origin);
      if (origin != null && corsHeaders == null) {
        return Response.json(
          statusCode: 403,
          body: {'error': 'origin_not_allowed'},
        );
      }
      if (context.request.method == HttpMethod.options) {
        if (origin == null) return Response(statusCode: 204);
        return Response(
          statusCode: 204,
          headers: {
            ...corsHeaders!,
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Authorization, Content-Type',
            'Access-Control-Max-Age': '600',
          },
        );
      }

      late final Db db;
      try {
        db = await Database.connect();
      } catch (error, stackTrace) {
        developer.log(
          'MongoDB connection failed',
          name: 'ecommerce_api.database',
          error: error,
          stackTrace: stackTrace,
        );
        return Response.json(statusCode: 503, body: {
          'error': 'service_unavailable',
          'message': 'Database is not ready'
        });
      }
      final response = await handler(context.provide<Db>(() => db));
      if (corsHeaders == null) return response;
      return response.copyWith(
        headers: {...response.headers, ...corsHeaders},
      );
    };

Map<String, String>? _corsHeaders(String? origin) {
  if (origin == null) return null;
  final uri = Uri.tryParse(origin);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      uri.path.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }

  final isLocalDevelopmentOrigin = uri.scheme == 'http' &&
      const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if (!isLocalDevelopmentOrigin && !Env.corsAllowedOrigins.contains(origin)) {
    return null;
  }

  return {
    'Access-Control-Allow-Origin': origin,
    'Vary': 'Origin',
  };
}
