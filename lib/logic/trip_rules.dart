import '../data/countries.dart';
import '../model/models.dart';

class CityDraft {
  CityDraft({this.name = '', this.countryCode = 'KR', this.start, this.end, this.id});

  /// Existing [City.id] when editing; null for a newly added city row.
  final String? id;

  String name;
  String countryCode;
  DateTime? start;
  DateTime? end;
}

class TripDraft {
  TripDraft({
    this.title = '',
    this.countryCode = 'KR',
    this.start,
    this.end,
    this.purpose = '',
    List<String>? tasteTags,
    this.budgetAmount = '',
    this.budgetCurrency = '',
    this.companionCount = 0,
    List<CityDraft>? cities,
  })  : tasteTags = tasteTags ?? <String>[],
        cities = cities ?? <CityDraft>[];

  factory TripDraft.fromTrip(Trip trip) {
    final cities = List<City>.of(trip.cities)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return TripDraft(
      title: trip.title,
      countryCode: trip.countryCode,
      start: dateOnly(trip.start),
      end: dateOnly(trip.end),
      purpose: trip.purpose,
      tasteTags: List<String>.of(trip.tasteTags),
      budgetAmount: trip.budgetAmount?.toString() ?? '',
      budgetCurrency: trip.budgetCurrency ?? '',
      companionCount: trip.companionCount,
      cities: [
        for (final city in cities)
          CityDraft(id: city.id, name: city.name, countryCode: city.countryCode, start: dateOnly(city.start), end: dateOnly(city.end)),
      ],
    );
  }

  String title;
  String countryCode;
  DateTime? start;
  DateTime? end;
  String purpose;
  List<String> tasteTags;
  String budgetAmount;
  String budgetCurrency;
  int companionCount;
  List<CityDraft> cities;
}

const maxTitleLength = 60;
const maxCityNameLength = 40;
const maxTripDays = 366;

Map<String, String> validateTripDraft(TripDraft draft) {
  final errors = <String, String>{};
  if (draft.title.trim().isEmpty) errors['title'] = '제목을 입력하세요.';
  if (draft.title.trim().length > maxTitleLength) errors['title'] = '제목은 $maxTitleLength자 이하로 입력하세요.';
  final country = draft.countryCode.trim().toUpperCase();
  if (!countryNames.containsKey(country)) errors['country'] = '목록에 없는 국가입니다.';
  if (draft.start == null) errors['start'] = '시작일을 고르세요.';
  if (draft.end == null) errors['end'] = '종료일을 고르세요.';
  if (draft.start != null && draft.end != null && dateOnly(draft.end!).isBefore(dateOnly(draft.start!))) {
    errors['end'] = '종료일은 시작일 이상이어야 합니다.';
  } else if (draft.start != null && draft.end != null && dateOnly(draft.end!).difference(dateOnly(draft.start!)).inDays + 1 > maxTripDays) {
    errors['end'] = '여행 기간은 $maxTripDays일 이하여야 합니다.';
  }
  final amountText = draft.budgetAmount.trim();
  final currency = draft.budgetCurrency.trim();
  int? amount;
  if (amountText.isEmpty != currency.isEmpty) {
    errors['budget'] = '금액과 통화를 함께 입력하세요.';
  } else if (amountText.isNotEmpty) {
    amount = int.tryParse(amountText);
    if (amount == null || amount < 0) errors['budget'] = '금액을 숫자로 입력하세요.';
    if (!currencyCodes.contains(currency)) errors['budget'] = '목록에 없는 통화입니다.';
  }
  if (draft.companionCount < 0) errors['companions'] = '동행 인원은 0 이상입니다.';

  for (var index = 0; index < draft.cities.length; index++) {
    final city = draft.cities[index];
    if (city.name.trim().isEmpty) errors['city-$index-name'] = '도시 이름을 입력하세요.';
    if (city.name.trim().length > maxCityNameLength) errors['city-$index-name'] = '도시 이름은 $maxCityNameLength자 이하로 입력하세요.';
    if (!countryNames.containsKey(city.countryCode.trim().toUpperCase())) {
      errors['city-$index-country'] = '목록에 없는 국가입니다.';
    }
    if (city.start == null || city.end == null) {
      errors['city-$index-dates'] = '도시 날짜를 고르세요.';
    } else if (dateOnly(city.end!).isBefore(dateOnly(city.start!))) {
      errors['city-$index-dates'] = '종료일은 시작일 이상이어야 합니다.';
    } else if (draft.start != null && draft.end != null) {
      final inside = !dateOnly(city.start!).isBefore(dateOnly(draft.start!)) && !dateOnly(city.end!).isAfter(dateOnly(draft.end!));
      if (!inside) errors['city-$index-dates'] = '도시 날짜는 여행 기간 안이어야 합니다.';
    }
  }
  for (var left = 0; left < draft.cities.length; left++) {
    final a = draft.cities[left];
    if (a.start == null || a.end == null) continue;
    for (var right = left + 1; right < draft.cities.length; right++) {
      final b = draft.cities[right];
      if (b.start == null || b.end == null) continue;
      if (rangesOverlap(a.start!, a.end!, b.start!, b.end!)) {
        errors['cities'] = '도시 날짜가 겹칩니다.';
      }
    }
  }
  return errors;
}

/// Days and items that editing [trip] to [draft] would drop from the applied itinerary.
class TripEditImpact {
  const TripEditImpact({required this.days, required this.items, required this.pinned});

  final List<DateTime> days;
  final int items;
  final int pinned;

  bool get isEmpty => items == 0;
}

bool editRemovesDay(Trip trip, TripDraft draft, DateTime day) {
  final start = draft.start;
  final end = draft.end;
  if (start == null || end == null || !containsDay(start, end, day)) return true;
  final kept = {for (final city in draft.cities) if (city.id != null) city.id!};
  return trip.cities.any((city) => !kept.contains(city.id) && containsDay(city.start, city.end, day));
}

TripEditImpact tripEditImpact(Trip trip, TripDraft draft) {
  final days = <DateTime>[];
  var items = 0;
  var pinned = 0;
  for (final day in trip.activeDays) {
    if (day.items.isEmpty || !editRemovesDay(trip, draft, day.date)) continue;
    days.add(dateOnly(day.date));
    items += day.items.length;
    pinned += day.items.where((item) => item.locked).length;
  }
  days.sort();
  return TripEditImpact(days: days, items: items, pinned: pinned);
}
