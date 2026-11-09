import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/logic/map_directions.dart';
import 'package:trip_weave/map/geo.dart';

void main() {
  test('좌표가 있으면 Google Maps 길찾기 링크를 만든다', () {
    final place = buildSampleCatalog().places.firstWhere((item) => item.id == 'gallery');
    final point = placeGeo(place)!;
    final uri = directionsUri(point: point, place: place)!;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '${point.lat},${point.lon}');
  });

  test('좌표가 없으면 현지어 이름으로 검색 링크를 만든다', () {
    final place = buildSampleCatalog().places.firstWhere((item) => item.id == 'market');
    final uri = directionsUri(place: place)!;
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['query'], place.localName);
  });
}
