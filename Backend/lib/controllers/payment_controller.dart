import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ecommerce_api/services/payment_service.dart';
import 'package:ecommerce_api/services/security.dart';

class PaymentController {
  static Future<Response> checkout(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    final principal = principalFrom(context);
    if (principal == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final rawReturnDeeplink = body['returnDeeplink'];
      Map<String, String>? returnDeeplink;
      if (rawReturnDeeplink != null) {
        if (rawReturnDeeplink is! Map ||
            rawReturnDeeplink['ios_scheme'] is! String ||
            rawReturnDeeplink['android_scheme'] is! String) {
          throw FormatException(
            'returnDeeplink must include ios_scheme and android_scheme',
          );
        }
        returnDeeplink = {
          'ios_scheme': rawReturnDeeplink['ios_scheme'] as String,
          'android_scheme': rawReturnDeeplink['android_scheme'] as String,
        };
      }
      final checkout = await PaymentService(context.read<Db>()).createCheckout(
        orderId: '${body['orderId'] ?? ''}',
        userId: principal.id,
        paymentOption: '${body['paymentOption'] ?? ''}',
        returnDeeplink: returnDeeplink,
      );
      return Response.json(body: checkout);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on StateError catch (error) {
      if (error.message == 'order_not_found_or_already_paid') {
        return Response.json(
          statusCode: 404,
          body: {'error': 'order_not_found_or_already_paid'},
        );
      }
      if (error.message == 'unauthorized') {
        return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
      }
      return Response.json(
        statusCode: 503,
        body: {
          'error': 'payment_provider_unavailable',
          'message': error.message,
        },
      );
    } catch (_) {
      return Response.json(statusCode: 400, body: {'error': 'checkout_failed'});
    }
  }

  static Future<Response> paymentReturn(RequestContext context) async {
    // A browser redirect alone must never be treated as payment confirmation.
    if (context.request.method != HttpMethod.post &&
        context.request.method != HttpMethod.get) {
      return Response(statusCode: 405);
    }
    final isPost = context.request.method == HttpMethod.post;
    final raw =
        isPost ? await context.request.body() : context.request.uri.query;
    final parameters = isPost
        ? Map<String, dynamic>.from(Uri.splitQueryString(raw))
        : context.request.uri.queryParameters;
    final transactionId =
        '${parameters['tran_id'] ?? parameters['tranId'] ?? ''}';
    if (transactionId.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'missing_transaction_id'},
      );
    }
    final found =
        await PaymentService(context.read<Db>()).hasTransaction(transactionId);
    if (!found) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'payment_not_found'},
      );
    }
    return Response.json(
      statusCode: 202,
      body: {
        'status': 'verification_pending',
        'tranId': transactionId,
        'message':
            'Return redirect is not payment confirmation; server-side reconciliation is required.',
      },
    );
  }

  static Future<Response> verify(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    final principal = principalFrom(context);
    if (principal == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final result = await PaymentService(context.read<Db>()).verifyTransaction(
        transactionId: '${body['tranId'] ?? ''}',
        userId: principal.id,
      );
      return Response.json(body: result);
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    } on StateError catch (error) {
      if (error.message == 'payment_not_found') {
        return Response.json(
          statusCode: 404,
          body: {'error': 'payment_not_found'},
        );
      }
      if (error.message.contains('rate limit')) {
        return Response.json(
          statusCode: 429,
          body: {
            'error': 'payment_provider_rate_limit',
            'message': 'Wait before checking this transaction again.',
          },
        );
      }
      return Response.json(
        statusCode: 502,
        body: {
          'error': 'payment_verification_failed',
          'message': error.message,
        },
      );
    } catch (_) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'bad_request'},
      );
    }
  }
}
