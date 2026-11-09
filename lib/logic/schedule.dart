import '../format.dart';
import '../model/models.dart';

const visitKinds = {ItemKind.stay, ItemKind.meal};

DayPlan? dayFor(List<DayPlan> days, DateTime day) {
  for (final plan in days) {
    if (sameDay(plan.date, day)) return plan;
  }
  return null;
}

bool visitEnded(PlanItem item, DateTime now, Set<String> doneIds) {
  if (doneIds.contains(item.id)) return true;
  return item.end != null && !now.isBefore(item.end!);
}

PlanItem? nextVisit(List<PlanItem> items, DateTime now, {Set<String> doneIds = const {}}) {
  for (final item in items) {
    if (!visitKinds.contains(item.kind)) continue;
    if (!visitEnded(item, now, doneIds)) return item;
  }
  return null;
}

PlanItem? previousVisit(List<PlanItem> items, DateTime now, {Set<String> doneIds = const {}}) {
  PlanItem? last;
  for (final item in items) {
    if (!visitKinds.contains(item.kind)) continue;
    if (visitEnded(item, now, doneIds)) last = item;
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
    final next = nextVisit(today.items, now, doneIds: trip.visitDoneIds);
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
  return nextVisit(today.items, now, doneIds: trip.visitDoneIds);
}

/// The first visit on a day after [now]'s date, for when today has nothing left.
({DayPlan day, PlanItem item})? laterVisit(Trip trip, DateTime now) {
  final days = [...trip.activeDays]..sort((a, b) => a.date.compareTo(b.date));
  for (final day in days) {
    if (!dateOnly(day.date).isAfter(dateOnly(now))) continue;
    for (final item in day.items) {
      if (visitKinds.contains(item.kind)) return (day: day, item: item);
    }
  }
  return null;
}

({int done, int total}) visitProgress(List<PlanItem> items, DateTime now, {Set<String> doneIds = const {}}) {
  var done = 0;
  var total = 0;
  for (final item in items) {
    if (!visitKinds.contains(item.kind)) continue;
    total += 1;
    if (visitEnded(item, now, doneIds)) done += 1;
  }
  return (done: done, total: total);
}

DateTime pinEnd(PlanItem item) => item.end ?? item.start!.add(const Duration(minutes: 30));

bool overlapsInTime(PlanItem a, PlanItem b) {
  if (a.start == null || b.start == null) return false;
  return a.start!.isBefore(pinEnd(b)) && b.start!.isBefore(pinEnd(a));
}

List<PlanItem> pinnedOn(List<DayPlan> days, DateTime day) {
  final plan = dayFor(days, day);
  if (plan == null) return const [];
  return plan.items.where((item) => item.locked).toList();
}

/// Pinned items from [sources], cloned per day. Earlier sources win: a later
/// pin is dropped when it repeats an id or place, or overlaps a kept pin.
List<DayPlan> mergePins(List<List<DayPlan>> sources) {
  final byDate = <DateTime, List<PlanItem>>{};
  for (final days in sources) {
    for (final day in days) {
      final kept = byDate.putIfAbsent(dateOnly(day.date), () => <PlanItem>[]);
      final fromEarlier = List<PlanItem>.of(kept);
      for (final item in day.items) {
        if (!item.locked) continue;
        final clash = fromEarlier.any(
          (other) => other.id == item.id || (item.placeId != null && other.placeId == item.placeId) || overlapsInTime(other, item),
        );
        if (!clash) kept.add(item.clone());
      }
    }
  }
  final dates = byDate.keys.toList()..sort();
  return [for (final date in dates) if (byDate[date]!.isNotEmpty) DayPlan(date: date, items: byDate[date]!)];
}

class ProposalSummary {
  const ProposalSummary({required this.days, required this.visits, required this.pinned, required this.emptyDays});

  final int days;
  final int visits;
  final int pinned;
  final int emptyDays;

  String get line {
    final parts = ['$days일', '방문 $visits곳'];
    if (pinned > 0) parts.add('고정 $pinned개 유지');
    return parts.join(' · ');
  }
}

ProposalSummary summarizeProposal(List<DayPlan> days) {
  var visits = 0;
  var pinned = 0;
  var emptyDays = 0;
  for (final day in days) {
    final stays = day.items.where((item) => item.kind == ItemKind.stay).length;
    visits += stays;
    pinned += day.items.where((item) => item.locked).length;
    if (stays == 0) emptyDays += 1;
  }
  return ProposalSummary(days: days.length, visits: visits, pinned: pinned, emptyDays: emptyDays);
}

/// Items other than moves, and how many of them are pinned, for a date chip.
({int items, int pinned}) dayCounts(DayPlan? day) {
  if (day == null) return (items: 0, pinned: 0);
  final items = day.items.where((item) => item.kind != ItemKind.move).toList();
  return (items: items.length, pinned: items.where((item) => item.locked).length);
}
