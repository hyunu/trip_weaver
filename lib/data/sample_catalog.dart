import '../model/models.dart';

class SampleCatalog {
  const SampleCatalog({required this.trips, required this.places, required this.currentTripId});

  final List<Trip> trips;
  final List<Place> places;
  final String currentTripId;
}

SampleCatalog buildSampleCatalog() {
  final collected = DateTime(2026, 11, 1, 9);
  final verified = DateTime(2026, 11, 2, 15);

  Claim claim({
    required String field,
    required String? value,
    required FactValidity validity,
    required String sourceName,
    DateTime? verifiedAt,
    SourceKind sourceKind = SourceKind.official,
  }) {
    return Claim(
      field: field,
      value: value,
      validity: validity,
      sourceName: sourceName,
      sourceKind: sourceKind,
      collectedAt: collected,
      verifiedAt: verifiedAt,
    );
  }

  final places = <Place>[
    Place(
      id: 'park',
      name: '외탄 공원',
      localName: '外滩',
      category: PlaceCategory.attraction,
      cityName: '상하이',
      claims: [
        claim(field: 'coordinate', value: '31.2435, 121.4912', validity: FactValidity.corroborated, sourceName: 'mock 지오코더', verifiedAt: verified),
        claim(field: 'coordinate', value: '31.2435, 121.4912', validity: FactValidity.corroborated, sourceName: 'mock 시 자료', verifiedAt: verified),
        claim(field: 'address', value: '중산동 1로', validity: FactValidity.corroborated, sourceName: 'mock 공식 안내', verifiedAt: verified),
        claim(field: 'address', value: '중산동 1로', validity: FactValidity.corroborated, sourceName: 'mock 시 자료', verifiedAt: verified),
        claim(field: 'hours', value: '09:00–17:00', validity: FactValidity.corroborated, sourceName: 'mock 공식 안내', verifiedAt: verified),
        claim(field: 'hours', value: '09:00–17:00', validity: FactValidity.corroborated, sourceName: 'mock 시 자료', verifiedAt: verified),
      ],
    ),
    Place(
      id: 'gallery',
      name: '루자쭈이 전망',
      category: PlaceCategory.culture,
      cityName: '상하이',
      claims: [
        claim(field: 'coordinate', value: '31.2408, 121.5012', validity: FactValidity.collected, sourceName: 'mock 지오코더'),
        claim(field: 'address', value: '루자쭈이로 100', validity: FactValidity.collected, sourceName: 'mock 안내 페이지'),
        claim(field: 'hours', value: '10:00–18:00', validity: FactValidity.collected, sourceName: 'mock 안내 페이지'),
      ],
    ),
    Place(
      id: 'market',
      name: '예원 골목',
      localName: '豫园',
      category: PlaceCategory.shopping,
      cityName: '상하이',
      claims: [
        claim(field: 'coordinate', value: '31.2273, 121.4924', validity: FactValidity.collected, sourceName: 'mock 지오코더'),
        claim(field: 'address', value: '예원로 218', validity: FactValidity.collected, sourceName: 'mock 시장 조합'),
        claim(field: 'hours', value: '09:00–18:00', validity: FactValidity.conflicted, sourceName: 'mock 시장 조합'),
        claim(field: 'hours', value: '10:00–16:00', validity: FactValidity.conflicted, sourceName: 'mock 현장 메모'),
      ],
    ),
    Place(
      id: 'noodle',
      name: '난징루 식당',
      category: PlaceCategory.restaurant,
      cityName: '상하이',
      aiOrderSentence: '추천을 부탁합니다.',
      claims: [
        claim(field: 'coordinate', value: '31.2357, 121.4810', validity: FactValidity.collected, sourceName: 'mock 지오코더'),
        claim(field: 'address', value: '난징동로 100', validity: FactValidity.collected, sourceName: 'mock 안내 페이지'),
        claim(field: 'hours', value: '11:00–21:00', validity: FactValidity.collected, sourceName: 'mock 안내 페이지'),
      ],
    ),
    Place(
      id: 'wharf',
      name: '옛 부두 상점',
      category: PlaceCategory.shopping,
      cityName: '상하이',
      claims: [
        claim(field: 'coordinate', value: '31.2335, 121.4888', validity: FactValidity.collected, sourceName: 'mock 지오코더'),
        claim(field: 'address', value: '외탄로 2', validity: FactValidity.collected, sourceName: 'mock 공식 목록'),
        claim(field: 'business', value: '운영 중단 자료가 있습니다', validity: FactValidity.suspended, sourceName: 'mock 공식 목록'),
      ],
    ),
  ];

  PlanItem stay({
    required String id,
    required String title,
    required String placeId,
    required String category,
    required DateTime start,
    required DateTime end,
    List<String> unconfirmed = const [],
    List<ItemWarning> warnings = const [],
    bool locked = false,
    bool hoursConflict = false,
  }) {
    return PlanItem(
      id: id,
      kind: ItemKind.stay,
      title: title,
      placeId: placeId,
      categoryLabel: category,
      start: start,
      end: end,
      unconfirmedFields: unconfirmed,
      warnings: warnings,
      locked: locked,
      hoursConflict: hoursConflict,
      dwellIsProposal: true,
    );
  }

  PlanItem move({required String id, required DateTime start, required DateTime end}) {
    return PlanItem(
      id: id,
      kind: ItemKind.move,
      title: '',
      start: start,
      end: end,
      unconfirmedFields: const ['경로'],
      warnings: const [ItemWarning.estimatedGeometry],
    );
  }

  PlanItem meal({
    required String id,
    required String title,
    required DateTime start,
    required DateTime end,
    String? placeId,
    String? note,
    List<String> unconfirmed = const ['예약', '메뉴', '가격'],
  }) {
    return PlanItem(
      id: id,
      kind: ItemKind.meal,
      title: title,
      placeId: placeId,
      categoryLabel: placeId == null ? null : '음식점',
      start: start,
      end: end,
      unconfirmedFields: unconfirmed,
      dwellIsProposal: true,
      note: note,
    );
  }

  DateTime at(int month, int day, [int hour = 0, int minute = 0]) => DateTime(2026, month, day, hour, minute);

  DayPlan dayNov6() {
    return DayPlan(
      date: at(11, 6),
      items: [
        stay(
          id: 'd1106-park',
          title: '외탄 공원',
          placeId: 'park',
          category: '관광지',
          start: at(11, 6, 10),
          end: at(11, 6, 11, 30),
          unconfirmed: const ['휴무'],
          warnings: const [ItemWarning.closureUnconfirmed],
        ),
        move(id: 'd1106-move', start: at(11, 6, 11, 30), end: at(11, 6, 11, 45)),
        meal(id: 'd1106-meal', title: '난징루 식당', placeId: 'noodle', start: at(11, 6, 12), end: at(11, 6, 13, 30)),
        stay(
          id: 'd1106-gallery',
          title: '루자쭈이 전망',
          placeId: 'gallery',
          category: '문화시설',
          start: at(11, 6, 14),
          end: at(11, 6, 15, 30),
          unconfirmed: const ['운영시간'],
          warnings: const [ItemWarning.hoursUnconfirmed],
        ),
      ],
    );
  }

  DayPlan dayNov7() {
    return DayPlan(
      date: at(11, 7),
      items: [
        stay(
          id: 'd1107-market',
          title: '예원 골목',
          placeId: 'market',
          category: '쇼핑',
          start: at(11, 7, 11),
          end: at(11, 7, 12),
          unconfirmed: const ['휴무'],
          warnings: const [ItemWarning.hoursConflict, ItemWarning.closureUnconfirmed],
          hoursConflict: true,
        ),
        meal(id: 'd1107-meal', title: '난징루 식당', placeId: 'noodle', start: at(11, 7, 12, 30), end: at(11, 7, 13, 45)),
        PlanItem(
          id: 'd1107-rest',
          kind: ItemKind.rest,
          title: '휴식',
          start: at(11, 7, 14),
          end: at(11, 7, 14, 30),
          note: '연속 방문 뒤에 제안한 휴식입니다.',
        ),
        stay(
          id: 'd1107-park',
          title: '외탄 공원',
          placeId: 'park',
          category: '관광지',
          start: at(11, 7, 15),
          end: at(11, 7, 16, 30),
          unconfirmed: const ['휴무'],
          warnings: const [ItemWarning.closureUnconfirmed],
        ),
      ],
    );
  }

  final dayNov8 = DayPlan(
    date: at(11, 8),
    items: [
      stay(
        id: 'd1108-park',
        title: '외탄 공원',
        placeId: 'park',
        category: '관광지',
        start: at(11, 8, 9),
        end: at(11, 8, 10, 30),
        unconfirmed: const ['휴무'],
        warnings: const [ItemWarning.closureUnconfirmed],
        locked: true,
      ),
      move(id: 'd1108-move-1', start: at(11, 8, 10, 30), end: at(11, 8, 10, 50)),
      stay(
        id: 'd1108-gallery',
        title: '루자쭈이 전망',
        placeId: 'gallery',
        category: '문화시설',
        start: at(11, 8, 10, 50),
        end: at(11, 8, 12, 20),
        unconfirmed: const ['운영시간'],
        warnings: const [ItemWarning.hoursUnconfirmed],
      ),
      move(id: 'd1108-move-2', start: at(11, 8, 12, 20), end: at(11, 8, 12, 30)),
      meal(id: 'd1108-meal', title: '난징루 식당', placeId: 'noodle', start: at(11, 8, 12, 30), end: at(11, 8, 13, 45)),
      PlanItem(
        id: 'd1108-rest',
        kind: ItemKind.rest,
        title: '휴식',
        start: at(11, 8, 13, 45),
        end: at(11, 8, 14, 15),
        note: '연속 방문 뒤에 제안한 휴식입니다.',
      ),
      move(id: 'd1108-move-3', start: at(11, 8, 14, 15), end: at(11, 8, 14, 30)),
      PlanItem(
        id: 'd1108-gap',
        kind: ItemKind.gap,
        title: '대체 장소 없음',
        start: at(11, 8, 14, 30),
        unconfirmedFields: const ['장소'],
        warnings: const [ItemWarning.noReplacement],
      ),
      stay(
        id: 'd1108-market',
        title: '예원 골목',
        placeId: 'market',
        category: '쇼핑',
        start: at(11, 8, 15),
        end: at(11, 8, 16),
        unconfirmed: const ['휴무'],
        warnings: const [ItemWarning.hoursConflict, ItemWarning.closureUnconfirmed],
        hoursConflict: true,
      ),
    ],
  );

  DayPlan dayNov9() {
    return DayPlan(
      date: at(11, 9),
      items: [
        stay(
          id: 'd1109-gallery',
          title: '루자쭈이 전망',
          placeId: 'gallery',
          category: '문화시설',
          start: at(11, 9, 9, 30),
          end: at(11, 9, 11),
          unconfirmed: const ['운영시간'],
          warnings: const [ItemWarning.hoursUnconfirmed],
        ),
        move(id: 'd1109-move', start: at(11, 9, 11), end: at(11, 9, 11, 20)),
        stay(
          id: 'd1109-park',
          title: '외탄 공원',
          placeId: 'park',
          category: '관광지',
          start: at(11, 9, 11, 30),
          end: at(11, 9, 13),
          unconfirmed: const ['휴무'],
          warnings: const [ItemWarning.closureUnconfirmed],
        ),
        meal(id: 'd1109-meal', title: '난징루 식당', placeId: 'noodle', start: at(11, 9, 13, 15), end: at(11, 9, 14, 30)),
      ],
    );
  }

  DayPlan portDay(int day, String id) {
    return DayPlan(
      date: at(11, day),
      items: [
        meal(
          id: id,
          title: '식사, 장소 미정',
          start: at(11, day, 12),
          end: at(11, day, 13, 30),
          unconfirmed: const ['장소', '예약', '메뉴'],
          note: '도시 위치가 확인되지 않았습니다.',
        ),
      ],
    );
  }

  final activeDays = [dayNov6(), dayNov7(), dayNov8, dayNov9(), portDay(10, 'd1110-meal'), portDay(11, 'd1111-meal')];
  final proposalDays = activeDays.map((day) => day.clone()).toList();
  proposalDays[2] = DayPlan(
    date: at(11, 8),
    items: [
      stay(
        id: 'p1108-park',
        title: '외탄 공원',
        placeId: 'park',
        category: '관광지',
        start: at(11, 8, 9),
        end: at(11, 8, 10, 30),
        unconfirmed: const ['휴무'],
        warnings: const [ItemWarning.closureUnconfirmed],
        locked: true,
      ),
      stay(
        id: 'p1108-market',
        title: '예원 골목',
        placeId: 'market',
        category: '쇼핑',
        start: at(11, 8, 10, 45),
        end: at(11, 8, 11, 45),
        unconfirmed: const ['휴무'],
        warnings: const [ItemWarning.hoursConflict, ItemWarning.closureUnconfirmed],
        hoursConflict: true,
      ),
      move(id: 'p1108-move', start: at(11, 8, 11, 45), end: at(11, 8, 12)),
      meal(id: 'p1108-meal', title: '난징루 식당', placeId: 'noodle', start: at(11, 8, 12), end: at(11, 8, 13, 15)),
      stay(
        id: 'p1108-gallery',
        title: '루자쭈이 전망',
        placeId: 'gallery',
        category: '문화시설',
        start: at(11, 8, 13, 30),
        end: at(11, 8, 15),
        unconfirmed: const ['운영시간'],
        warnings: const [ItemWarning.hoursUnconfirmed],
      ),
    ],
  );

  final river = Trip(
    id: 'trip-river',
    title: '황푸와 외탄',
    countryCode: 'CN',
    countryName: '중국',
    start: DateTime(2026, 11, 6),
    end: DateTime(2026, 11, 11),
    status: TripStatus.active,
    purpose: '걸어서 미술관과 시장을 보는 일정',
    tasteTags: const ['도보', '국수'],
    budgetAmount: 400000,
    budgetCurrency: 'KRW',
    companionCount: 0,
    pendingLocalEdits: 2,
    dataOriginMock: true,
    weatherSkipped: true,
    cities: [
      City(
        id: 'city-shanghai',
        name: '상하이',
        countryCode: 'CN',
        start: DateTime(2026, 11, 6),
        end: DateTime(2026, 11, 9),
        sortOrder: 0,
        coordinateConfirmed: true,
        coordinateLabel: '31.2304, 121.4737',
        coordinateSource: 'mock 지오코더',
      ),
      City(
        id: 'city-port',
        name: '충밍',
        countryCode: 'CN',
        start: DateTime(2026, 11, 10),
        end: DateTime(2026, 11, 11),
        sortOrder: 1,
      ),
    ],
    links: {
      'park': TripPlaceLink(decision: Decision.selected, saved: true),
      'gallery': TripPlaceLink(decision: Decision.selected),
      'market': TripPlaceLink(decision: Decision.selected),
      'noodle': TripPlaceLink(decision: Decision.selected, saved: true),
      'wharf': TripPlaceLink(),
    },
    activeDays: activeDays,
    proposalDays: proposalDays,
  );

  final south = Trip(
    id: 'trip-south',
    title: '남쪽 바다',
    countryCode: 'KR',
    countryName: '대한민국',
    start: DateTime(2026, 11, 20),
    end: DateTime(2026, 11, 22),
    status: TripStatus.draft,
    companionCount: 1,
    dataOriginMock: true,
    cities: [
      City(
        id: 'city-south',
        name: '남해구',
        countryCode: 'KR',
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 22),
        sortOrder: 0,
        coordinateConfirmed: true,
        coordinateLabel: '34.8000, 128.4000',
        coordinateSource: 'mock 지오코더',
      ),
    ],
  );

  final winter = Trip(
    id: 'trip-winter',
    title: '겨울 골목',
    countryCode: 'KR',
    countryName: '대한민국',
    start: DateTime(2026, 1, 4),
    end: DateTime(2026, 1, 6),
    status: TripStatus.completed,
    purpose: '추운 날의 짧은 방문',
    dataOriginMock: true,
    cities: [
      City(
        id: 'city-north',
        name: '북구',
        countryCode: 'KR',
        start: DateTime(2026, 1, 4),
        end: DateTime(2026, 1, 6),
        sortOrder: 0,
        coordinateConfirmed: true,
        coordinateLabel: '37.7000, 127.1000',
        coordinateSource: 'mock 지오코더',
      ),
    ],
  );

  return SampleCatalog(trips: [river, south, winter], places: places, currentTripId: river.id);
}
