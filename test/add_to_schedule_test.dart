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
      final day = DateTime(2026, 11, 9);
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
      final controller = TripController();
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-explore')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('place-card-market')), 120, scrollable: find.byKey(const Key('explore-scroll')));
      await tester.tap(find.byKey(const Key('place-card-market')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-add-schedule')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-date-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-pick-11-9')));
      await tester.pumpAndSettle();
      expect(find.textContaining('일정 11.9'), findsWidgets);
      await tester.tap(find.byKey(const Key('tab-itinerary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date-chip-11-9')));
      await tester.pumpAndSettle();
      expect(find.text('예원 골목'), findsOneWidget);
    });
  });
}

void _expectNoOverlap(List<PlanItem> items) {
  final timed = items.where((item) => item.start != null).toList();
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      expect(overlapsInTime(timed[i], timed[j]), isFalse, reason: '${timed[i].id} vs ${timed[j].id}');
    }
  }
}
