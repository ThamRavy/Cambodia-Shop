import 'package:test/test.dart';
import 'package:ecommerce_api/services/geo_service.dart';
void main(){
 test('GeoJSON coordinates use longitude then latitude',(){expect(GeoService.point(11.55,104.92)['coordinates'],[104.92,11.55]);});
 test('rejects out of range latitude',(){expect(()=>GeoService.point(91,0),throwsFormatException);});
 test('Google Maps directions URL includes destination',(){expect(GeoService.googleMapsDirectionsUrl(latitude:11.55,longitude:104.92),contains('destination=11.55,104.92'));});
}
