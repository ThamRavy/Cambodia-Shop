// ignore_for_file: file_names

import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/product_controller.dart';

Future<Response> onRequest(RequestContext context, String id) =>
    ProductController.show(context, id);
