import 'dart:math' as math;

import '../model/models.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;
}

GeoPoint? geoFromLabel(String? label) {
  if (label == null) return null;
  final parts = label.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return GeoPoint(lat, lon);
}

/// Uses a coordinate only when every claim agrees. A conflict is not collapsed into one pin.
GeoPoint? placeGeo(Place place) {
  final labels = place.claimsFor('coordinate').map((claim) => claim.value).whereType<String>().toList();
  if (labels.isEmpty) return null;
  final points = labels.map(geoFromLabel).whereType<GeoPoint>().toList();
  if (points.length != labels.length || points.isEmpty) return null;
  final first = points.first;
  for (final point in points.skip(1)) {
    if ((point.lat - first.lat).abs() > 0.00001 || (point.lon - first.lon).abs() > 0.00001) return null;
  }
  return first;
}

double distanceMeters(GeoPoint a, GeoPoint b) {
  const earth = 6371000.0;
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLon = (b.lon - a.lon) * math.pi / 180;
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(h.toDouble()));
}

String straightLineLabel(double meters) {
  if (meters < 1000) return '${meters.round()}m · 직선 거리';
  return '${(meters / 1000).toStringAsFixed(1)}km · 직선 거리';
}

/// Walking pace used only to turn a straight-line sum into minutes.
const straightWalkKmh = 4.5;

String formatMeters(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

int straightWalkMinutes(double meters) => (meters / (straightWalkKmh * 1000 / 60)).round();

/// Honest label for a visit-order straight line. [stops] is the number of numbered pins.
String routeEstimateLabel(double meters, int stops) {
  if (stops < 2) return '방문 순서를 이을 장소가 2곳 미만이라 직선 거리를 합산하지 않습니다.';
  final minutes = straightWalkMinutes(meters);
  return '방문 $stops곳 직선 ${formatMeters(meters)} · 도보 약 $minutes분 (시속 ${straightWalkKmh}km, 도로 경로 아님)';
}
