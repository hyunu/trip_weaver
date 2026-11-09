import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/format.dart';
import 'package:trip_weave/logic/city_lookup.dart';
import 'package:trip_weave/logic/schedule.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  test('상하이 도시 이름은 상하이 좌표로 찾는다', () {
    final found = candidatesForCity('상하이');
    expect(found.first.coordinateLabel, '31.2304, 121.4737');
    expect(candidatesForCity('서울'), isEmpty);
  });

  test('확인된 도시 위치를 다른 후보로 다시 고를 수 있다', () {
    final controller = TripController();
    final trip = controller.current!;
    final city = trip.cities.firstWhere((item) => item.id == 'city-shanghai');
    final edits = trip.pendingLocalEdits;
    final candidates = candidatesForCity(city.name);
    expect(isCurrentLocation(city, candidates[0]), isTrue);
    expect(isCurrentLocation(city, candidates[1]), isFalse);

    controller.startRelocate(city.id);
    expect(controller.relocatingCityIds, contains(city.id));
    expect(controller.cityCandidates[city.id], hasLength(2));

    controller.pickCandidate(city.id, controller.cityCandidates[city.id]![1]);
    expect(city.coordinateConfirmed, isTrue);
    expect(city.coordinateLabel, '31.2397, 121.4905');
    expect(city.coordinateCandidateId, 'shanghai-bund');
    expect(trip.pendingLocalEdits, edits + 1);
    expect(controller.relocatingCityIds, isEmpty);
    expect(controller.cityCandidates[city.id], isNull);
    expect(isCurrentLocation(city, candidates[1]), isTrue);
    expect(isCurrentLocation(city, candidates[0]), isFalse);

    controller.startRelocate(city.id);
    controller.pickCandidate(city.id, candidates[1]);
    expect(trip.pendingLocalEdits, edits + 1);
  });

  test('다시 고르기를 취소하면 확인된 좌표가 그대로다', () {
    final controller = TripController();
    final city = controller.current!.cities.firstWhere((item) => item.id == 'city-shanghai');
    controller.startRelocate(city.id);
    controller.cancelRelocate(city.id);
    expect(controller.relocatingCityIds, isEmpty);
    expect(controller.cityCandidates[city.id], isNull);
    expect(city.coordinateLabel, '31.2304, 121.4737');

    controller.offline = true;
    controller.startRelocate(city.id);
    expect(controller.relocatingCityIds, contains(city.id));
    expect(controller.cityCandidates[city.id], isNull);
    controller.closeCityEdit();
    expect(controller.relocatingCityIds, isEmpty);
  });

  test('다음 목적지는 끝나지 않은 첫 방문이다', () {
    final controller = TripController();
    final trip = controller.current!;
    final next = controller.destinationFor(trip);
    expect(next?.title, '루자쭈이 전망');
    expect(next?.id, 'd1108-gallery');
    final today = dayFor(trip.activeDays, controller.now)!;
    expect(previousVisit(today.items, controller.now)?.title, '외탄 공원');
  });

  test('제안 적용 전에는 활성 일정이 유지된다', () {
    final controller = TripController();
    final before = _stayTitles(controller);
    expect(before, ['외탄 공원', '루자쭈이 전망', '예원 골목']);
    controller.startReview();
    expect(_stayTitles(controller), before);
    controller.applyProposal();
    expect(controller.reviewingProposal, isFalse);
    expect(controller.current!.proposalDays, isNull);
    expect(_stayTitles(controller), ['외탄 공원', '예원 골목', '루자쭈이 전망']);
  });

  test('제안 버리기는 활성 일정을 바꾸지 않는다', () {
    final controller = TripController();
    controller.discardProposal();
    expect(_stayTitles(controller), ['외탄 공원', '루자쭈이 전망', '예원 골목']);
    expect(controller.current!.proposalDays, isNull);
  });

  test('오프라인 일정 만들기는 결과를 그리지 않는다', () {
    final controller = TripController();
    final before = controller.current!.proposalDays!.length;
    controller.offline = true;
    controller.requestItinerary();
    expect(controller.itineraryDeferred, isTrue);
    expect(controller.reviewingProposal, isFalse);
    expect(controller.current!.proposalDays!.length, before);
    expect(controller.current!.activeDays[2].items[2].title, '루자쭈이 전망');
  });

  test('생성된 이동에는 노선 문장이 없다', () {
    final controller = TripController();
    controller.requestItinerary();
    final proposal = controller.current!.proposalDays!;
    expect(controller.reviewingProposal, isTrue);
    expect(controller.current!.activeDays[2].items[2].title, '루자쭈이 전망');
    final titles = proposal.expand((day) => day.items).map((item) => item.title).join(' ');
    expect(titles.contains('호선'), isFalse);
    expect(titles.contains('옛 부두 상점'), isFalse);
    final moves = proposal.expand((day) => day.items).where((item) => item.kind == ItemKind.move);
    expect(moves, isNotEmpty);
    expect(moves.every((item) => item.warnings.contains(ItemWarning.estimatedGeometry)), isTrue);
  });

  test('수집된 운영시간은 확인됨 배지가 아니다', () {
    final controller = TripController();
    final gallery = controller.placeById('gallery')!;
    final hours = gallery.claimsFor('hours').single;
    expect(hours.validity, FactValidity.collected);
    expect(hours.value, '10:00–18:00');
    expect(badgeLabel(rowBadge(gallery)), '출처 1곳, 미확인');
    final market = controller.placeById('market')!;
    expect(market.claimsFor('hours').map((claim) => claim.value), ['09:00–18:00', '10:00–16:00']);
    expect(badgeLabel(rowBadge(market)), '출처마다 다릅니다');
  });

  test('예산 표기', () {
    expect(moneyLabel(400000, 'KRW'), '400,000 KRW');
    expect(moneyLabel(null, null), '예산 없음');
  });
}

List<String> _stayTitles(TripController controller) {
  final day = controller.current!.activeDays.firstWhere((item) => item.date.day == 8 && item.date.month == 11);
  return day.items.where((item) => item.kind == ItemKind.stay).map((item) => item.title).toList();
}
