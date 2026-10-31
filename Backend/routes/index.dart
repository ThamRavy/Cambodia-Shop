import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) => Response.json(
      body: {
        'name': 'Ecommerce API',
        'status': 'ok',
        'health': '/health',
        'api': '/api/v1',
      },
    );
