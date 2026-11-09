import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/map/trip_map.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('다섯 탭이 전환되고 글자 크기가 위계를 지킨다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('screen-title-home'))).style!.fontSize, 34);
    expect(tester.widget<Text>(find.byKey(const Key('hero-title'))).style!.fontSize, 22);
    expect(tester.widget<Text>(find.byKey(const Key('hero-period'))).style!.fontSize, 13);
    expect(find.text('황푸와 외탄'), findsOneWidget);
    expect(find.text('2026.11.6 – 11.11'), findsOneWidget);
    expect(find.textContaining('다음 일정'), findsOneWidget);
    expect(find.text('샘플 데이터입니다. 실제 장소 정보가 아닙니다.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('sample-banner')), matching: find.byType(IconButton)), findsNothing);

    await tester.tap(find.byKey(const Key('tab-explore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-title-explore')), findsOneWidget);
    expect(find.byKey(const Key('trip-map')), findsOneWidget);
    expect(find.byKey(const Key('place-query')), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('place-card-gallery')), find.byKey(const Key('explore-scroll')));
    expect(find.byKey(const Key('place-card-gallery')), findsOneWidget);
    await _reveal(tester, find.byKey(const Key('place-card-market')), find.byKey(const Key('explore-scroll')));
    expect(find.byKey(const Key('place-card-market')), findsOneWidget);

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, 2400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('충밍'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-map')), findsNothing);
    expect(find.text('도시 위치가 확인되지 않았습니다.'), findsWidgets);
    expect(find.text('도시 편집으로 이동'), findsOneWidget);

    await tester.tap(find.text('상하이'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('place-card-gallery')));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('10:00–18:00'), find.byKey(const Key('place-combined')));
    expect(find.text('10:00–18:00'), findsOneWidget);
    expect(find.text('출처 1곳, 미확인'), findsWidgets);
    expect(find.text('확인됨'), findsNothing);
    expect(find.text('AI 문구'), findsNothing);

    await _toTop(tester, find.byKey(const Key('place-combined')));
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('place-card-market')));
    await _reveal(tester, find.text('09:00–18:00'), find.byKey(const Key('place-combined')));
    expect(find.text('09:00–18:00'), findsOneWidget);
    expect(find.text('10:00–16:00'), findsOneWidget);
    expect(find.text('출처마다 다릅니다'), findsWidgets);
    expect(find.text('확인됨'), findsNothing);

    await _toTop(tester, find.byKey(const Key('place-combined')));
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-itinerary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-map')), findsOneWidget);
    expect(find.byKey(const Key('map-pin-d1108-park')), findsOneWidget);
    expect(find.text(routeEstimateNote), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsNothing);
    final gallery = find.byKey(const Key('item-d1108-gallery'));
    await _reveal(tester, gallery, find.byKey(const Key('itinerary-scroll')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.descendant(of: gallery, matching: find.text('체류'))).dy, lessThan(tester.getTopLeft(find.descendant(of: gallery, matching: find.textContaining('10:50'))).dy));
    expect(tester.getTopLeft(find.descendant(of: gallery, matching: find.text('미확인 값'))).dy, lessThan(tester.getTopLeft(find.descendant(of: gallery, matching: find.textContaining('10:50'))).dy));
    expect(find.text('지하철'), findsNothing);
    expect(find.text('호선'), findsNothing);

    final meal = find.byKey(const Key('item-d1108-meal'));
    await _reveal(tester, meal, find.byKey(const Key('itinerary-scroll')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.descendant(of: meal, matching: find.text('식사'))).dy, lessThan(tester.getTopLeft(find.descendant(of: meal, matching: find.textContaining('12:30'))).dy));
    expect(tester.getTopLeft(find.descendant(of: meal, matching: find.text('미확인 값'))).dy, lessThan(tester.getTopLeft(find.descendant(of: meal, matching: find.textContaining('12:30'))).dy));

    await tester.tap(find.text('제안 검토'));
    await tester.pumpAndSettle();
    expect(find.text('아직 적용하지 않은 일정입니다.'), findsOneWidget);
    expect(controller.current!.activeDays[2].items[2].title, '루자쭈이 전망');
    await tester.tap(find.text('이 일정 적용'));
    await tester.pumpAndSettle();
    expect(find.text('아직 적용하지 않은 일정입니다.'), findsNothing);
    expect(controller.current!.activeDays[2].items[1].title, '예원 골목');

    await tester.tap(find.byKey(const Key('tab-underway')));
    await tester.pumpAndSettle();
    expect(find.text('현재 위치와 지도는 지도 단계에서 연결됩니다.'), findsNothing);
    expect(find.byKey(const Key('trip-map')), findsOneWidget);
    expect(find.byKey(const Key('map-pin-p1108-market')), findsOneWidget);
    expect(find.byKey(const Key('map-pin-wharf')), findsOneWidget);
    expect(tester.widget<Text>(find.text(routeEstimateNote)).style!.fontSize, 13);
    await _reveal(tester, find.text('주변 장소'), find.byKey(const Key('underway-steps')));
    expect(find.text('주변 장소'), findsOneWidget);
    expect(find.byType(AspectRatio), findsNothing);
    expect(find.byKey(const Key('map-tile')), findsNothing);
    expect(find.text('대체 경로 없음'), findsNothing);
    expect(find.byKey(const Key('underway-directions')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-journal')));
    await tester.pumpAndSettle();
    expect(find.text('사진과 여행 기록은 사진 단계에서 사용할 수 있습니다.'), findsOneWidget);
    expect(find.text('사진 찍기'), findsNothing);
    expect(find.text('사진 가져오기'), findsNothing);
    expect(find.text('기록이 없습니다'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-title-home')), findsOneWidget);
  });

  testWidgets('태블릿은 하단 탭 없이 분할된다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(1024, 1366));
    await tester.pumpWidget(TripWeaveApp(controller: TripController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-home')), findsNothing);
    expect(find.byKey(const Key('rail-home')), findsOneWidget);
    expect(find.text('황푸와 외탄'), findsWidgets);
    expect(find.textContaining('상하이'), findsWidgets);
    expect(find.text('동행 인원 (본인 제외)'), findsOneWidget);
    expect(find.byType(AspectRatio), findsNothing);

    await tester.tap(find.byKey(const Key('rail-explore')));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('place-card-market')));
    expect(find.byKey(const Key('place-facts')), findsOneWidget);
    expect(find.byKey(const Key('place-sources')), findsOneWidget);
    expect(find.text('09:00–18:00'), findsWidgets);
    expect(find.text('10:00–16:00'), findsWidgets);

    await tester.tap(find.byKey(const Key('rail-itinerary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item-d1108-park')), findsOneWidget);
    expect(find.text('일정을 고르세요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rail-underway')));
    await tester.pumpAndSettle();
    expect(find.text('지도는 아직 연결되지 않았습니다.'), findsNothing);
    expect(find.byKey(const Key('trip-map')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsNothing);
    expect(find.byType(AspectRatio), findsNothing);

    await tester.tap(find.byKey(const Key('rail-journal')));
    await tester.pumpAndSettle();
    expect(find.text('사진과 여행 기록은 사진 단계에서 사용할 수 있습니다.'), findsOneWidget);
    expect(find.text('기록 없음'), findsWidgets);
  });

  testWidgets('회전 후에도 선택한 장소가 남는다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-explore')));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('place-card-gallery')));
    await tester.pumpAndSettle();
    expect(controller.selectedPlaceId, 'gallery');
    expect(controller.explorePushed, isTrue);

    await _setView(tester, const Size(1024, 1366));
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.selectedPlaceId, 'gallery');
    expect(find.byKey(const Key('place-facts')), findsOneWidget);
    expect(find.byKey(const Key('trip-map')), findsOneWidget);

    await _setView(tester, const Size(390, 844));
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.selectedPlaceId, 'gallery');
    expect(controller.explorePushed, isTrue);
    expect(find.text('루자쭈이 전망'), findsWidgets);
    expect(find.byKey(const Key('place-combined')), findsOneWidget);
  });
}

Future<void> _toTop(WidgetTester tester, Finder list) async {
  await tester.drag(list, const Offset(0, 2400));
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder, find.byKey(const Key('explore-scroll')));
  final top = tester.getTopLeft(finder);
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
