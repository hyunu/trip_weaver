import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/map/place_pins.dart';
import 'package:trip_weave/map/trip_map.dart';
import 'package:trip_weave/shell/scope.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/theme/app_theme.dart';

void main() {
  testWidgets('오프라인이고 타일이 없으면 지도 안내가 보인다', (tester) async {
    OsmTileStore.instance.resetForTest();
    addTearDown(OsmTileStore.instance.resetForTest);

    final controller = TripController()..setOffline(true);
    final day = controller.visibleDay(controller.current!)!;
    final pins = visitPins(day, controller.placeById);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: TripScope(
          controller: controller,
          child: Center(
            child: SizedBox(width: 390, height: 240, child: TripMap(pins: pins)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('map-tile')), findsOneWidget);
    expect(find.text('지도 타일을 불러오지 못했습니다. 연결을 확인하세요.'), findsOneWidget);
  });
}
