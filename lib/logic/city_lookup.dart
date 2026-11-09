import '../model/models.dart';

List<GeoCandidate> offlineCandidatesForCity(String name) {
  final key = name.trim().toLowerCase().replaceAll(' ', '');
  if (key.contains('상하이') || key.contains('shanghai') || key.contains('上海')) {
    return const [
      GeoCandidate(id: 'shanghai-people', label: '상하이 인민광장', coordinateLabel: '31.2304, 121.4737', sourceName: 'mock 지오코더'),
      GeoCandidate(id: 'shanghai-bund', label: '상하이 외탄', coordinateLabel: '31.2397, 121.4905', sourceName: 'mock 지오코더'),
    ];
  }
  if (key.contains('충밍') || key.contains('chongming') || key.contains('崇明')) {
    return const [
      GeoCandidate(id: 'chongming', label: '충밍 성시', coordinateLabel: '31.6229, 121.3974', sourceName: 'mock 지오코더'),
    ];
  }
  return const [];
}

/// Tests and legacy call sites.
List<GeoCandidate> candidatesForCity(String name) => offlineCandidatesForCity(name);

bool isCurrentLocation(City city, GeoCandidate candidate) {
  if (!city.coordinateConfirmed) return false;
  final id = city.coordinateCandidateId;
  if (id != null) return id == candidate.id;
  return city.coordinateLabel == candidate.coordinateLabel && city.coordinateSource == candidate.sourceName;
}
