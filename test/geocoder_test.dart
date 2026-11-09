import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/logic/trip_rules.dart';
import 'package:trip_weave/logic/geocoder.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/state/trip_store.dart';

void main() {
  test('오프라인 샘플 지오코더는 상하이만 돌려준다', () async {
    final geocoder = OfflineSampleGeocoder();
    final shanghai = await geocoder.search('상하이');
    expect(shanghai, isNotEmpty);
    expect(shanghai.first.sourceName, 'mock 지오코더');
    expect(await geocoder.search('서울'), isEmpty);
  });

  test('합성 지오코더는 원격 실패 시 샘플만 쓴다', () async {
    final geocoder = CompositeCityGeocoder(
      online: _ThrowingGeocoder(),
      offline: OfflineSampleGeocoder(),
    );
    final found = await geocoder.search('상하이');
    expect(found.first.coordinateLabel, '31.2304, 121.4737');
  });

  test('부산 여행은 Nominatim 대신 주입 지오코더로 위치를 확인한다', () async {
    final geocoder = _SeoulGeocoder();
    final controller = TripController(geocoder: geocoder);
    final error = controller.createTrip(
      TripDraft(
        title: '부산 바다',
        countryCode: 'KR',
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 2),
        cities: [CityDraft(name: '부산', countryCode: 'KR', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 2))],
      ),
    );
    expect(error, isNull);
    final city = controller.current!.cities.single;
    await controller.findCandidates(city.id);
    expect(controller.cityCandidates[city.id], hasLength(1));
    controller.pickCandidate(city.id, controller.cityCandidates[city.id]!.single);
    expect(city.coordinateConfirmed, isTrue);
    expect(city.coordinateSource, '테스트 지오코더');
  });

  test('직접 추가한 장소는 dataOriginMock이 아니고 일정 제안에 쓸 수 있다', () async {
    final controller = TripController(geocoder: _SeoulGeocoder());
    final error = controller.createTrip(
      TripDraft(
        title: '오사카 맛집',
        countryCode: 'JP',
        start: DateTime(2026, 12, 5),
        end: DateTime(2026, 12, 6),
        cities: [CityDraft(name: '오사카', countryCode: 'JP', start: DateTime(2026, 12, 5), end: DateTime(2026, 12, 6))],
      ),
    );
    expect(error, isNull);
    final city = controller.current!.cities.single;
    await controller.findCandidates(city.id);
    controller.pickCandidate(city.id, controller.cityCandidates[city.id]!.single);
    controller.selectCity(city.id);
    expect(controller.addUserPlace(name: '도톤보리 산책', category: PlaceCategory.attraction, cityName: city.name), isNull);
    final added = controller.places.last;
    expect(added.dataOriginMock, isFalse);
    expect(added.claims.single.sourceKind, SourceKind.user);
    controller.setDecision(added.id, Decision.selected);
    controller.requestItinerary();
    final titles = controller.current!.proposalDays!.expand((day) => day.items).map((item) => item.title);
    expect(titles, contains('도톤보리 산책'));
  });

  test('사용자 장소는 스냅샷에 저장된다', () async {
    final directory = await Directory.systemTemp.createTemp('trip_weave_places');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final geocoder = _SeoulGeocoder();
    final first = TripController(store: store, geocoder: geocoder);
    first.createTrip(
      TripDraft(
        title: '제주',
        countryCode: 'KR',
        start: DateTime(2026, 12, 10),
        end: DateTime(2026, 12, 11),
        cities: [CityDraft(name: '제주', countryCode: 'KR', start: DateTime(2026, 12, 10), end: DateTime(2026, 12, 11))],
      ),
    );
    final city = first.current!.cities.single;
    await first.findCandidates(city.id);
    first.pickCandidate(city.id, first.cityCandidates[city.id]!.single);
    first.addUserPlace(name: '협재 해수욕장', category: PlaceCategory.attraction, cityName: city.name);
    await first.persistenceSettled;

    final second = TripController(store: store, geocoder: geocoder);
    await second.restore();
    expect(second.places.any((place) => place.name == '협재 해수욕장'), isTrue);
    expect(second.places.singleWhere((place) => place.name == '협재 해수욕장').dataOriginMock, isFalse);
    await directory.delete(recursive: true);
  });
}

class _ThrowingGeocoder implements CityGeocoder {
  @override
  Future<List<GeoCandidate>> search(String query, {String? countryCode}) async {
    throw StateError('network');
  }
}

class _SeoulGeocoder implements CityGeocoder {
  @override
  Future<List<GeoCandidate>> search(String query, {String? countryCode}) async {
    if (query.trim().isEmpty) return const [];
    return [
      GeoCandidate(
        id: 'test-center',
        label: '$query 중심 (테스트)',
        coordinateLabel: '37.5665, 126.9780',
        sourceName: '테스트 지오코더',
      ),
    ];
  }
}
