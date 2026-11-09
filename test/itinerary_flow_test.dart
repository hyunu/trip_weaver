import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/logic/propose.dart';
import 'package:trip_weave/logic/schedule.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('고정 항목과 제안', () {
    test('새로 제안받아도 고정한 항목은 같은 날짜, 같은 시각에 남는다', () {
      final controller = TripController();
      final trip = controller.current!;
      final park = dayFor(trip.activeDays, DateTime(2026, 11, 8))!.items.firstWhere((item) => item.id == 'd1108-park');
      expect(park.locked, isTrue);

      controller.requestItinerary();
      final day = dayFor(trip.proposalDays!, DateTime(2026, 11, 8))!;
      final kept = day.items.where((item) => item.id == 'd1108-park').single;
      expect(kept.locked, isTrue);
      expect(kept.start, park.start);
      expect(kept.end, park.end);
      expect(trip.proposalDays!.expand((day) => day.items).where((item) => item.placeId == 'park'), hasLength(1));
      _expectNoOverlap(day.items);
    });

    test('고정하지 않은 항목은 다시 배치되고, 고정을 풀면 더 이상 지키지 않는다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.discardProposal();
      controller.toggleLock('d1108-park');
      controller.requestItinerary();
      expect(trip.proposalDays!.expand((day) => day.items).any((item) => item.id == 'd1108-park'), isFalse);
      expect(trip.proposalDays!.expand((day) => day.items).any((item) => item.locked), isFalse);
    });

    test('고정한 식사가 있으면 그 날 점심을 따로 만들지 않고 그 주변에 배치한다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.toggleLock('d1108-meal');
      controller.requestItinerary();
      final day = dayFor(trip.proposalDays!, DateTime(2026, 11, 8))!;
      final meals = day.items.where((item) => item.kind == ItemKind.meal && item.start!.hour < 16).toList();
      expect(meals.map((item) => item.id), ['d1108-meal']);
      expect(trip.proposalDays!.expand((day) => day.items).where((item) => item.placeId == 'noodle'), hasLength(1));
      _expectNoOverlap(day.items);
    });

    test('검토 중인 제안에서 고정한 항목도 다시 제안할 때 지킨다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.startReview();
      controller.toggleLock('p1108-gallery');
      controller.requestItinerary();
      final day = dayFor(trip.proposalDays!, DateTime(2026, 11, 8))!;
      final gallery = day.items.singleWhere((item) => item.placeId == 'gallery');
      expect(gallery.id, 'p1108-gallery');
      expect(gallery.start, DateTime(2026, 11, 8, 13, 30));
      expect(day.items.where((item) => item.placeId == 'park'), hasLength(1));
      _expectNoOverlap(day.items);
      final ids = trip.proposalDays!.expand((day) => day.items).map((item) => item.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('도시 위치가 미확인인 날에도 고정 항목을 남긴다', () {
      final controller = TripController();
      final trip = controller.current!;
      controller.toggleLock('d1110-meal');
      controller.requestItinerary();
      final day = dayFor(trip.proposalDays!, DateTime(2026, 11, 10))!;
      expect(day.items.map((item) => item.id), ['d1110-meal']);
    });

    test('선택한 장소를 매일 되풀이하지 않고 도시의 날짜에 나눈다', () {
      final controller = TripController();
      final trip = controller.current!;
      final days = proposeItinerary(trip, controller.places)!;
      final stays = days.expand((day) => day.items).where((item) => item.kind == ItemKind.stay).map((item) => item.placeId).toList();
      expect(stays.toSet().length, stays.length);
      expect(stays.toSet(), {'park', 'gallery', 'market'});
      for (final day in days) {
        _expectNoOverlap(day.items);
      }
    });

    test('같은 시간대의 고정은 먼저 받은 쪽을 남긴다', () {
      final date = DateTime(2026, 11, 8);
      PlanItem pin(String id, String place, int hour) => PlanItem(
        id: id,
        kind: ItemKind.stay,
        title: id,
        placeId: place,
        start: DateTime(2026, 11, 8, hour),
        end: DateTime(2026, 11, 8, hour + 1),
        locked: true,
      );
      final merged = mergePins([
        [DayPlan(date: date, items: [pin('a', 'x', 9)])],
        [DayPlan(date: date, items: [pin('b', 'y', 9), pin('c', 'x', 14), pin('d', 'z', 15)])],
      ]);
      expect(merged.single.items.map((item) => item.id), ['a', 'd']);
    });

    test('제안 요약은 날짜 수, 방문 수, 지킨 고정 수를 말한다', () {
      final controller = TripController();
      controller.requestItinerary();
      final summary = summarizeProposal(controller.current!.proposalDays!);
      expect(summary.line, '6일 · 방문 3곳 · 고정 1개 유지');
    });
  });

  group('제안에서 뺀 항목', () {
    List<PlanItem> all(TripController controller) => controller.current!.proposalDays!.expand((day) => day.items).toList();

    test('검토 중에 뺀 장소는 새로 제안받아도 다시 들어오지 않는다', () {
      final controller = TripController()..startReview();
      controller.deleteItem('p1108-gallery');
      expect(controller.excludedCount(controller.current!), 1);
      controller.requestItinerary();
      expect(all(controller).where((item) => item.placeId == 'gallery'), isEmpty);
      expect(all(controller).where((item) => item.placeId == 'market'), hasLength(1));
      controller.requestItinerary();
      expect(all(controller).where((item) => item.placeId == 'gallery'), isEmpty);
    });

    test('뺀 저녁·점심 자리는 그 날짜에만 비운다', () {
      final controller = TripController()..requestItinerary();
      final trip = controller.current!;
      final dinner = dayFor(trip.proposalDays!, DateTime(2026, 11, 7))!.items.lastWhere((item) => item.kind == ItemKind.meal);
      expect(dinner.start!.hour, 18);
      final lunch = dayFor(trip.proposalDays!, DateTime(2026, 11, 8))!.items.firstWhere((item) => item.placeId == 'noodle');
      controller.deleteItem(dinner.id);
      controller.deleteItem(lunch.id);
      controller.requestItinerary();
      final nov7 = dayFor(trip.proposalDays!, DateTime(2026, 11, 7))!;
      final nov8 = dayFor(trip.proposalDays!, DateTime(2026, 11, 8))!;
      final nov6 = dayFor(trip.proposalDays!, DateTime(2026, 11, 6))!;
      expect(nov7.items.where((item) => item.kind == ItemKind.meal && item.start!.hour >= 16), isEmpty);
      expect(nov8.items.where((item) => item.kind == ItemKind.meal && item.start!.hour < 16), isEmpty);
      expect(nov6.items.where((item) => item.kind == ItemKind.meal), hasLength(2));
      expect(nov6.items.any((item) => item.placeId == 'noodle'), isTrue);
    });

    test('제안에서 뺀 고정 항목은 현재 일정의 같은 고정으로 되살아나지 않는다', () {
      final controller = TripController()..startReview();
      controller.deleteItem('p1108-park');
      controller.requestItinerary();
      expect(all(controller).where((item) => item.placeId == 'park'), isEmpty);
    });

    test('되살리기, 적용, 버리기는 뺀 목록을 비운다', () {
      final controller = TripController()..startReview();
      final trip = controller.current!;
      controller.deleteItem('p1108-gallery');
      controller.restoreExcluded();
      expect(controller.excludedCount(trip), 0);
      expect(all(controller).where((item) => item.placeId == 'gallery'), hasLength(1));

      controller.deleteItem(all(controller).firstWhere((item) => item.placeId == 'gallery').id);
      controller.applyProposal();
      expect(controller.excludedCount(trip), 0);
      controller.requestItinerary();
      expect(all(controller).where((item) => item.placeId == 'gallery'), hasLength(1));

      controller.deleteItem(all(controller).firstWhere((item) => item.placeId == 'gallery').id);
      controller.discardProposal();
      expect(controller.excludedCount(trip), 0);
    });

    test('현재 일정에서 지운 항목은 제안 제외로 남기지 않는다', () {
      final controller = TripController();
      controller.deleteItem('d1108-gallery');
      expect(controller.excludedCount(controller.current!), 0);
      controller.requestItinerary();
      expect(all(controller).where((item) => item.placeId == 'gallery'), hasLength(1));
    });

    testWidgets('화면에서 뺀 항목은 새로 제안받아도 돌아오지 않고, 되살릴 수 있다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(1024, 1366));
      final controller = TripController()
        ..selectTab(2)
        ..startReview();
      controller.openItem('p1108-gallery', tablet: true);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('item-delete')));
      await tester.pumpAndSettle();
      expect(find.text('적용하지 않은 제안에서만 빠집니다. 새로 제안받아도 다시 넣지 않습니다.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-delete-item')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-itinerary')));
      await tester.pumpAndSettle();
      expect(find.text('제안에서 뺀 항목 1개는 새로 제안받아도 다시 넣지 않습니다.'), findsOneWidget);
      expect(all(controller).where((item) => item.placeId == 'gallery'), isEmpty);

      await tester.tap(find.byKey(const Key('restore-excluded')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proposal-excluded')), findsNothing);
      expect(all(controller).where((item) => item.placeId == 'gallery'), hasLength(1));
    });
  });

  group('날짜 칩', () {
    test('이동을 뺀 항목 수와 고정 수를 센다', () {
      final controller = TripController();
      final day = dayFor(controller.current!.activeDays, DateTime(2026, 11, 8));
      final counts = dayCounts(day);
      expect((counts.items, counts.pinned), (6, 1));
      expect(dayCounts(null), (items: 0, pinned: 0));
    });

    testWidgets('폰 날짜 칩은 그 날의 항목 수와 고정 수를 보여 준다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(320, 568));
      final controller = TripController()..selectTab(2);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final today = find.byKey(const Key('date-chip-11-8'));
      expect(find.descendant(of: today, matching: find.text('11.8 오늘')), findsOneWidget);
      expect(find.descendant(of: today, matching: find.text('6개 · 고정 1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('date-chip-11-6')), matching: find.text('11.6 금')), findsOneWidget);

      controller.startReview();
      await tester.pumpAndSettle();
      expect(find.descendant(of: today, matching: find.text('4개 · 고정 1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빈 날은 일정 없음으로 표시한다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..selectTab(2);
      controller.current!.activeDays.removeWhere((day) => day.date.day == 9);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('date-chip-11-9')), matching: find.text('일정 없음')), findsOneWidget);
    });

    testWidgets('넓은 태블릿 날짜 열도 같은 정보를 보여 준다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(1366, 1024));
      final controller = TripController()..selectTab(2);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('date-rail-11-8')), matching: find.text('일 · 오늘 · 일정 6개 · 고정 1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('date-rail-11-10')), matching: find.text('화 · 일정 1개')), findsOneWidget);
    });
  });

  group('일정 보조 로직', () {
    test('여행 밖 날짜를 고르고 있으면 일정은 여행 첫날을 보여 준다', () {
      final controller = TripController(now: DateTime(2026, 12, 1, 9));
      final trip = controller.current!;
      expect(controller.planDate(trip), DateTime(2026, 11, 6));
      expect(controller.visibleDay(trip)!.date, DateTime(2026, 11, 6));
    });

    test('오늘 진행과 다음 날 첫 방문', () {
      final controller = TripController();
      final trip = controller.current!;
      final today = dayFor(trip.activeDays, controller.now)!;
      final progress = visitProgress(today.items, controller.now);
      expect((progress.done, progress.total), (1, 4));
      final later = laterVisit(trip, controller.now)!;
      expect(later.day.date, DateTime(2026, 11, 9));
      expect(later.item.id, 'd1109-gallery');
    });

    test('적용과 버리기는 결과를 알린다', () {
      final controller = TripController();
      controller.discardProposal();
      expect(controller.itineraryNotice, '제안을 버렸습니다. 지금 일정은 그대로입니다.');
      controller.requestItinerary();
      expect(controller.itineraryNotice, isNull);
      controller.applyProposal();
      expect(controller.itineraryNotice, startsWith('제안을 적용했습니다.'));
    });
  });

  group('일정 화면', () {
    testWidgets('새 제안은 요약과 고정 표시를 보여 주고, 버리기는 확인한다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..selectTab(2);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-itinerary')));
      await tester.pumpAndSettle();
      expect(find.text('6일 · 방문 3곳 · 고정 1개 유지'), findsOneWidget);
      expect(find.byKey(const Key('item-pinned-d1108-park')), findsOneWidget);

      await tester.tap(find.byKey(const Key('discard-proposal')));
      await tester.pumpAndSettle();
      expect(find.text('이 제안을 버릴까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(controller.current!.proposalDays, isNotNull);

      await tester.tap(find.byKey(const Key('discard-proposal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-discard-proposal')));
      await tester.pumpAndSettle();
      expect(controller.current!.proposalDays, isNull);
      expect(find.byKey(const Key('itinerary-notice')), findsOneWidget);
      expect(find.byKey(const Key('toggle-proposal')), findsNothing);
    });

    testWidgets('선택한 장소가 없으면 식사만 제안한 이유를 말한다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..selectTab(2);
      controller.current!.links.clear();
      controller.discardProposal();
      controller.toggleLock('d1108-park');
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('request-itinerary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proposal-no-places')), findsOneWidget);
    });

    testWidgets('항목 화면은 고정의 뜻을 설명한다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(1024, 1366));
      final controller = TripController()..selectTab(2);
      controller.openItem('d1108-park', tablet: true);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('고정한 항목은 새로 제안받아도 이 날짜, 이 시각에 그대로 남습니다.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('item-lock')));
      await tester.pumpAndSettle();
      expect(find.text('고정하면 새로 제안받아도 이 항목이 같은 시각에 남습니다.'), findsOneWidget);
    });
  });

  group('여행 중 화면', () {
    for (final size in const [Size(320, 568), Size(390, 844), Size(1024, 1366), Size(1366, 1024)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}에서 넘치지 않고 진행을 보여 준다', (tester) async {
        await tester.runAsync(warmSampleMap);
        await _setView(tester, size);
        final controller = TripController()..selectTab(3);
        await tester.pumpWidget(TripWeaveApp(controller: controller));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('오늘 방문 4곳 중 1곳 끝남'), findsOneWidget);
        expect(find.byKey(const Key('underway-next')), findsOneWidget);
      });
    }

    testWidgets('작은 폰에서는 지도를 줄이거나 접어 목록 자리를 남긴다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(320, 568));
      final controller = TripController()..selectTab(3);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('underway-steps'))).height, greaterThan(120));
    });

    testWidgets('제안 검토 중에 남은 일정을 누르면 적용된 일정의 그 항목이 열린다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..startReview();
      controller.selectTab(3);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('underway-next')));
      await tester.pumpAndSettle();
      expect(controller.reviewingProposal, isFalse);
      expect(controller.tabIndex, 2);
      expect(controller.selectedItem()?.id, 'd1108-gallery');
      expect(controller.itineraryPushed, isTrue);
      expect(find.byKey(const Key('item-lock')), findsOneWidget);
    });

    testWidgets('오늘 방문이 끝나면 다음 날 첫 방문을 보여 준다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController(now: DateTime(2026, 11, 8, 20))..selectTab(3);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('오늘 남은 방문이 없습니다.'), findsOneWidget);
      expect(find.text('11월 9일 첫 방문'), findsOneWidget);
      expect(find.byKey(const Key('underway-later')), findsOneWidget);
    });

    testWidgets('여행 시작 전에는 시작일을 말한다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController(now: DateTime(2026, 11, 1, 9))..selectTab(3);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('여행은 11월 6일에 시작합니다.'), findsOneWidget);
      expect(find.text('11월 6일 첫 방문'), findsOneWidget);
    });

    testWidgets('적용된 일정이 없으면 일정으로 가는 길을 준다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..selectTab(3);
      controller.current!.activeDays = [];
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('적용된 일정이 없습니다.'), findsOneWidget);
      await tester.tap(find.text('제안 검토하기'));
      await tester.pumpAndSettle();
      expect(controller.tabIndex, 2);
      expect(controller.reviewingProposal, isTrue);
      expect(find.byKey(const Key('proposal-review')), findsOneWidget);
    });
  });
}

void _expectNoOverlap(List<PlanItem> items) {
  final timed = items.where((item) => item.start != null).toList();
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      expect(overlapsInTime(timed[i], timed[j]), isFalse, reason: '${timed[i].id} ${timed[i].start}–${timed[i].end} / ${timed[j].id} ${timed[j].start}–${timed[j].end}');
    }
  }
  for (var i = 1; i < timed.length; i++) {
    expect(timed[i].start!.isBefore(timed[i - 1].start!), isFalse);
  }
}

Future<void> _setView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final phone = size.shortestSide < 600;
  final padding = FakeViewPadding(left: 0, top: phone ? 54 : 24, right: 0, bottom: phone ? 34 : 20);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}
