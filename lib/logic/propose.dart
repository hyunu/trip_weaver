import '../model/models.dart';

int proposedDwell(PlaceCategory category) {
  switch (category) {
    case PlaceCategory.attraction:
      return 90;
    case PlaceCategory.restaurant:
      return 75;
    case PlaceCategory.shopping:
      return 60;
    case PlaceCategory.culture:
      return 120;
  }
}

List<DayPlan>? proposeItinerary(Trip trip, List<Place> places) {
  if (trip.cities.isEmpty) return null;
  final days = <DayPlan>[];
  var seq = 0;
  var day = dateOnly(trip.start);
  final last = dateOnly(trip.end);
  while (!day.isAfter(last)) {
    days.add(DayPlan(date: day, items: _dayItems(trip, places, day, () => 'gen-${day.month}${day.day}-${seq++}')));
    day = day.add(const Duration(days: 1));
  }
  return days;
}

List<PlanItem> _dayItems(Trip trip, List<Place> places, DateTime day, String Function() nextId) {
  final city = trip.cityOn(day);
  if (city == null) {
    return [
      PlanItem(
        id: nextId(),
        kind: ItemKind.gap,
        title: '이 날짜의 도시가 지정되지 않았습니다',
        start: DateTime(day.year, day.month, day.day, 9),
        unconfirmedFields: const ['도시'],
        warnings: const [ItemWarning.cityUnassigned],
      ),
    ];
  }
  if (!city.coordinateConfirmed) {
    return [
      PlanItem(
        id: nextId(),
        kind: ItemKind.meal,
        title: '식사, 장소 미정',
        start: DateTime(day.year, day.month, day.day, 12),
        end: DateTime(day.year, day.month, day.day, 13, 30),
        unconfirmedFields: const ['장소', '예약', '메뉴'],
        dwellIsProposal: true,
        note: '도시 위치가 확인되지 않았습니다.',
      ),
    ];
  }

  final selected = <Place>[];
  for (final place in places) {
    if (place.cityName != city.name) continue;
    final link = trip.links[place.id];
    if (link == null || link.decision != Decision.selected) continue;
    if (place.suspended) continue;
    selected.add(place);
  }
  final visits = selected.where((place) => place.category != PlaceCategory.restaurant).toList();
  final restaurants = selected.where((place) => place.category == PlaceCategory.restaurant).toList();
  final items = <PlanItem>[];
  var cursor = DateTime(day.year, day.month, day.day, 9);
  var lunchPlaced = false;

  void addMove() {
    final end = cursor.add(const Duration(minutes: 15));
    items.add(
      PlanItem(
        id: nextId(),
        kind: ItemKind.move,
        title: '',
        start: cursor,
        end: end,
        unconfirmedFields: const ['경로'],
        warnings: const [ItemWarning.estimatedGeometry],
      ),
    );
    cursor = end;
  }

  void addLunch() {
    if (lunchPlaced) return;
    final start = cursor.isBefore(DateTime(day.year, day.month, day.day, 12))
        ? DateTime(day.year, day.month, day.day, 12)
        : cursor;
    final place = restaurants.isEmpty ? null : restaurants.first;
    items.add(
      PlanItem(
        id: nextId(),
        kind: ItemKind.meal,
        title: place?.name ?? '식사, 장소 미정',
        placeId: place?.id,
        categoryLabel: '음식점',
        start: start,
        end: DateTime(start.year, start.month, start.day, start.hour, start.minute + 90),
        unconfirmedFields: _mealFields(place),
        dwellIsProposal: true,
        note: '식사 시각은 초기 제안이며 현지 관습의 확정이 아닙니다.',
      ),
    );
    cursor = start.add(const Duration(minutes: 90));
    lunchPlaced = true;
  }

  for (var index = 0; index < visits.length; index++) {
    final place = visits[index];
    final dwell = proposedDwell(place.category);
    if (!lunchPlaced && !cursor.add(Duration(minutes: dwell)).isBefore(DateTime(day.year, day.month, day.day, 12, 1)) && cursor.hour >= 11) {
      addLunch();
      addMove();
    } else if (index > 0) {
      addMove();
    }
    final end = cursor.add(Duration(minutes: dwell));
    items.add(
      PlanItem(
        id: nextId(),
        kind: ItemKind.stay,
        title: place.name,
        placeId: place.id,
        categoryLabel: categoryName(place.category),
        start: cursor,
        end: end,
        unconfirmedFields: _unconfirmed(place),
        warnings: _warnings(place),
        hoursConflict: _hoursConflict(place),
        dwellIsProposal: true,
      ),
    );
    cursor = end;
  }
  addLunch();
  if (items.where((item) => item.kind == ItemKind.stay || item.kind == ItemKind.meal).length >= 3) {
    final end = cursor.add(const Duration(minutes: 30));
    items.add(
      PlanItem(
        id: nextId(),
        kind: ItemKind.rest,
        title: '휴식',
        start: cursor,
        end: end,
        note: '연속 방문 뒤에 제안한 휴식입니다.',
      ),
    );
    cursor = end;
  }
  final dinnerStart = DateTime(day.year, day.month, day.day, 18);
  items.add(
    PlanItem(
      id: nextId(),
      kind: ItemKind.meal,
      title: '식사, 장소 미정',
      start: dinnerStart,
      end: DateTime(day.year, day.month, day.day, 19, 30),
      unconfirmedFields: const ['장소', '예약', '메뉴'],
      dwellIsProposal: true,
      note: '저녁 슬롯은 초기 제안이며 현지 관습의 확정이 아닙니다.',
    ),
  );
  return items;
}

String categoryName(PlaceCategory category) {
  switch (category) {
    case PlaceCategory.attraction:
      return '관광지';
    case PlaceCategory.restaurant:
      return '음식점';
    case PlaceCategory.shopping:
      return '쇼핑';
    case PlaceCategory.culture:
      return '문화시설';
  }
}

bool _hoursConflict(Place place) {
  final hours = place.claimsFor('hours');
  return hours.map((claim) => claim.value).toSet().length > 1 || hours.any((claim) => claim.validity == FactValidity.conflicted);
}

List<String> _unconfirmed(Place place) {
  final fields = <String>[];
  final hours = place.claimsFor('hours');
  if (!_hoursConflict(place) && (hours.isEmpty || hours.any((claim) => claim.validity == FactValidity.collected))) {
    fields.add('운영시간');
  }
  if (place.claimsFor('closure').isEmpty) fields.add('휴무');
  return fields;
}

List<ItemWarning> _warnings(Place place) {
  final warnings = <ItemWarning>[];
  final hours = place.claimsFor('hours');
  if (_hoursConflict(place)) {
    warnings.add(ItemWarning.hoursConflict);
  } else if (hours.isEmpty || hours.any((claim) => claim.validity == FactValidity.collected)) {
    warnings.add(ItemWarning.hoursUnconfirmed);
  }
  if (place.claimsFor('closure').isEmpty) warnings.add(ItemWarning.closureUnconfirmed);
  return warnings;
}

List<String> _mealFields(Place? place) {
  final fields = <String>[];
  if (place == null) fields.add('장소');
  if (place == null || place.claimsFor('reservation').isEmpty) fields.add('예약');
  if (place == null || place.claimsFor('menu').isEmpty) fields.add('메뉴');
  if (place == null || place.claimsFor('price').isEmpty) fields.add('가격');
  return fields;
}
