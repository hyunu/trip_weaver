import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/logic/city_lookup.dart';
import 'package:trip_weave/logic/trip_rules.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/state/trip_store.dart';

void main() {
  test('저장한 여행은 다시 읽으면 같고 샘플은 샘플로 남는다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_store');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final first = TripController(catalog: catalog, store: store);
    first.selectTrip('trip-river');
    final error = first.createTrip(
      TripDraft(
        title: '직접 만든 여행',
        countryCode: 'KR',
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 3),
        purpose: '저장 확인',
        tasteTags: const ['도보'],
        budgetAmount: '12000',
        budgetCurrency: 'KRW',
        companionCount: 2,
        cities: [
          CityDraft(name: '부산', countryCode: 'KR', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 2)),
        ],
      ),
    );
    expect(error, isNull);
    await first.persistenceSettled;

    final reloaded = TripController(catalog: catalog, store: store);
    await reloaded.restore();
    final created = reloaded.trips.singleWhere((trip) => trip.title == '직접 만든 여행');
    expect(created.dataOriginMock, isFalse);
    expect(created.purpose, '저장 확인');
    expect(created.budgetAmount, 12000);
    expect(created.budgetCurrency, 'KRW');
    expect(created.companionCount, 2);
    expect(created.tasteTags, ['도보']);
    expect(created.cities.single.name, '부산');
    expect(created.cities.single.countryCode, 'KR');
    expect(reloaded.currentTripId, created.id);

    final sample = reloaded.trips.singleWhere((trip) => trip.id == 'trip-river');
    expect(sample.dataOriginMock, isTrue);
    expect(sample.activeDays, isNotEmpty);
    expect(sample.proposalDays, isNotNull);
    expect(sample.cities.first.coordinateLabel, '31.2304, 121.4737');

    final again = TripController(catalog: catalog, store: store, now: DateTime(2027, 1, 2));
    await again.restore();
    expect(again.trips.map((trip) => trip.id), reloaded.trips.map((trip) => trip.id));
    expect(again.trips.singleWhere((trip) => trip.id == 'trip-river').dataOriginMock, isTrue);
    expect(again.trips.singleWhere((trip) => trip.title == '직접 만든 여행').dataOriginMock, isFalse);

    await directory.delete(recursive: true);
  });

  test('샘플 표시는 파일에서 빠져 있어도 샘플 여행에 다시 붙는다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_flag');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final controller = TripController(catalog: catalog, store: store);
    for (final trip in catalog.trips) {
      trip.dataOriginMock = false;
    }
    await store.write(encodeTripSnapshot(TripSnapshot(trips: catalog.trips, currentTripId: 'trip-south', nextSeq: 100)));
    await controller.restore();
    expect(controller.trips.every((trip) => trip.dataOriginMock), isTrue);
    expect(controller.currentTripId, 'trip-south');
    await directory.delete(recursive: true);
  });

  test('다시 고른 도시 위치는 저장되고 예전 파일도 그대로 읽힌다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_relocate');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final first = TripController(catalog: catalog, store: store);
    first.selectTrip('trip-river');
    await first.startRelocate('city-shanghai');
    first.pickCandidate('city-shanghai', first.cityCandidates['city-shanghai']![1]);
    await first.persistenceSettled;
    expect(await File('${directory.path}/trips.json').readAsString(), contains('"coordinateCandidateId":"shanghai-bund"'));

    final reloaded = TripController(catalog: buildSampleCatalog(), store: store);
    await reloaded.restore();
    final city = reloaded.trips.singleWhere((trip) => trip.id == 'trip-river').cities.first;
    expect(city.coordinateLabel, '31.2397, 121.4905');
    expect(city.coordinateCandidateId, 'shanghai-bund');

    final legacy = decodeTripSnapshot(
      encodeTripSnapshot(TripSnapshot(trips: buildSampleCatalog().trips, currentTripId: 'trip-river', nextSeq: 1)),
    );
    final legacyCity = legacy.trips.singleWhere((trip) => trip.id == 'trip-river').cities.first;
    expect(legacyCity.coordinateCandidateId, isNull);
    expect(legacyCity.coordinateConfirmed, isTrue);
    expect(isCurrentLocation(legacyCity, candidatesForCity(legacyCity.name).first), isTrue);
    await directory.delete(recursive: true);
  });

  test('기록과 제안 제외는 v2 스냅샷으로 남는다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_v2');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final first = TripController(catalog: catalog, store: store);
    first.selectTrip('trip-river');
    first.saveJournal('낮에 외탄을 걸었다.');
    first.startReview();
    final proposal = first.current!.proposalDays!;
    final item = proposal.first.items.firstWhere((i) => i.kind != ItemKind.move);
    first.deleteItem(item.id);
    await first.persistenceSettled;
    final encoded = await File('${directory.path}/trips.json').readAsString();
    expect(encoded, contains('"version":3'));
    expect(encoded, contains('낮에 외탄을 걸었다.'));

    final reloaded = TripController(catalog: catalog, store: store);
    await reloaded.restore();
    expect(reloaded.journalText(), '낮에 외탄을 걸었다.');
    expect(reloaded.excludedCount(reloaded.current!), greaterThan(0));

    await directory.delete(recursive: true);
  });

  test('v1 파일은 그대로 읽고 journal은 비어 있다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_v1');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final map = jsonDecode(
      encodeTripSnapshot(TripSnapshot(trips: catalog.trips, currentTripId: 'trip-south', nextSeq: 120)),
    ) as Map<String, dynamic>;
    map['version'] = 1;
    map.remove('journal');
    map.remove('exclusions');
    await File('${directory.path}/trips.json').writeAsString(jsonEncode(map));

    final controller = TripController(catalog: buildSampleCatalog(), store: store);
    await controller.restore();
    expect(controller.trips.length, catalog.trips.length);
    expect(controller.journalText(), isNull);

    await directory.delete(recursive: true);
  });

  test('손상된 저장 파일은 백업하고 샘플로 시작한다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_bad');
    final file = File('${directory.path}/trips.json');
    final store = FileTripStore(file);
    await file.writeAsString('{not json');
    final controller = TripController(catalog: catalog, store: store);
    await controller.restore();
    expect(controller.restoreNotice, isNotNull);
    expect(controller.trips.any((t) => t.id == 'trip-river'), isTrue);
    expect(File('${directory.path}/trips.json.corrupt').existsSync(), isTrue);

    await directory.delete(recursive: true);
  });

  test('저장 실패 시 다시 시도할 수 있다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_fail');
    final inner = FileTripStore(File('${directory.path}/trips.json'));
    final store = _FailingTripStore(inner);
    store.failWrites = true;
    final controller = TripController(catalog: catalog, store: store);
    controller.setDecision('wharf', Decision.excluded);
    await controller.persistenceSettled;
    expect(controller.saveStatus, SaveStatus.failed);
    expect(controller.lastSaveSnack, isNotNull);

    store.failWrites = false;
    await controller.retrySave();
    expect(controller.saveStatus, SaveStatus.saved);

    await directory.delete(recursive: true);
  });
}

class _FailingTripStore implements TripStore {
  _FailingTripStore(this.inner);

  final TripStore inner;
  var failWrites = false;

  @override
  Future<TripSnapshot?> read() => inner.read();

  @override
  Future<void> write(String encoded) async {
    if (failWrites) throw const FileSystemException('write blocked');
    await inner.write(encoded);
  }
}
