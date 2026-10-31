class GeoService {
  static Map<String, dynamic> point(double latitude, double longitude) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw FormatException('Latitude/longitude out of range');
    }
    return {
      'type': 'Point',
      'coordinates': [longitude, latitude]
    };
  }

  static String googleMapsDirectionsUrl(
      {required double latitude, required double longitude}) {
    point(latitude, longitude);
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
  }
}
