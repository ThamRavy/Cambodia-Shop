import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:ecommerce_api/services/geo_service.dart';

class AddressController {
  static Future<Response> directions(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: 405);
    }
    try {
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final latitude = body['latitude'];
      final longitude = body['longitude'];
      if (latitude is! num || longitude is! num) {
        throw FormatException('latitude and longitude are required');
      }
      return Response.json(
        body: {
          'directionsUrl': GeoService.googleMapsDirectionsUrl(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
        },
      );
    } on FormatException catch (error) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'invalid_input', 'message': error.message},
      );
    }
  }
}
