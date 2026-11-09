import '../model/models.dart';
import 'propose.dart';
import 'schedule.dart';
import 'trip_rules.dart';

const _mealMinutes = 90;

String? insertPlaceOnDay(Trip trip, Place place, DateTime day, String itemId) {
  final date = dateOnly(day);
  if (!containsDay(trip.start, trip.end, date)) return '여행 기간 밖 날짜입니다.';
  final city = trip.cityOn(date);
  if (city == null) return '이 날짜에 배정된 도시가 없습니다.';
  if (!cityNamesMatchForPlaces(place.cityName, city.name)) {
    return '${city.name}에 있는 날짜에만 넣을 수 있습니다.';
  }
  if (place.suspended) return '운영 중단으로 일정에 넣을 수 없습니다.';
  if (!city.coordinateConfirmed) return '도시 위치를 먼저 확인하세요.';

  var plan = dayFor(trip.activeDays, date);
  if (plan != null && plan.items.any((item) => item.placeId == place.id)) {
    return '이 날짜 일정에 이미 있습니다.';
  }
  plan ??= DayPlan(date: date, items: []);
  if (dayFor(trip.activeDays, date) == null) {
    trip.activeDays.add(plan);
    trip.activeDays.sort((a, b) => a.date.compareTo(b.date));
  }

  final minutes = place.category == PlaceCategory.restaurant ? _mealMinutes : proposedDwell(place.category);
  var from = preferredStartAfter(plan.items, date);
  if (place.category == PlaceCategory.restaurant && from.hour < 11) {
    from = DateTime(date.year, date.month, date.day, 12);
  }
  final start = fitAround(plan.items, from, minutes);
  final end = start.add(Duration(minutes: minutes));
  plan.items.add(planItemForPlace(id: itemId, place: place, start: start, end: end, locked: true));
  _sortTimed(plan);
  return null;
}

void _sortTimed(DayPlan plan) {
  final timed = plan.items.where((item) => item.start != null).toList()..sort((a, b) => a.start!.compareTo(b.start!));
  final untimed = plan.items.where((item) => item.start == null).toList();
  plan.items = [...untimed, ...timed];
}
