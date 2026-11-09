import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
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
    first.setDecision('wharf', Decision.excluded);
    first.toggleSaved('wharf');
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
    first.setDecision('park', Decision.excluded);
    first.toggleSaved('park');
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
    expect(sample.pendingLocalEdits, greaterThan(2));
    expect(sample.links['wharf']!.decision, Decision.excluded);
    expect(sample.links['wharf']!.saved, isTrue);
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
}
