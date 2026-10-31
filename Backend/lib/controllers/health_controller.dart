import 'package:dart_frog/dart_frog.dart';

class HealthController {
  static Response handle(RequestContext context) => Response.json(
        body: {'status': 'ok', 'service': 'cambodia-shop-api'},
      );
}
