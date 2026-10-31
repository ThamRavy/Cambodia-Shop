import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/health_controller.dart';

Response onRequest(RequestContext context) => HealthController.handle(context);
