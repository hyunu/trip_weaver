import '../model/models.dart';
import 'geo.dart';

class MapPin {
  const MapPin({required this.id, required this.placeId, required this.point, required this.label, this.order, this.emphasized = false, this.nearby = false, this.past = false});

  final String id;
  final String placeId;
  final GeoPoint point;
  final String label;
  final int? order;
  final bool emphasized;
  final bool nearby;
  final bool past;
}

List<MapPin> visitPins(DayPlan? day, Place? Function(String? id) lookup, {String? emphasizePlaceId, DateTime? now}) {
  if (day == null) return const [];
  final pins = <MapPin>[];
  var order = 1;
  for (final item in day.items) {
    if (item.kind != ItemKind.stay && item.kind != ItemKind.meal) continue;
    final place = lookup(item.placeId);
    final point = place == null ? null : placeGeo(place);
    if (place == null || point == null) continue;
    final next = place.id == emphasizePlaceId;
    final ended = now != null && item.end != null && !item.end!.isAfter(now);
    pins.add(MapPin(id: item.id, placeId: place.id, point: point, label: item.title.isEmpty ? place.name : item.title, order: order, emphasized: next, past: ended && !next));
    order += 1;
  }
  return pins;
}

List<MapPin> nearbyPins(List<Place> places, GeoPoint focus, Set<String> skipIds, {double withinMeters = 1800}) {
  final pins = <MapPin>[];
  for (final place in places) {
    if (skipIds.contains(place.id)) continue;
    final point = placeGeo(place);
    if (point == null) continue;
    if (distanceMeters(focus, point) > withinMeters) continue;
    pins.add(MapPin(id: place.id, placeId: place.id, point: point, label: place.name, nearby: true));
  }
  return pins;
}

/// Numbered visit pins in visit order. Nearby pins have no order and are omitted.
List<MapPin> orderedVisitPins(List<MapPin> pins) {
  final visits = pins.where((pin) => pin.order != null).toList()..sort((a, b) => a.order!.compareTo(b.order!));
  return visits;
}

double visitRouteMeters(List<MapPin> pins) {
  final visits = orderedVisitPins(pins);
  var total = 0.0;
  for (var index = 1; index < visits.length; index++) {
    total += distanceMeters(visits[index - 1].point, visits[index].point);
  }
  return total;
}

List<MapPin> explorePins(List<Place> places, {String? selectedId}) {
  final pins = <MapPin>[];
  for (final place in places) {
    final point = placeGeo(place);
    if (point == null) continue;
    pins.add(MapPin(id: place.id, placeId: place.id, point: point, label: place.name, emphasized: place.id == selectedId));
  }
  return pins;
}
