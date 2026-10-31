import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/auth_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    AuthController.login(context);
