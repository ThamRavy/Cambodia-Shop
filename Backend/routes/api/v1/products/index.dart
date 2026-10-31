import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/product_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    ProductController.index(context);
