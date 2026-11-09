import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/geo.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/map/place_pins.dart';
import 'package:trip_weave/map/trip_map.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/theme/app_theme.dart';
import 'package:trip_weave/widgets/chrome.dart';

const _sizes = {'폰': Size(390, 844), '작은 폰': Size(320, 568), '태블릿 세로': Size(1024, 1366), '태블릿 가로': Size(1366, 1024)};

Future<void> _setView(WidgetTester tester, Size size, {double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps and fails with the screen name when layout reported an overflow.
Future<void> _settle(WidgetTester tester, String screen) async {
  await tester.pumpAndSettle();
  final error = tester.takeException();
  expect(error, isNull, reason: '$screen: $error');
}

void _stretch(TripController controller) {
  final trip = controller.current!;
  trip.title = '아주아주긴여행제목이줄바꿈없이계속이어지는경우에도카드와상세가넘치지않아야합니다상하이도보여행';
  final first = trip.cities.firstWhere((city) => city.coordinateConfirmed);
  for (var index = 0; index < 24; index++) {
    trip.cities.add(City(id: 'extra-$index', name: '아주 긴 이름을 가진 도시 $index', countryCode: 'CN', start: trip.start, end: trip.end, sortOrder: 10 + index));
  }
  for (var index = 0; index < 40; index++) {
    controller.places.add(
      Place(id: 'many-$index', name: '이름이 꽤 긴 샘플 장소 번호 $index 번째 골목 안쪽 가게', category: PlaceCategory.values[index % 4], cityName: first.name, claims: const []),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in const [1.5, 2.0]) {
    for (final entry in _sizes.entries) {
      testWidgets('글자 $scale배 ${entry.key}에서 홈·상세·탐색·장소·기록·빈 화면이 넘치지 않는다', (tester) async {
        await tester.runAsync(warmSampleMap);
        await _setView(tester, entry.value, scale: scale);
        final tablet = entry.value.shortestSide >= 600;
        final controller = TripController();
        _stretch(controller);
        await tester.pumpWidget(TripWeaveApp(controller: controller));
        await _settle(tester, '홈');

        controller.openHome(controller.currentTripId!);
        await _settle(tester, '여행 상세');

        controller.selectTab(1);
        await _settle(tester, '탐색');
        controller.openPlace(controller.visiblePlaces().first.id, tablet: tablet);
        await _settle(tester, '장소');

        controller.selectTab(4);
        await _settle(tester, '기록');

        controller.currentTripId = null;
        for (final tab in const [1, 4]) {
          controller.selectTab(tab);
          await _settle(tester, '여행 없는 탭 $tab');
        }
        controller.trips.clear();
        controller.selectTab(0);
        await _settle(tester, '여행 없는 홈');
      });
    }
  }

  testWidgets('글자 2배에서도 기록 날짜 칸이 두 줄을 담는다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844), scale: 2);
    final controller = TripController()..selectTab(4);
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await _settle(tester, '기록');
    expect(tester.getSize(find.byType(DateToken).first).height, greaterThan(64));
  });

  testWidgets('홈, 상세, 탐색, 장소, 기록의 누를 곳은 48 이상이고 라벨이 있다', (tester) async {
    await tester.runAsync(warmSampleMap);
    await _setView(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));

    Future<void> check(String screen) async {
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: screen);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: screen);
    }

    await check('홈');
    controller.openHome(controller.currentTripId!);
    await check('여행 상세');
    controller.selectTab(1);
    await check('탐색');
    controller.openPlace(controller.visiblePlaces().first.id, tablet: false);
    await check('장소');
    controller.selectTab(4);
    await check('기록');
    handle.dispose();
  });

  testWidgets('탭 바는 전체 이름과 선택 상태를 읽어 준다', (tester) async {
    await _setView(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(TripWeaveApp(controller: TripController()));
    await tester.pumpAndSettle();

    final home = tester.getSemantics(find.byKey(const Key('tab-home'))).getSemanticsData();
    expect(home.label, '여행 홈');
    expect(home.hasFlag(SemanticsFlag.isSelected), isTrue);
    final journal = tester.getSemantics(find.byKey(const Key('tab-journal'))).getSemanticsData();
    expect(journal.label, '여행 기록');
    expect(journal.hasFlag(SemanticsFlag.isSelected), isFalse);
    handle.dispose();
  });

  testWidgets('지도 핀은 번호와 이름을 읽어 주고 48 칸 안을 눌러도 열린다', (tester) async {
    final handle = tester.ensureSemantics();
    MapPin? tapped;
    final pins = [
      MapPin(id: 'a', placeId: 'a', point: const GeoPoint(31.2435, 121.4912), label: '외탄', order: 1, emphasized: true),
      MapPin(id: 'b', placeId: 'b', point: const GeoPoint(31.2273, 121.4924), label: '예원', order: 2, past: true),
      MapPin(id: 'c', placeId: 'c', point: const GeoPoint(31.2357, 121.4810), label: '근처 가게', nearby: true),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 390, height: 400, child: TripMap(pins: pins, onPinTap: (pin) => tapped = pin))),
        ),
      ),
    );
    await tester.pump();

    expect(mapPinSemanticLabel(pins[0]), '1번 방문, 외탄, 다음 목적지');
    expect(mapPinSemanticLabel(pins[1]), '2번 방문, 예원, 지난 방문');
    expect(mapPinSemanticLabel(pins[2]), '근처 가게, 주변 장소');
    expect(find.bySemanticsLabel('1번 방문, 외탄, 다음 목적지'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^지도, 방문 2곳')), findsOneWidget);

    final pin = find.byKey(const Key('map-pin-a'));
    final box = tester.getRect(pin);
    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tapAt(box.bottomLeft + const Offset(4, -4));
    expect(tapped?.id, 'a');
    expect(tester.getSemantics(pin).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  test('보조 회색 글자는 흰 바탕과 캔버스에서 4.5:1 이상이다', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    for (final background in const [AppColors.card, AppColors.canvas, Color(0xFFF7F7F8)]) {
      expect(ratio(AppColors.tertiary, background), greaterThanOrEqualTo(4.5));
      expect(ratio(AppColors.secondary, background), greaterThanOrEqualTo(4.5));
    }
  });
}
