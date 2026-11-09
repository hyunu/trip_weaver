import '../model/models.dart';
import 'schedule.dart';

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

const _moveMinutes = 15;
const _mealMinutes = 90;

/// Builds a fresh proposal. Items pinned in [pinnedFrom] stay on their date at
/// their time; generated items are fitted around them and their places are
/// not proposed again. Selected places are spread over the city's days
/// instead of repeating on every day.
List<DayPlan>? proposeItinerary(Trip trip, List<Place> places, {List<DayPlan> pinnedFrom = const []}) {
  if (trip.cities.isEmpty) return null;
  final dates = tripDays(trip);
  final pinsByDate = {for (final date in dates) date: pinnedOn(pinnedFrom, date).map((item) => item.clone()).toList()};
  final pinnedPlaceIds = {
    for (final pins in pinsByDate.values)
      for (final pin in pins)
        if (pin.placeId != null) pin.placeId!,
  };
  final usedIds = {for (final pins in pinsByDate.values) for (final pin in pins) pin.id};
  var seq = 0;
  String nextId(DateTime day) {
    String id;
    do {
      id = 'gen-${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}-${seq++}';
    } while (usedIds.contains(id));
    usedIds.add(id);
    return id;
  }

  final visitsByDate = <DateTime, List<Place>>{};
  final restaurantByDate = <DateTime, Place?>{};
  for (final city in trip.cities) {
    final cityDates = dates.where((date) => trip.cityOn(date)?.id == city.id).toList();
    if (cityDates.isEmpty) continue;
    final selected = _selectedIn(trip, places, city).where((place) => !pinnedPlaceIds.contains(place.id)).toList();
    final visits = selected.where((place) => place.category != PlaceCategory.restaurant).toList();
    final restaurants = selected.where((place) => place.category == PlaceCategory.restaurant).toList();
    final perDay = (visits.length / cityDates.length).ceil();
    for (var index = 0; index < cityDates.length; index++) {
      final from = (index * perDay).clamp(0, visits.length);
      final to = ((index + 1) * perDay).clamp(0, visits.length);
      visitsByDate[cityDates[index]] = visits.sublist(from, to);
      restaurantByDate[cityDates[index]] = restaurants.isEmpty ? null : restaurants[index % restaurants.length];
    }
  }

  return [
    for (final date in dates)
      DayPlan(
        date: date,
        items: _DayBuilder(
          day: date,
          pins: pinsByDate[date]!,
          nextId: () => nextId(date),
        ).build(trip.cityOn(date), visitsByDate[date] ?? const [], restaurantByDate[date]),
      ),
  ];
}

List<Place> _selectedIn(Trip trip, List<Place> places, City city) {
  final selected = <Place>[];
  for (final place in places) {
    if (place.cityName != city.name) continue;
    final link = trip.links[place.id];
    if (link == null || link.decision != Decision.selected) continue;
    if (place.suspended) continue;
    selected.add(place);
  }
  return selected;
}

class _DayBuilder {
  _DayBuilder({required this.day, required this.pins, required this.nextId}) : cursor = DateTime(day.year, day.month, day.day, 9);

  final DateTime day;
  final List<PlanItem> pins;
  final String Function() nextId;
  final generated = <PlanItem>[];
  DateTime cursor;

  DateTime at(int hour, [int minute = 0]) => DateTime(day.year, day.month, day.day, hour, minute);

  List<PlanItem> build(City? city, List<Place> visits, Place? restaurant) {
    if (city == null) {
      generated.add(
        PlanItem(
          id: nextId(),
          kind: ItemKind.gap,
          title: '이 날짜의 도시가 지정되지 않았습니다',
          start: at(9),
          unconfirmedFields: const ['도시'],
          warnings: const [ItemWarning.cityUnassigned],
        ),
      );
      return _merged();
    }
    if (!city.coordinateConfirmed) {
      if (!_pinnedMeal(lunch: true)) {
        final start = _fit(at(12), _mealMinutes);
        generated.add(
          PlanItem(
            id: nextId(),
            kind: ItemKind.meal,
            title: '식사, 장소 미정',
            start: start,
            end: start.add(const Duration(minutes: _mealMinutes)),
            unconfirmedFields: const ['장소', '예약', '메뉴'],
            dwellIsProposal: true,
            note: '도시 위치가 확인되지 않았습니다.',
          ),
        );
      }
      return _merged();
    }

    var lunchPlaced = _pinnedMeal(lunch: true);
    void addLunch() {
      if (lunchPlaced) return;
      lunchPlaced = true;
      final from = cursor.isBefore(at(12)) ? at(12) : cursor;
      _place(
        minutes: _mealMinutes,
        from: from,
        travel: restaurant != null,
        build: (start, end) => PlanItem(
          id: nextId(),
          kind: ItemKind.meal,
          title: restaurant?.name ?? '식사, 장소 미정',
          placeId: restaurant?.id,
          categoryLabel: '음식점',
          start: start,
          end: end,
          unconfirmedFields: _mealFields(restaurant),
          dwellIsProposal: true,
          note: '식사 시각은 초기 제안이며 현지 관습의 확정이 아닙니다.',
        ),
      );
    }

    for (final place in visits) {
      final dwell = proposedDwell(place.category);
      if (!lunchPlaced && cursor.hour >= 11 && cursor.add(Duration(minutes: dwell)).isAfter(at(12))) addLunch();
      _place(
        minutes: dwell,
        from: cursor,
        travel: true,
        build: (start, end) => PlanItem(
          id: nextId(),
          kind: ItemKind.stay,
          title: place.name,
          placeId: place.id,
          categoryLabel: categoryName(place.category),
          start: start,
          end: end,
          unconfirmedFields: _unconfirmed(place),
          warnings: _warnings(place),
          hoursConflict: _hoursConflict(place),
          dwellIsProposal: true,
        ),
      );
    }
    addLunch();

    final busy = [...generated, ...pins].where((item) => visitKinds.contains(item.kind) && item.start != null && !item.start!.isAfter(cursor)).length;
    if (busy >= 3) {
      _place(
        minutes: 30,
        from: cursor,
        travel: false,
        build: (start, end) => PlanItem(
          id: nextId(),
          kind: ItemKind.rest,
          title: '휴식',
          start: start,
          end: end,
          note: '연속 방문 뒤에 제안한 휴식입니다.',
        ),
      );
    }
    if (!_pinnedMeal(lunch: false)) {
      _place(
        minutes: _mealMinutes,
        from: cursor.isAfter(at(18)) ? cursor : at(18),
        travel: false,
        build: (start, end) => PlanItem(
          id: nextId(),
          kind: ItemKind.meal,
          title: '식사, 장소 미정',
          start: start,
          end: end,
          unconfirmedFields: const ['장소', '예약', '메뉴'],
          dwellIsProposal: true,
          note: '저녁 슬롯은 초기 제안이며 현지 관습의 확정이 아닙니다.',
        ),
      );
    }
    return _merged();
  }

  bool _pinnedMeal({required bool lunch}) {
    return pins.any((pin) => pin.kind == ItemKind.meal && pin.start != null && (lunch ? pin.start!.hour < 16 : pin.start!.hour >= 16));
  }

  /// Earliest start at or after [from] where [minutes] fits between pins.
  DateTime _fit(DateTime from, int minutes) {
    var start = from;
    var moved = true;
    while (moved) {
      moved = false;
      for (final pin in pins) {
        if (pin.start == null) continue;
        final end = start.add(Duration(minutes: minutes));
        if (start.isBefore(pinEnd(pin)) && end.isAfter(pin.start!)) {
          start = pinEnd(pin);
          moved = true;
        }
      }
    }
    return start;
  }

  void _place({required int minutes, required DateTime from, required bool travel, required PlanItem Function(DateTime start, DateTime end) build}) {
    var start = _fit(from, minutes);
    final hasPrevious = generated.isNotEmpty || pins.any((pin) => pin.start != null && !pin.start!.isAfter(start));
    if (travel && hasPrevious) {
      final moveStart = _fit(from, _moveMinutes + minutes);
      start = moveStart.add(const Duration(minutes: _moveMinutes));
      generated.add(
        PlanItem(
          id: nextId(),
          kind: ItemKind.move,
          title: '',
          start: moveStart,
          end: start,
          unconfirmedFields: const ['경로'],
          warnings: const [ItemWarning.estimatedGeometry],
        ),
      );
    }
    final end = start.add(Duration(minutes: minutes));
    generated.add(build(start, end));
    cursor = end;
  }

  List<PlanItem> _merged() {
    final timed = [...pins.where((pin) => pin.start != null), ...generated];
    final order = {for (var index = 0; index < timed.length; index++) timed[index]: index};
    timed.sort((a, b) {
      final byStart = a.start!.compareTo(b.start!);
      return byStart != 0 ? byStart : order[a]!.compareTo(order[b]!);
    });
    return [...pins.where((pin) => pin.start == null), ...timed];
  }
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
