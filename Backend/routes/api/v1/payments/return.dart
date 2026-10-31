import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/controllers/payment_controller.dart';

Future<Response> onRequest(RequestContext context) =>
    PaymentController.paymentReturn(context);
