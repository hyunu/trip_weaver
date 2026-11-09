import '../map/geo.dart';
import '../model/models.dart';

Place buildUserPlace({
  required String id,
  required String name,
  required PlaceCategory category,
  required String cityName,
  required GeoPoint point,
  DateTime? collectedAt,
}) {
  final stamp = collectedAt ?? DateTime.now();
  final coordinate = '${point.lat.toStringAsFixed(4)}, ${point.lon.toStringAsFixed(4)}';
  return Place(
    id: id,
    name: name.trim(),
    category: category,
    cityName: cityName.trim(),
    dataOriginMock: false,
    claims: [
      Claim(
        field: 'coordinate',
        value: coordinate,
        validity: FactValidity.collected,
        sourceName: '직접 입력',
        sourceKind: SourceKind.user,
        collectedAt: stamp,
      ),
    ],
  );
}

GeoCandidate candidateFromPoint(GeoPoint point, {required String label, String id = 'map-pick'}) {
  return GeoCandidate(
    id: id,
    label: label,
    coordinateLabel: '${point.lat.toStringAsFixed(4)}, ${point.lon.toStringAsFixed(4)}',
    sourceName: '지도에서 직접 고름',
  );
}
