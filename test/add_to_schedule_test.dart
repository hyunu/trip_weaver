import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/logic/add_to_schedule.dart';
import 'package:trip_weave/logic/schedule.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('일정에 추가', () {
    test('선택한 날짜의 적용 일정에 고정 항목으로 넣는다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.discardProposal();
      final day = DateTime(2026, 11, 7);
      final place = controller.placeById('gallery')!;
      expect(insertPlaceOnDay(trip, place, day, 'sched-test'), isNull);
      final plan = dayFor(trip.activeDays, day)!;
      final added = plan.items.singleWhere((item) => item.placeId == 'gallery');
      expect(added.locked, isTrue);
      expect(added.start, isNotNull);
      _expectNoOverlap(plan.items);
    });

    test('같은 날짜에 두 번 넣지 않는다', () {
      final controller = TripController();
      final trip = controller.current!;
      final place = controller.placeById('park')!;
      final day = DateTime(2026, 11, 8);
      expect(insertPlaceOnDay(trip, place, day, 'a'), isNotNull);
    });

    test('새로 제안받으면 넣은 장소는 고정으로 남고 빈 시간을 채운다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.discardProposal();
      controller.addPlaceToSchedule('market', DateTime(2026, 11, 9));
      controller.requestItinerary();
      final day = dayFor(trip.proposalDays!, DateTime(2026, 11, 9))!;
      final market = day.items.singleWhere((item) => item.placeId == 'market');
      expect(market.locked, isTrue);
      expect(day.items.length, greaterThan(1));
      _expectNoOverlap(day.items);
    });

    testWidgets('장소 상세에서 날짜를 고르면 일정 탭에 바로 보인다', (tester) async {
      TripController.debugFixedNow = DateTime(2026, 11, 8, 10, 40);
      await tester.runAsync(warmSampleMap);
      _setView(tester, const Size(390, 844));
      final controller = TripController();
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-explore')));
      await tester.pumpAndSettle();
      await _tapCard(tester, find.byKey(const Key('place-card-market')));
      expect(find.byKey(const Key('place-combined')), findsOneWidget);
      await tester.tap(find.byKey(const Key('place-add-schedule')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-date-sheet')), findsOneWidget);
      final pick = find.byKey(const Key('schedule-pick-11-9'));
      await tester.dragUntilVisible(pick, find.byKey(const Key('schedule-date-sheet')), const Offset(0, -80));
      await tester.pumpAndSettle();
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-date-sheet')), findsNothing);
      expect(controller.scheduledDaysFor('market'), contains(dateOnly(DateTime(2026, 11, 9))));
      await tester.tap(find.byKey(const Key('tab-itinerary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date-chip-11-9')));
      await tester.pumpAndSettle();
      expect(find.text('예원 골목'), findsOneWidget);
    });
  });
}

Future<void> _tapCard(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder, find.byKey(const Key('explore-scroll')));
  final top = tester.getTopLeft(finder);
  await tester.tapAt(top + const Offset(24, 16));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder list) async {
  final scrollables = find.descendant(of: list, matching: find.byType(Scrollable));
  for (var attempt = 0; attempt < 12; attempt++) {
    if (tester.any(target)) {
      final top = tester.getTopLeft(target);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (top.dy >= 8 && top.dy < height - 80) return;
    }
    final states = tester.stateList<ScrollableState>(scrollables);
    if (states.isEmpty) return;
    final position = states.first.position;
    final next = position.pixels + 240;
    if (next > position.maxScrollExtent && tester.any(target)) return;
    position.jumpTo(next.clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
  }
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final phone = size.shortestSide < 600;
  final padding = FakeViewPadding(left: 0, top: phone ? 54 : 24, right: 0, bottom: phone ? 34 : 20);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

void _expectNoOverlap(List<PlanItem> items) {
  final timed = items.where((item) => item.start != null).toList();
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      expect(overlapsInTime(timed[i], timed[j]), isFalse, reason: '${timed[i].id} vs ${timed[j].id}');
    }
  }
}
