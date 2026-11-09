import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('탐색 헤더에서 여행을 바꾸면 탭을 유지한다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-explore')));
    await tester.pumpAndSettle();
    expect(controller.currentTripId, 'trip-river');

    await tester.tap(find.byKey(const Key('trip-switcher')));
    await tester.pumpAndSettle();
    expect(find.text('여행 바꾸기'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trip-picker-trip-south')));
    await tester.pumpAndSettle();
    expect(controller.currentTripId, 'trip-south');
    expect(controller.tabIndex, 1);
    expect(find.byKey(const Key('screen-title-explore')), findsOneWidget);
  });

  testWidgets('진행 중 여행이 없으면 여행 중 탭이 비활성이다', (tester) async {
    await _setView(tester, const Size(390, 844));
    final controller = TripController(now: DateTime(2026, 11, 8, 10, 40));
    for (final trip in controller.trips) {
      if (trip.status == TripStatus.active) trip.status = TripStatus.draft;
    }
    controller.selectTrip('trip-south');
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    final ink = tester.widget<InkWell>(find.byKey(const Key('tab-underway')));
    expect(ink.onTap, isNull);

    await tester.tap(find.byKey(const Key('tab-underway')));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, isNot(3));

    expect(find.byKey(const Key('next-trip-countdown')), findsOneWidget);
    expect(find.text('D-12'), findsOneWidget);
  });

  testWidgets('진행 중 여행이 있으면 여행 중 탭으로 들어가고 진행 중 여행을 고른다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    controller.selectTrip('trip-south');
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-underway')));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 3);
    expect(controller.currentTripId, 'trip-river');
    expect(find.byKey(const Key('underway-steps')), findsOneWidget);
  });
}

Future<void> _setView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final phone = size.shortestSide < 600;
  final padding = FakeViewPadding(left: 0, top: phone ? 54 : 0, right: 0, bottom: phone ? 34 : 0);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}
