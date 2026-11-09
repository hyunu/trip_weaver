import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/format.dart';
import 'package:trip_weave/model/models.dart';

void main() {
  test('샘플 장소 출처는 예시로 적고 영업 주장 값은 유지한다', () {
    final catalog = buildSampleCatalog();
    final byId = {for (final place in catalog.places) place.id: place};

    expect(byId.keys, ['park', 'gallery', 'market', 'noodle', 'wharf']);
    for (final place in catalog.places) {
      expect(placeSuggestion(place.id), isNotNull);
      expect(placeSuggestion(place.id)!.length, greaterThan(12));
      for (final claim in place.claims) {
        expect(claim.sourceName.startsWith('샘플 · '), isTrue, reason: place.id);
        expect(claim.sourceName.contains('mock'), isFalse);
      }
    }

    final gallery = byId['gallery']!;
    expect(gallery.name, '루자쭈이 전망');
    expect(gallery.localName, '陆家嘴滨江');
    expect(gallery.claimsFor('hours').single.value, '10:00–18:00');
    expect(gallery.claimsFor('hours').single.validity, FactValidity.collected);
    expect(gallery.claimsFor('coordinate').single.value, '31.2408, 121.5012');
    expect(badgeLabel(rowBadge(gallery)), '출처 1곳, 미확인');

    final market = byId['market']!;
    expect(market.localName, '豫园商城');
    expect(market.claimsFor('hours').map((claim) => claim.value), ['09:00–18:00', '10:00–16:00']);
    expect(badgeLabel(rowBadge(market)), '출처마다 다릅니다');

    final park = byId['park']!;
    expect(park.localName, '黄浦公园');
    expect(park.claimsFor('address').map((claim) => claim.value).toSet(), {'황푸구 중산둥 1로 외탄'});
    expect(badgeLabel(rowBadge(park)), '확인됨');

    final noodle = byId['noodle']!;
    expect(noodle.name, '덕흥관');
    expect(noodle.localName, '德兴馆');
    expect(noodle.claimsFor('address').single.value, '황푸구 난징둥루 덕흥관');
    expect(placeSuggestion('noodle'), contains('덕흥관'));

    final wharf = byId['wharf']!;
    expect(wharf.name, '십육포');
    expect(wharf.localName, '十六铺');
    expect(wharf.suspended, isTrue);
    expect(placeSuggestion('wharf'), contains('자동 일정'));
    expect(placeSuggestion('missing'), isNull);
  });
}
