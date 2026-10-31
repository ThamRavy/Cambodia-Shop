import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/services/product_service.dart';
import 'package:ecommerce_api/services/security.dart';

class ProductController {
  static Future<Response> index(RequestContext context) async {
    final service = ProductService(context.read<Db>());
    if (context.request.method == HttpMethod.get) {
      final category = context.request.uri.queryParameters['category'];
      final products = await service.list(category: category);
      return Response.json(body: {'items': products});
    }
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    final principal = principalFrom(context);
    if (principal == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    if (principal.role != 'admin') {
      return Response.json(statusCode: 403, body: {'error': 'forbidden'});
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final created = await service.create(body);
      return Response.json(statusCode: 201, body: created);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } catch (_) {
      return Response.json(
          statusCode: 409, body: {'error': 'product_conflict'});
    }
  }

  static Future<Response> show(RequestContext context, String id) async {
    if (context.request.method != HttpMethod.get) {
      return Response(statusCode: 405);
    }
    final product = await ProductService(context.read<Db>()).getById(id);
    if (product == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: product);
  }
}
