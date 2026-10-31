import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/api_controller.dart';

Response onRequest(RequestContext context) => ApiController.handle(context);
