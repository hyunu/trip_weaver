import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/trip_map.dart';
import 'package:trip_weave/state/trip_controller.dart';

Future<void> warmSampleMap() => TripMap.warmStyleForTests();

void main() {
  testWidgets('여행 중 다음 목적지 카드에 길찾기·도착·건너뛰기가 보인다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-underway')));
    await tester.pumpAndSettle();

    expect(find.text('대체 경로 없음'), findsNothing);
    expect(find.byKey(const Key('underway-directions')), findsOneWidget);
    expect(find.byKey(const Key('underway-local-sheet')), findsOneWidget);
    expect(find.byKey(const Key('underway-arrived')), findsOneWidget);
    expect(find.byKey(const Key('underway-skip')), findsOneWidget);
    expect(find.byKey(const Key('underway-next-local')), findsOneWidget);
    expect(find.text('陆家嘴滨江'), findsOneWidget);

    final trip = controller.current!;
    final first = controller.destinationFor(trip)!;
    expect(first.title, '루자쭈이 전망');

    await tester.tap(find.byKey(const Key('underway-arrived')));
    await tester.pumpAndSettle();
    expect(trip.visitDoneIds, contains(first.id));
    expect(controller.destinationFor(trip)?.title, '덕흥관');

    await tester.tap(find.byKey(const Key('underway-local-sheet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('underway-local-sheet-text')), findsOneWidget);
    expect(find.text('德兴馆'), findsOneWidget);
  });

  test('도착 표시를 하면 다음 목적지가 바뀐다', () {
    final controller = TripController();
    final trip = controller.current!;
    final next = controller.destinationFor(trip)!;
    controller.markVisitDone(next.id);
    expect(controller.destinationFor(trip)?.id, isNot(next.id));
    expect(trip.visitDoneIds, contains(next.id));
  });
}
