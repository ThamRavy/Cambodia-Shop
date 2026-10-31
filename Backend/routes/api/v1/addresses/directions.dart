
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  // Accept POST requests only.
  if (request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      headers: {'Allow': 'POST'},
      body: {
        'success': false,
        'message': 'Method not allowed. Use POST.',
      },
    );
  }

  // Parse the incoming JSON.
  dynamic decodedBody;

  try {
    decodedBody = await request.json();
  } catch (_) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Invalid JSON request body.',
      },
    );
  }

  if (decodedBody is! Map) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Request body must be a JSON object.',
      },
    );
  }

  final body = decodedBody;

  // Read and validate latitude and longitude.
  final latitude = _parseCoordinate(body['latitude']);
  final longitude = _parseCoordinate(body['longitude']);

  if (latitude == null || longitude == null) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message':
            'Latitude and longitude must be valid numbers.',
      },
    );
  }

  if (latitude < -90 || latitude > 90) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Latitude must be between -90 and 90.',
      },
    );
  }

  if (longitude < -180 || longitude > 180) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Longitude must be between -180 and 180.',
      },
    );
  }

  // Optional starting location.
  // If omitted, Google Maps can use the customer's location
  // or let the customer choose a starting point.
  final originValue = body['origin'];

  if (originValue != null && originValue is! String) {
    return Response.json(
      statusCode: 400,
      body: {
        'success': false,
        'message': 'Origin must be a string.',
      },
    );
  }

  final origin = originValue?.trim();

  // Create the Google Maps directions URL.
  final queryParameters = <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  };

  if (origin != null && origin.isNotEmpty) {
    queryParameters['origin'] = origin;
  }

  final directionsUrl = Uri.https(
    'www.google.com',
    '/maps/dir/',
    queryParameters,
  ).toString();

  // Return the URL to the client.
  return Response.json(
    body: {
      'success': true,
      'message': 'Google Maps directions URL generated.',
      'destination': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'directionsUrl': directionsUrl,
    },
  );
}

double? _parseCoordinate(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
