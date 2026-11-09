import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('홈의 진행 중 카드에서 상세, 일정, 도시 위치까지 이어진다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-trip')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('create-trip'))).dy, lessThan(200));
    expect(find.text('기준 시각 11월 8일 10:40 · 샘플'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hero-title')));
    await tester.pumpAndSettle();
    expect(controller.homePushed, isTrue);
    expect(find.text('뒤로'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('detail-confirm-cities')), find.byKey(const Key('trip-detail-scroll')));
    expect(find.text('위치가 확인되지 않은 도시 1곳은 탐색과 지도에 나오지 않습니다.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-confirm-cities')));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 1);
    expect(find.byKey(const Key('screen-title-city-edit')), findsOneWidget);
    expect(find.text('위치를 확인한 도시만 탐색과 지도에 나옵니다. 확인할 도시 1곳.'), findsOneWidget);

    final unconfirmed = controller.current!.cities.firstWhere((city) => !city.coordinateConfirmed);
    await _scrollTo(tester, find.byKey(Key('find-candidates-${unconfirmed.id}')), find.byKey(const Key('city-edit-scroll')));
    await tester.tap(find.byKey(Key('find-candidates-${unconfirmed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('다시 찾기'), findsOneWidget);
    await _scrollTo(tester, find.byKey(Key('candidate-${unconfirmed.id}-0')), find.byKey(const Key('city-edit-scroll')));
    expect(find.text('충밍 성시'), findsOneWidget);
    await tester.tap(find.byKey(Key('candidate-${unconfirmed.id}-0')));
    await tester.pumpAndSettle();
    expect(unconfirmed.coordinateConfirmed, isTrue);
    expect(find.text('모든 도시의 위치가 확인되었습니다. 탐색과 지도에서 쓸 수 있습니다.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('detail-open-itinerary')), find.byKey(const Key('trip-detail-scroll')));
    expect(find.text('일정 보기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-open-itinerary')));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 2);
    expect(find.byKey(const Key('screen-title-itinerary')), findsOneWidget);
  });

  testWidgets('확인된 도시 위치를 상세와 도시 위치 화면에서 다시 고른다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hero-title')));
    await tester.pumpAndSettle();
    const relocate = Key('detail-relocate-city-shanghai');
    await _scrollTo(tester, find.byKey(relocate), find.byKey(const Key('trip-detail-scroll')));
    await tester.tap(find.byKey(relocate));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 1);
    expect(find.byKey(const Key('screen-title-city-edit')), findsOneWidget);
    expect(find.text('새 위치를 고르세요'), findsOneWidget);
    expect(find.text('지금 위치'), findsOneWidget);
    expect(find.byKey(const Key('relocate-city-shanghai')), findsNothing);

    await tester.tap(find.byKey(const Key('cancel-relocate-city-shanghai')));
    await tester.pumpAndSettle();
    expect(find.text('새 위치를 고르세요'), findsNothing);
    expect(find.text('좌표 31.2304, 121.4737'), findsOneWidget);

    await tester.tap(find.byKey(const Key('relocate-city-shanghai')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('candidate-city-shanghai-1')), find.byKey(const Key('city-edit-scroll')));
    await tester.tap(find.byKey(const Key('candidate-city-shanghai-1')));
    await tester.pumpAndSettle();
    final city = controller.current!.cities.firstWhere((item) => item.id == 'city-shanghai');
    expect(city.coordinateLabel, '31.2397, 121.4905');
    expect(find.text('좌표 31.2397, 121.4905'), findsOneWidget);
    expect(find.byKey(const Key('relocate-city-shanghai')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 폰에서 위치 다시 고르기 후보가 넘치지 않는다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(320, 568));
    final controller = TripController()
      ..openCityEdit()
      ..selectTab(1)
      ..startRelocate('city-shanghai');
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('cancel-relocate-city-shanghai')), findsOneWidget);
  });

  testWidgets('태블릿에서 다른 여행을 고른 뒤 진행 중 카드로 돌아올 수 있다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(1024, 1366));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-card-trip-south')));
    await tester.pumpAndSettle();
    expect(controller.currentTripId, 'trip-south');

    await tester.tap(find.byKey(const Key('hero-title')));
    await tester.pumpAndSettle();
    expect(controller.currentTripId, 'trip-river');
    expect(controller.homePushed, isFalse);

    await tester.tap(find.byKey(const Key('trip-card-trip-south')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hero-open-itinerary')));
    await tester.pumpAndSettle();
    expect(controller.currentTripId, 'trip-river');
    expect(controller.tabIndex, 2);
    expect(controller.selectedItem(), isNotNull);
  });

  testWidgets('여행 만들기는 빠진 값을 알려 주고, 고치면 저장된다', (tester) async {
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    final before = controller.trips.length;
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-trip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('form-city-name-0')), findsOneWidget);
    expect(find.byKey(const Key('form-remove-city-0')), findsNothing);
    expect(find.text('두 글자 코드'), findsNothing);

    await _scrollTo(tester, find.byKey(const Key('form-save')), find.byKey(const Key('trip-form-scroll')));
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(controller.trips.length, before);
    expect(find.byKey(const Key('form-error-summary')), findsOneWidget);
    expect(find.text('제목을 입력하세요.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('제목을 입력하세요.')).dy, lessThan(500));

    await tester.enterText(find.byKey(const Key('form-title')), '가을 상하이');
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력하세요.'), findsNothing);

    await tester.tap(find.byKey(const Key('form-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('2026.11.15 (일)'), findsWidgets);
    expect(find.text('2026.11.18 (수)'), findsWidgets);

    await _scrollTo(tester, find.byKey(const Key('form-add-city')), find.byKey(const Key('trip-form-scroll')));
    await tester.tap(find.byKey(const Key('form-add-city')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('form-remove-city-1')), find.byKey(const Key('trip-form-scroll')));
    await tester.tap(find.byKey(const Key('form-remove-city-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-city-name-1')), findsNothing);

    await _scrollTo(tester, find.byKey(const Key('form-city-name-0')), find.byKey(const Key('trip-form-scroll')));
    await tester.enterText(find.byKey(const Key('form-city-name-0')), '상하이');
    await _scrollTo(tester, find.byKey(const Key('form-budget')), find.byKey(const Key('trip-form-scroll')));
    await tester.enterText(find.byKey(const Key('form-budget')), '12a00');
    expect(find.text('1200'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form-budget')), '');
    await tester.enterText(find.byKey(const Key('form-tag')), '야경');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-tag')), '야경');
    await tester.tap(find.byKey(const Key('form-add-tag')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '야경'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('form-companion-plus')), find.byKey(const Key('trip-form-scroll')));
    await tester.tap(find.byKey(const Key('form-companion-plus')));
    await tester.pumpAndSettle();
    expect(find.text('본인 제외 · 총 2명'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('form-save')), find.byKey(const Key('trip-form-scroll')));
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(controller.trips.length, before + 1);
    final made = controller.current!;
    expect(made.title, '가을 상하이');
    expect(made.cities.single.name, '상하이');
    expect(made.cities.single.start, DateTime(2026, 11, 15));
    expect(made.cities.single.end, DateTime(2026, 11, 18));
    expect(made.companionCount, 1);
    expect(made.tasteTags, ['야경']);
    expect(controller.creating, isFalse);
    expect(find.text('일정 만들러 가기'), findsOneWidget);

    await tester.tap(find.text('일정 만들러 가기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('itinerary-none')), findsOneWidget);
    expect(find.text('일정 만들기'), findsOneWidget);
  });

  testWidgets('작성 중인 여행을 닫으면 버릴지 묻는다', (tester) async {
    await _setView(tester, const Size(390, 844));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-trip')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(controller.creating, isFalse);

    await tester.tap(find.byKey(const Key('create-trip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-title')), '임시');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('작성 중인 여행을 버릴까요?'), findsOneWidget);
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(controller.creating, isTrue);
    expect(find.text('임시'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();
    expect(controller.creating, isFalse);
  });

  testWidgets('일정은 오프라인 이유를 말하고, 제안 검토와 항목 삭제가 분명하다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController()..offline = true;
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-itinerary')));
    await tester.pumpAndSettle();

    expect(find.text('온라인이 되면 생성합니다'), findsNothing);
    expect(tester.widget<TextButton>(find.descendant(of: find.byKey(const Key('request-itinerary')), matching: find.byType(TextButton))).onPressed, isNull);
    expect(find.text('오프라인에서는 일정을 만들 수 없습니다. 연결되면 다시 누르세요.'), findsOneWidget);

    controller.offline = false;
    controller.selectTab(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('itinerary-offline-note')), findsNothing);
    expect(find.text('새로 제안받기'), findsOneWidget);

    await tester.tap(find.text('제안 검토'));
    await tester.pumpAndSettle();
    expect(find.text('현재 일정 보기'), findsOneWidget);
    expect(find.text('적용하면 지금 일정을 이 제안으로 바꿉니다.'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('apply-proposal'))).dy, tester.getTopLeft(find.byKey(const Key('discard-proposal'))).dy);
    await tester.tap(find.text('현재 일정 보기'));
    await tester.pumpAndSettle();
    expect(controller.reviewingProposal, isFalse);
    expect(find.text('제안 검토'), findsOneWidget);

    final day = controller.visibleDay(controller.current!)!;
    final item = day.items.first;
    final count = day.items.length;
    controller.openItem(item.id, tablet: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-delete')));
    await tester.pumpAndSettle();
    expect(find.text('‘${item.title}’ 항목을 일정에서 삭제할까요?'), findsOneWidget);
    expect(find.text('이 날짜의 일정에서 지워집니다. 되돌릴 수 없습니다.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-item')));
    await tester.pumpAndSettle();
    expect(day.items.length, count - 1);
    expect(controller.itineraryPushed, isFalse);
  });

  testWidgets('여행 삭제는 무엇이 지워지는지 말한 뒤 지운다', (tester) async {
    await _setView(tester, const Size(1024, 1366));
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-card-trip-south')));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('detail-delete-trip')), find.byKey(const Key('trip-detail-scroll')));
    await tester.tap(find.byKey(const Key('detail-delete-trip')));
    await tester.pumpAndSettle();
    expect(find.text('‘남쪽 바다’ 여행을 삭제할까요?'), findsOneWidget);
    expect(find.text('일정과 장소 선택이 이 기기에서 함께 지워집니다. 되돌릴 수 없습니다.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-trip')));
    await tester.pumpAndSettle();
    expect(controller.trips.any((trip) => trip.id == 'trip-south'), isFalse);
    expect(find.text('여행을 고르세요.'), findsOneWidget);
  });

  final itinerarySetups = <String, void Function(TripController)>{
    '일정': (controller) => controller.selectTab(2),
    '제안 검토': (controller) => controller
      ..selectTab(2)
      ..startReview(),
    '오프라인 제안 검토': (controller) => controller
      ..offline = true
      ..selectTab(2)
      ..startReview(),
  };
  for (final entry in itinerarySetups.entries) {
    testWidgets('작은 폰에서도 ${entry.key} 화면이 넘치지 않는다', (tester) async {
      await tester.runAsync(warmSampleMap);
      await _setView(tester, const Size(320, 568));
      final controller = TripController();
      entry.value(controller);
      await tester.pumpWidget(TripWeaveApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('itinerary-scroll')), findsOneWidget);
    });
  }

  testWidgets('보통 폰의 일정 화면은 지도를 유지한다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final controller = TripController()
      ..selectTab(2)
      ..startReview();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('trip-map')), findsOneWidget);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target, Finder list) async {
  await tester.scrollUntilVisible(target, 200, scrollable: find.descendant(of: list, matching: find.byType(Scrollable)).first);
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
