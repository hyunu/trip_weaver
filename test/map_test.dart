import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/map/geo.dart';
import 'package:trip_weave/map/place_pins.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  test('방문 핀 번호는 체류와 식사만 일정 순으로 매긴다', () {
    final controller = TripController();
    final day = controller.current!.activeDays.firstWhere((item) => item.date.day == 8);
    final pins = visitPins(day, controller.placeById);
    expect(pins.map((pin) => pin.order).toList(), [1, 2, 3, 4]);
    expect(pins.map((pin) => pin.id).toList(), ['d1108-park', 'd1108-gallery', 'd1108-meal', 'd1108-market']);
    final withNearby = [
      ...pins,
      MapPin(id: 'wharf', placeId: 'wharf', point: const GeoPoint(31.23, 121.49), label: '부두', nearby: true),
    ];
    expect(orderedVisitPins(withNearby).map((pin) => pin.id).toList(), ['d1108-park', 'd1108-gallery', 'd1108-meal', 'd1108-market']);
  });

  test('방문 순서 거리 라벨은 직선 합과 시속 4.5km 도보 시간이다', () {
    const a = GeoPoint(0, 0);
    const b = GeoPoint(0, 1);
    final leg = distanceMeters(a, b);
    expect(leg, closeTo(111194.9, 1));
    final pins = [
      MapPin(id: 'a', placeId: 'a', point: a, label: 'A', order: 2),
      MapPin(id: 'b', placeId: 'b', point: b, label: 'B', order: 1),
      MapPin(id: 'near', placeId: 'near', point: const GeoPoint(0, 0.5), label: '근처', nearby: true),
    ];
    expect(visitRouteMeters(pins), closeTo(leg, 1));
    final minutes = straightWalkMinutes(leg);
    expect(routeEstimateLabel(visitRouteMeters(pins), orderedVisitPins(pins).length), '방문 2곳 직선 ${formatMeters(leg)} · 도보 약 $minutes분 (시속 4.5km, 도로 경로 아님)');
    expect(routeEstimateLabel(0, 1), '방문 순서를 이을 장소가 2곳 미만이라 직선 거리를 합산하지 않습니다.');
  });
}
