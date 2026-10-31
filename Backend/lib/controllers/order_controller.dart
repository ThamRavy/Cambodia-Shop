import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/services/order_service.dart';
import 'package:ecommerce_api/services/security.dart';

class OrderController {
  static Future<Response> index(RequestContext context) async {
    final principal = principalFrom(context);
    if (principal == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    if (context.request.method != HttpMethod.get &&
        context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    if (principal.role != 'customer') {
      return Response.json(statusCode: 403, body: {'error': 'forbidden'});
    }
    final service = OrderService(context.read<Db>());
    if (context.request.method == HttpMethod.get) {
      final orders = await service.listForUser(principal.id);
      return Response.json(body: {'items': orders});
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final order = await service.create(principal.id, body);
      return Response.json(statusCode: 201, body: order);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on StateError catch (error) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'checkout_conflict', 'message': error.message},
      );
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'bad_request'});
    }
  }

  static Future<Response> show(RequestContext context, String id) async {
    if (context.request.method != HttpMethod.get) {
      return Response(statusCode: 405);
    }
    final principal = principalFrom(context);
    if (principal == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    final order =
        await OrderService(context.read<Db>()).getForUser(id, principal.id);
    if (order == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: order);
  }
}
