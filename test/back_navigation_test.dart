import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/state/trip_controller.dart';

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder list) async {
  final scrollable = find.descendant(of: list, matching: find.byType(Scrollable));
  if (!scrollable.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable.first);
  await tester.pumpAndSettle();
}

Future<void> _tapExploreCard(WidgetTester tester, Finder card) async {
  await _reveal(tester, card, find.byKey(const Key('explore-scroll')));
  final top = tester.getTopLeft(card);
  await tester.tapAt(top + const Offset(24, 16));
  await tester.pumpAndSettle();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('시스템 뒤로가기가 여행 상세를 먼저 닫는다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hero-title')));
    await tester.pumpAndSettle();
    expect(controller.homePushed, isTrue);
    expect(find.byKey(const Key('trip-detail-scroll')), findsOneWidget);

    await _systemBack(tester);
    expect(controller.homePushed, isFalse);
    expect(find.byKey(const Key('screen-title-home')), findsOneWidget);
    expect(find.byKey(const Key('trip-detail-scroll')), findsNothing);
  });

  testWidgets('시스템 뒤로가기가 탐색 장소 상세를 먼저 닫는다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-explore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상하이'));
    await tester.pumpAndSettle();
    await _tapExploreCard(tester, find.byKey(const Key('place-card-gallery')));
    expect(controller.explorePushed, isTrue);
    expect(find.byKey(const Key('place-combined')), findsOneWidget);

    await _systemBack(tester);
    expect(controller.explorePushed, isFalse);
    expect(find.byKey(const Key('place-combined')), findsNothing);
    expect(find.byKey(const Key('explore-scroll')), findsOneWidget);
  });

  testWidgets('작성 중 여행 폼에서 시스템 뒤로가기는 버리기를 묻는다', (tester) async {
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-trip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-city-search')), '임시');
    await _systemBack(tester);
    expect(find.text('작성 중인 여행을 버릴까요?'), findsOneWidget);
    expect(controller.creating, isTrue);

    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();
    expect(controller.creating, isFalse);
  });

  testWidgets('태블릿 탐색의 도시 위치 편집도 시스템 뒤로가기로 닫힌다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(1024, 1366));
    final controller = TripController()
      ..openCityEdit()
      ..selectTab(1);
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.editingCity, isTrue);
    expect(find.byKey(const Key('screen-title-city-edit')), findsOneWidget);

    await _systemBack(tester);
    expect(controller.editingCity, isFalse);
    expect(find.byKey(const Key('screen-title-explore')), findsOneWidget);
  });
}
