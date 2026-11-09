import '../format.dart';
import '../model/models.dart';

const visitKinds = {ItemKind.stay, ItemKind.meal};

DayPlan? dayFor(List<DayPlan> days, DateTime day) {
  for (final plan in days) {
    if (sameDay(plan.date, day)) return plan;
  }
  return null;
}

PlanItem? nextVisit(List<PlanItem> items, DateTime now) {
  for (final item in items) {
    if (!visitKinds.contains(item.kind)) continue;
    if (item.end == null || now.isBefore(item.end!)) return item;
  }
  return null;
}

PlanItem? previousVisit(List<PlanItem> items, DateTime now) {
  PlanItem? last;
  for (final item in items) {
    if (!visitKinds.contains(item.kind)) continue;
    if (item.end != null && !now.isBefore(item.end!)) last = item;
  }
  return last;
}

List<PlanItem> remainingAfter(List<PlanItem> items, PlanItem next) {
  final index = items.indexWhere((item) => item.id == next.id);
  if (index < 0 || index + 1 >= items.length) return const [];
  return items.sublist(index + 1);
}

bool isOngoing(Trip trip, DateTime now) {
  if (trip.status == TripStatus.completed || trip.status == TripStatus.archived) return false;
  return trip.status == TripStatus.active;
}

bool isPast(Trip trip, DateTime now) {
  if (trip.status == TripStatus.completed || trip.status == TripStatus.archived) return true;
  return dateOnly(trip.end).isBefore(dateOnly(now)) && trip.status != TripStatus.active;
}

String nextScheduleLine(Trip trip, DateTime now) {
  if (trip.status == TripStatus.completed || trip.status == TripStatus.archived) return '끝난 여행';
  if (dateOnly(trip.end).isBefore(dateOnly(now)) && trip.status != TripStatus.active) return '끝난 여행';
  if (trip.activeDays.isEmpty) return '적용된 일정 없음';
  final today = dayFor(trip.activeDays, now);
  if (today != null) {
    final next = nextVisit(today.items, now);
    if (next == null) return '오늘 남은 방문이 없습니다';
    final clock = next.start == null ? '' : '${formatHm(next.start!)} ';
    return '다음 일정 $clock${next.title}';
  }
  for (final day in trip.activeDays) {
    if (dateOnly(day.date).isBefore(dateOnly(now))) continue;
    final next = nextVisit(day.items, DateTime(day.date.year, day.date.month, day.date.day));
    if (next == null) continue;
    return '다음 일정 ${day.date.month}.${day.date.day} ${next.title}';
  }
  return '적용된 일정 없음';
}

List<DateTime> tripDays(Trip trip) {
  final days = <DateTime>[];
  var day = dateOnly(trip.start);
  final last = dateOnly(trip.end);
  while (!day.isAfter(last)) {
    days.add(day);
    day = day.add(const Duration(days: 1));
  }
  return days;
}

PlanItem? nextDestination(Trip trip, DateTime now) {
  if (trip.activeDays.isEmpty) return null;
  final today = dayFor(trip.activeDays, now);
  if (today == null) return null;
  return nextVisit(today.items, now);
}
