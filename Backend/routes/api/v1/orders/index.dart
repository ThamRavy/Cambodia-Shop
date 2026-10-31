import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/order_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    OrderController.index(context);
