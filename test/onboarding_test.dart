import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/logic/geocoder.dart';
import 'package:trip_weave/logic/trip_rules.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/state/trip_store.dart';

void main() {
  testWidgets('첫 실행은 온보딩이 뜨고 샘플 둘러보기 후 샘플 섹션에만 나타난다', (tester) async {
    final directory = await Directory.systemTemp.createTemp('trip_weave_onboard');
    final store = FileTripStore(File('${directory.path}/trips.json'));
    final controller = TripController(store: store, geocoder: OfflineSampleGeocoder());
    await controller.restore();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-welcome')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-browse-samples')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-title-home')), findsOneWidget);
    expect(find.text('샘플 여행'), findsOneWidget);
    expect(find.text('샘플 모두 숨기기'), findsOneWidget);
    expect(find.text('남쪽 바다'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hide-all-samples')));
    await tester.pumpAndSettle();
    expect(find.text('샘플 여행'), findsNothing);
    expect(find.text('여행이 없습니다.'), findsOneWidget);

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
        budgetAmount: '',
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
