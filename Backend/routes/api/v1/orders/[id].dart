// ignore_for_file: file_names

import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/order_controller.dart';

Future<Response> onRequest(RequestContext context, String id) =>
    OrderController.show(context, id);
