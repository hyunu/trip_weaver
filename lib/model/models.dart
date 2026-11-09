enum FactValidity { corroborated, collected, conflicted, stale, suspended, unknown }

enum SourceKind { official, review, user }

enum PlaceCategory { attraction, restaurant, shopping, culture }

enum Decision { none, selected, excluded }

enum TripStatus { draft, active, completed, archived }

enum ItemKind { move, stay, meal, rest, gap }

enum ItemWarning {
  hoursUnconfirmed,
  closureUnconfirmed,
  hoursConflict,
  outsideHours,
  cityUnassigned,
  estimatedGeometry,
  noReplacement,
  weatherUnavailable,
}

class Claim {
  Claim({
    required this.field,
    required this.value,
    required this.validity,
    required this.sourceName,
    required this.sourceKind,
    this.sourceUrl,
    this.collectedAt,
    this.verifiedAt,
  });

  final String field;
  final String? value;
  final FactValidity validity;
  final String sourceName;
  final SourceKind sourceKind;
  final String? sourceUrl;
  final DateTime? collectedAt;
  final DateTime? verifiedAt;
}

class Place {
  Place({
    required this.id,
    required this.name,
    required this.category,
    required this.cityName,
    required this.claims,
    this.localName,
    this.dataOriginMock = true,
    this.aiOrderSentence,
  });

  final String id;
  final String name;
  final String? localName;
  final PlaceCategory category;
  final String cityName;
  final bool dataOriginMock;
  final List<Claim> claims;
  final String? aiOrderSentence;

  bool get suspended => claims.any((claim) => claim.validity == FactValidity.suspended);

  List<Claim> claimsFor(String field) => claims.where((claim) => claim.field == field).toList();
}

class TripPlaceLink {
  TripPlaceLink({this.decision = Decision.none, this.saved = false});

  Decision decision;
  bool saved;
}

class City {
  City({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.start,
    required this.end,
    required this.sortOrder,
    this.coordinateConfirmed = false,
    this.coordinateLabel,
    this.coordinateSource,
    this.coordinateCandidateId,
  });

  final String id;
  String name;
  String countryCode;
  DateTime start;
  DateTime end;
  int sortOrder;
  bool coordinateConfirmed;
  String? coordinateLabel;
  String? coordinateSource;

  /// Null for sample data and files saved before re-picking existed.
  String? coordinateCandidateId;
}

class GeoCandidate {
  const GeoCandidate({
    required this.id,
    required this.label,
    required this.coordinateLabel,
    required this.sourceName,
    this.cityName,
    this.countryCode,
  });

  final String id;
  final String label;
  final String coordinateLabel;
  final String sourceName;

  /// Short city label when known (e.g. from geocoder).
  final String? cityName;

  /// ISO 3166-1 alpha-2 when known.
  final String? countryCode;
}

class PlanItem {
  PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    this.placeId,
    this.start,
    this.end,
    this.categoryLabel,
    List<String>? unconfirmedFields,
    List<ItemWarning>? warnings,
    this.locked = false,
    this.hoursConflict = false,
    this.dwellIsProposal = false,
    this.note,
  }) : unconfirmedFields = List<String>.unmodifiable(unconfirmedFields ?? const []),
       warnings = List<ItemWarning>.unmodifiable(warnings ?? const []);

  final String id;
  final ItemKind kind;
  final String title;
  final String? placeId;
  DateTime? start;
  DateTime? end;
  final String? categoryLabel;
  final List<String> unconfirmedFields;
  final List<ItemWarning> warnings;
  bool locked;
  final bool hoursConflict;
  final bool dwellIsProposal;
  final String? note;

  PlanItem clone() {
    return PlanItem(
      id: id,
      kind: kind,
      title: title,
      placeId: placeId,
      start: start,
      end: end,
      categoryLabel: categoryLabel,
      unconfirmedFields: unconfirmedFields,
      warnings: warnings,
      locked: locked,
      hoursConflict: hoursConflict,
      dwellIsProposal: dwellIsProposal,
      note: note,
    );
  }
}

class DayPlan {
  DayPlan({required this.date, required List<PlanItem> items}) : items = List<PlanItem>.of(items);

  final DateTime date;
  List<PlanItem> items;

  DayPlan clone() => DayPlan(date: date, items: items.map((item) => item.clone()).toList());
}

class Trip {
  Trip({
    required this.id,
    required this.title,
    required this.countryCode,
    required this.countryName,
    required this.start,
    required this.end,
    required this.status,
    required List<City> cities,
    this.purpose = '',
    List<String>? tasteTags,
    this.budgetAmount,
    this.budgetCurrency,
    this.companionCount = 0,
    this.pendingLocalEdits = 0,
    this.dataOriginMock = false,
    Map<String, TripPlaceLink>? links,
    List<DayPlan>? activeDays,
    List<DayPlan>? proposalDays,
    this.weatherSkipped = false,
    Set<String>? visitDoneIds,
  }) : cities = List<City>.of(cities),
       tasteTags = List<String>.of(tasteTags ?? const []),
       links = links ?? <String, TripPlaceLink>{},
       activeDays = activeDays ?? <DayPlan>[],
       proposalDays = proposalDays,
       visitDoneIds = visitDoneIds ?? <String>{};

  final String id;
  String title;
  String countryCode;
  String countryName;
  DateTime start;
  DateTime end;
  TripStatus status;
  String purpose;
  List<String> tasteTags;
  int? budgetAmount;
  String? budgetCurrency;
  int companionCount;
  int pendingLocalEdits;
  bool dataOriginMock;
  List<City> cities;
  Map<String, TripPlaceLink> links;
  List<DayPlan> activeDays;
  List<DayPlan>? proposalDays;
  bool weatherSkipped;
  final Set<String> visitDoneIds;

  City? cityOn(DateTime day) {
    for (final city in cities) {
      if (containsDay(city.start, city.end, day)) return city;
    }
    return null;
  }
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool containsDay(DateTime start, DateTime end, DateTime day) {
  final value = dateOnly(day);
  return !value.isBefore(dateOnly(start)) && !value.isAfter(dateOnly(end));
}

bool rangesOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  final as = dateOnly(aStart);
  final ae = dateOnly(aEnd);
  final bs = dateOnly(bStart);
  final be = dateOnly(bEnd);
  return !as.isAfter(be) && !bs.isAfter(ae);
}
