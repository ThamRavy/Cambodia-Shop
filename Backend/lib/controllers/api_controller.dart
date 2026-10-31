import 'package:dart_frog/dart_frog.dart';

class ApiController {
  static Response handle(RequestContext context) => Response.json(
        body: {
          'name': 'Cambodia Shop API',
          'version': '1.0.0',
          'docs': '/README.md',
        },
      );
}
