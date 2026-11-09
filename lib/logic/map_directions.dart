import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../map/geo.dart';
import '../model/models.dart';

typedef MapDirectionsOpener = Future<bool> Function(Uri uri);

MapDirectionsOpener mapDirectionsOpener = launchDirectionsUri;

Future<bool> launchDirectionsUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Google Maps directions/search deep link for a confirmed coordinate or address query.
Uri? directionsUri({GeoPoint? point, Place? place}) {
  if (point != null) {
    return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${point.lat},${point.lon}');
  }
  if (place == null) return null;
  final name = place.localName?.trim();
  if (name != null && name.isNotEmpty) {
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}');
  }
  final address = addressLine(place);
  if (address == '주소 미확인' || address == '주소는 출처마다 다릅니다') return null;
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
}

Future<bool> openDirections({GeoPoint? point, Place? place, MapDirectionsOpener? opener}) async {
  final uri = directionsUri(point: point, place: place);
  if (uri == null) return false;
  final launch = opener ?? mapDirectionsOpener;
  try {
    return await launch(uri);
  } on Object catch (error, stack) {
    if (kDebugMode) {
      debugPrint('map directions failed: $error\n$stack');
    }
    return false;
  }
}
