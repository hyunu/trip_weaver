import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/logic/schedule.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('일정 편집 로직', () {
    test('항목을 추가하면 그날 계획이 생기고 시각 순으로 정렬된다', () {
      final controller = TripController();
      final trip = controller.current!;
      trip.activeDays = [];
      controller.selectDate(DateTime(2026, 11, 8));
      controller.addItineraryTransport(title: '공항 이동');
      final day = dayFor(trip.activeDays, DateTime(2026, 11, 8))!;
      expect(day.items, hasLength(1));
      expect(day.items.single.kind, ItemKind.move);
      expect(day.items.single.title, '공항 이동');
    });

    test('드래그 순서를 바꾸면 시각이 맞춰 다시 흐른다', () {
      final date = DateTime(2026, 11, 8);
      final day = DayPlan(
        date: date,
        items: [
          PlanItem(id: 'a', kind: ItemKind.stay, title: 'A', start: DateTime(2026, 11, 8, 9), end: DateTime(2026, 11, 8, 10)),
          PlanItem(id: 'b', kind: ItemKind.stay, title: 'B', start: DateTime(2026, 11, 8, 11), end: DateTime(2026, 11, 8, 12)),
        ],
      );
      reorderDayItems(day, 0, 2);
      expect(day.items.map((item) => item.id), ['b', 'a']);
      expect(day.items[0].start!.hour, 9);
      expect(day.items[1].start!.hour, 10);
    });

    test('시각을 고치면 같은 날 안에서만 저장된다', () {
      final controller = TripController();
      controller.updateItemTime('d1108-park', start: DateTime(2026, 11, 8, 8, 30), end: DateTime(2026, 11, 8, 10));
      final item = controller.current!.activeDays.expand((d) => d.items).firstWhere((i) => i.id == 'd1108-park');
      expect(item.start!.hour, 8);
      expect(item.start!.minute, 30);
      expect(item.end!.hour, 10);
    });

    test('컨트롤러로 순서를 바꾸면 목록 순서가 바뀐다', () {
      final controller = TripController()..selectDate(DateTime(2026, 11, 8));
      final day = dayFor(controller.current!.activeDays, DateTime(2026, 11, 8))!;
      final first = day.items.first.id;
      final second = day.items[1].id;
      controller.reorderItineraryItem(0, 2);
      expect(day.items[0].id, second);
      expect(day.items[1].id, first);
    });
  });

  group('일정 화면 편집', () {
    testWidgets('교통을 추가하고 시간 편집 시트를 연다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(1024, 1366));
      final controller = TripController()..selectTab(2);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('itinerary-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-kind-transport')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-item-title')), '인천→상하이');
      await tester.tap(find.byKey(const Key('confirm-add-item')));
      await tester.pumpAndSettle();

      expect(find.text('인천→상하이'), findsWidgets);
      controller.openItem(controller.selectedItemId!, tablet: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('item-edit-time')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-time-edit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-time-edit')));
      await tester.pumpAndSettle();
    });

    testWidgets('일정 화면에 추가 버튼이 보인다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(390, 844));
      final controller = TripController()..selectTab(2);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('itinerary-add')), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.bars), findsWidgets);
    });
  });
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
