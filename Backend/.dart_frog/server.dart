// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/health.dart' as health;
import '../routes/api/v1/index.dart' as api_v1_index;
import '../routes/api/v1/products/index.dart' as api_v1_products_index;
import '../routes/api/v1/products/[id].dart' as api_v1_products_$id;
import '../routes/api/v1/payments/verify.dart' as api_v1_payments_verify;
import '../routes/api/v1/payments/return.dart' as api_v1_payments_return;
import '../routes/api/v1/payments/checkout.dart' as api_v1_payments_checkout;
import '../routes/api/v1/orders/index.dart' as api_v1_orders_index;
import '../routes/api/v1/orders/[id].dart' as api_v1_orders_$id;
import '../routes/api/v1/auth/register.dart' as api_v1_auth_register;
import '../routes/api/v1/auth/login.dart' as api_v1_auth_login;
import '../routes/api/v1/addresses/directions.dart' as api_v1_addresses_directions;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/api/v1', (context) => buildApiV1Handler()(context))
    ..mount('/api/v1/products', (context) => buildApiV1ProductsHandler()(context))
    ..mount('/api/v1/payments', (context) => buildApiV1PaymentsHandler()(context))
    ..mount('/api/v1/orders', (context) => buildApiV1OrdersHandler()(context))
    ..mount('/api/v1/auth', (context) => buildApiV1AuthHandler()(context))
    ..mount('/api/v1/addresses', (context) => buildApiV1AddressesHandler()(context));
  return pipeline.addHandler(router);
}
Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/health', (context) => health.onRequest(context,))..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1Handler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => api_v1_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1ProductsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_v1_products_$id.onRequest(context,id,))..all('/', (context) => api_v1_products_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1PaymentsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/checkout', (context) => api_v1_payments_checkout.onRequest(context,))..all('/return', (context) => api_v1_payments_return.onRequest(context,))..all('/verify', (context) => api_v1_payments_verify.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1OrdersHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_v1_orders_$id.onRequest(context,id,))..all('/', (context) => api_v1_orders_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/login', (context) => api_v1_auth_login.onRequest(context,))..all('/register', (context) => api_v1_auth_register.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AddressesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/directions', (context) => api_v1_addresses_directions.onRequest(context,));
  return pipeline.addHandler(router);
}
