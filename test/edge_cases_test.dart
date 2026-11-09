import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/format.dart';
import 'package:trip_weave/logic/trip_rules.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/state/trip_store.dart';

class _BrokenStore implements TripStore {
  int writes = 0;

  @override
  Future<TripSnapshot?> read() async => throw const FileSystemException('읽기 실패');

  @override
  Future<void> write(String encoded) async {
    writes += 1;
    throw const FileSystemException('디스크 가득 참');
  }
}

Map<String, Object?> _trip(String id, {Object? start = '2026-12-01T00:00:00.000', Object? end = '2026-12-03T00:00:00.000'}) {
  return {'id': id, 'title': '여행 $id', 'countryCode': 'KR', 'countryName': '대한민국', 'start': start, 'end': end, 'status': 'draft'};
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trip_weave_edge');
    file = File('${directory.path}/trips.json');
  });

  tearDown(() => directory.delete(recursive: true));

  test('저장 파일이 없거나 비어 있으면 샘플 여행으로 시작한다', () async {
    final store = FileTripStore(file);
    expect(await store.read(), isNull);
    await file.writeAsString('   ');
    final controller = TripController(store: store);
    await controller.restore();
    expect(controller.trips, isNotEmpty);
  });

  test('깨진 저장 파일은 옆으로 옮겨 두고 샘플로 시작한다', () async {
    await file.writeAsString('{"trips": [ {"id": "trip-1", ');
    final store = FileTripStore(file);
    final controller = TripController(store: store);
    await controller.restore();
    expect(controller.trips.map((trip) => trip.id), buildSampleCatalog().trips.map((trip) => trip.id));
    expect(file.existsSync(), isFalse);
    expect(store.corruptCopy.readAsStringSync(), startsWith('{"trips"'));

    await file.writeAsString('[1, 2, 3]');
    expect(await store.read(), isNull);
    await file.writeAsString('{"version": 1}');
    expect(await store.read(), isNull);
  });

  test('날짜나 id가 깨진 여행만 빼고 나머지는 읽는다', () {
    final snapshot = decodeTripSnapshot(
      jsonEncode({
        'version': 1,
        'currentTripId': 'trip-gone',
        'nextSeq': 3,
        'trips': [
          _trip('trip-ok'),
          _trip('trip-bad-date', start: 'not-a-date'),
          _trip('trip-no-end', end: null),
          {..._trip('trip-ok'), 'title': '중복'},
          {..._trip(''), 'title': 'id 없음'},
          'not a map',
          {
            ..._trip('trip-150', start: '2026-12-09T00:00:00.000', end: '2026-12-02T00:00:00.000'),
            'budgetCurrency': 7,
            'cities': [
              {'id': 'city-151', 'name': '부산', 'start': 'yesterday'},
            ],
            'activeDays': [
              {'date': 'nope', 'items': []},
              {
                'date': '2026-12-03T00:00:00.000',
                'items': [
                  {'id': 'i', 'kind': 'stay', 'title': 3, 'placeId': 9, 'start': 'x'},
                ],
              },
            ],
          },
        ],
      }),
    );
    expect(snapshot.trips.map((trip) => trip.id), ['trip-ok', 'trip-150']);
    expect(snapshot.trips.first.title, '여행 trip-ok');
    expect(snapshot.currentTripId, isNull);
    expect(snapshot.nextSeq, 152);

    final swapped = snapshot.trips.last;
    expect(swapped.start, DateTime(2026, 12, 2));
    expect(swapped.end, DateTime(2026, 12, 9));
    expect(swapped.budgetCurrency, isNull);
    expect(swapped.cities.single.start, swapped.start);
    expect(swapped.activeDays, hasLength(1));
    final item = swapped.activeDays.single.items.single;
    expect(item.placeId, isNull);
    expect(item.start, isNull);
  });

  test('도시 위치 후보 id가 없는 v1 파일도 읽고, 있으면 그대로 돌려 쓴다', () {
    final v1 = decodeTripSnapshot(
      jsonEncode({
        'version': 1,
        'trips': [
          {
            ..._trip('trip-1'),
            'cities': [
              {'id': 'c', 'name': '부산', 'countryCode': 'KR', 'coordinateConfirmed': true, 'coordinateLabel': '35.1, 129.0'},
            ],
          },
        ],
      }),
    );
    expect(v1.trips.single.cities.single.coordinateCandidateId, isNull);
    expect(v1.trips.single.cities.single.coordinateLabel, '35.1, 129.0');
    v1.trips.single.cities.single.coordinateCandidateId = 'busan-0';
    final again = decodeTripSnapshot(encodeTripSnapshot(v1));
    expect(again.trips.single.cities.single.coordinateCandidateId, 'busan-0');
  });

  test('새 여행 id는 파일에 있던 번호와 겹치지 않는다', () async {
    final store = FileTripStore(file);
    await store.write(jsonEncode({
      'version': 1,
      'nextSeq': 100,
      'currentTripId': 'trip-100',
      'trips': [_trip('trip-100')]
    }));
    final controller = TripController(store: store);
    await controller.restore();
    final error = controller.createTrip(TripDraft(title: '새 여행', countryCode: 'KR', start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 2)));
    expect(error, isNull);
    expect(controller.trips.map((trip) => trip.id).toSet(), hasLength(2));
    await controller.persistenceSettled;
  });

  test('읽기와 저장이 실패해도 앱 상태는 남고 마지막 실패를 알려 준다', () async {
    final store = _BrokenStore();
    final controller = TripController(store: store);
    await controller.restore();
    expect(controller.trips, isNotEmpty);
    controller.toggleSaved('wharf');
    controller.toggleSaved('park');
    await controller.persistenceSettled;
    expect(store.writes, 2);
    expect(controller.lastSaveError, isA<FileSystemException>());
  });

  test('여행이 하나도 없는 파일은 빈 목록으로 읽는다', () async {
    final store = FileTripStore(file);
    await store.write(jsonEncode({'version': 1, 'nextSeq': 100, 'currentTripId': null, 'trips': []}));
    final controller = TripController(store: store);
    await controller.restore();
    expect(controller.trips, isEmpty);
    expect(controller.current, isNull);
  });

  test('아주 긴 이름과 긴 기간은 입력 단계에서 막는다', () {
    final draft = TripDraft(title: '가' * (maxTitleLength + 1), countryCode: 'KR', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 2));
    draft.cities.add(CityDraft(name: '나' * (maxCityNameLength + 1), countryCode: 'KR', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2)));
    final errors = validateTripDraft(draft);
    expect(errors['title'], '제목은 $maxTitleLength자 이하로 입력하세요.');
    expect(errors['end'], '여행 기간은 $maxTripDays일 이하여야 합니다.');
    expect(errors['city-0-name'], '도시 이름은 $maxCityNameLength자 이하로 입력하세요.');

    final leap = TripDraft(title: '윤년', countryCode: 'KR', start: DateTime(2028, 2, 28), end: DateTime(2028, 3, 1));
    leap.cities.add(CityDraft(name: '서울', countryCode: 'KR', start: DateTime(2028, 2, 29), end: DateTime(2028, 2, 29)));
    expect(validateTripDraft(leap), isEmpty);
    final oneDay = TripDraft(title: '당일', countryCode: 'KR', start: DateTime(2026, 12, 31, 23), end: DateTime(2026, 12, 31, 1));
    expect(validateTripDraft(oneDay), isEmpty);
  });

  test('도시가 없거나 많은 여행과 제목 없는 여행을 짧게 보여 준다', () {
    final trip = Trip(id: 't', title: '  ', countryCode: 'KR', countryName: '대한민국', start: DateTime(2026, 12, 31), end: DateTime(2027, 1, 2), status: TripStatus.draft, cities: []);
    expect(displayTitle(trip.title), '제목 없는 여행');
    expect(citySummary(trip), '도시 없음');
    for (var index = 0; index < 5; index++) {
      trip.cities.add(City(id: 'c$index', name: index == 1 ? '' : '도시$index', countryCode: 'KR', start: trip.start, end: trip.end, sortOrder: index));
    }
    expect(citySummary(trip), '도시0, 이름 없는 도시, 도시2 외 2곳 · 도시 5곳');
    expect(formatRange(trip.start, trip.end), '2026.12.31 – 2027.1.2');
    expect(cityTripLabel(null, ''), '제목 없는 여행');
  });
}
