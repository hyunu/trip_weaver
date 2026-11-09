import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/state/connectivity.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  test('가짜 연결 포트는 오프라인 상태를 컨트롤러에 반영한다', () async {
    final controller = TripController();
    final port = FakeConnectivityPort(online: true);
    final watch = TripConnectivity(controller: controller, port: port)..start();
    addTearDown(watch.dispose);

    expect(controller.offline, isFalse);
    port.setOnline(false);
    await Future<void>.delayed(Duration.zero);
    expect(controller.offline, isTrue);
    port.setOnline(true);
    await Future<void>.delayed(Duration.zero);
    expect(controller.offline, isFalse);
  });

  test('타일 요청 실패도 오프라인으로 표시한다', () {
    final controller = TripController();
    final port = FakeConnectivityPort(online: true);
    final watch = TripConnectivity(controller: controller, port: port)..start();
    addTearDown(watch.dispose);

    OsmTileStore.instance.onFetchFailure?.call();
    expect(controller.offline, isTrue);
  });

  test('앱 소유 컨트롤러만 기본으로 연결 감시를 켠다', () {
    expect(const TripWeaveApp().watchConnectivity, isNull);
    expect(TripWeaveApp(controller: TripController()).watchConnectivity, isNull);
    expect(const TripWeaveApp(watchConnectivity: true).watchConnectivity, isTrue);
  });

  testWidgets('연결 감시를 켜면 오프라인 배너가 보인다', (tester) async {
    final controller = TripController();
    final port = FakeConnectivityPort(online: false);
    await tester.pumpWidget(
      TripWeaveApp(
        controller: controller,
        connectivityPort: port,
        watchConnectivity: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오프라인. 저장된 데이터만 표시합니다.'), findsOneWidget);
  });
}
