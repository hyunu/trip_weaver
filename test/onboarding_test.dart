import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/logic/geocoder.dart';
import 'package:trip_weave/logic/trip_rules.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/state/trip_store.dart';

void main() {
  test('빈 저장 파일이면 온보딩 상태로 시작한다', () async {
    final directory = await Directory.systemTemp.createTemp('trip_weave_onboard');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final controller = TripController(store: store, geocoder: OfflineSampleGeocoder());
    await controller.restore();
    expect(controller.showOnboarding, isTrue);
    expect(controller.trips, isEmpty);
    await directory.delete(recursive: true);
  });

  test('샘플 둘러보기 후 샘플 여행만 채워진다', () async {
    final directory = await Directory.systemTemp.createTemp('trip_weave_onboard_home');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final controller = TripController(store: store, geocoder: OfflineSampleGeocoder());
    await controller.restore();
    controller.browseBundledSamples();
    expect(controller.sampleTrips.map((trip) => trip.id), contains('trip-river'));
    expect(controller.userTrips, isEmpty);
    expect(controller.bundledSamplesActive, isTrue);
    await directory.delete(recursive: true);
  });

  test('샘플 숨기기 후 목록은 비고 온보딩은 끝난 상태다', () async {
    final directory = await Directory.systemTemp.createTemp('trip_weave_onboard_hide');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final controller = TripController(store: store, geocoder: OfflineSampleGeocoder());
    await controller.restore();
    controller.browseBundledSamples();
    controller.hideAllSamples();
    expect(controller.sampleTrips, isEmpty);
    expect(controller.userTrips, isEmpty);
    expect(controller.onboardingComplete, isTrue);
    await directory.delete(recursive: true);
  });

  test('저장 파일에는 샘플 여행이 들어가지 않는다', () async {
    final catalog = buildSampleCatalog();
    final directory = await Directory.systemTemp.createTemp('trip_weave_no_sample_save');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final first = TripController(catalog: catalog, store: store);
    final error = first.createTrip(
      TripDraft(
        title: '저장만 할 여행',
        countryCode: 'KR',
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 3),
        purpose: '샘플 분리',
        tasteTags: const [],
        budgetAmount: '0',
        budgetCurrency: 'KRW',
        companionCount: 1,
        cities: [
          CityDraft(name: '서울', countryCode: 'KR', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 2)),
        ],
      ),
    );
    expect(error, isNull);
    await first.persistenceSettled;
    final text = await File('${directory.path}/trips.json').readAsString();
    expect(text, isNot(contains('trip-river')));
    expect(text, contains('저장만 할 여행'));
    expect(text, contains('"version":3'));

    final reloaded = TripController(catalog: catalog, store: store);
    await reloaded.restore();
    expect(reloaded.trips.any((trip) => trip.id == 'trip-river'), isTrue);
    expect(reloaded.trips.singleWhere((trip) => trip.title == '저장만 할 여행').dataOriginMock, isFalse);

    await directory.delete(recursive: true);
  });
}
