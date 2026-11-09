import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import '../logic/propose.dart';
import '../model/models.dart';

const tripSnapshotVersion = 2;

class TripSnapshot {
  const TripSnapshot({
    required this.trips,
    required this.currentTripId,
    required this.nextSeq,
    this.journal = const {},
    this.exclusions = const {},
    this.userPlaces = const [],
  });

  final List<Trip> trips;
  final String? currentTripId;
  final int nextSeq;
  final Map<String, Map<String, String>> journal;
  final Map<String, ProposalExclusions> exclusions;
  final List<Place> userPlaces;
}

class TripStoreCorruptException implements Exception {
  const TripStoreCorruptException(this.cause, {this.backupPath});

  final Object cause;
  final String? backupPath;

  @override
  String toString() => 'TripStoreCorruptException($cause, backup: $backupPath)';
}

abstract class TripStore {
  Future<TripSnapshot?> read();

  Future<void> write(String encoded);
}

class FileTripStore implements TripStore {
  FileTripStore(this.file);

  final File file;

  static Future<FileTripStore> open() async {
    final directory = await getApplicationDocumentsDirectory();
    return FileTripStore(File('${directory.path}/trip_weave_trips.json'));
  }

  File get corruptCopy => File('${file.path}.corrupt');

  /// A file that cannot be read or parsed is moved aside to [corruptCopy] so the
  /// next save does not overwrite the only copy of the user's data.
  @override
  Future<TripSnapshot?> read() async {
    if (!file.existsSync()) return null;
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return decodeTripSnapshot(text);
    } on Object catch (error) {
      try {
        if (file.existsSync()) await file.rename(corruptCopy.path);
      } on Object {
        // Leave the file in place; the next write replaces it.
      }
      throw TripStoreCorruptException(error, backupPath: corruptCopy.existsSync() ? corruptCopy.path : null);
    }
  }

  @override
  Future<void> write(String encoded) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(file.path);
  }
}

String encodeTripSnapshot(TripSnapshot snapshot) {
  return jsonEncode({
    'version': tripSnapshotVersion,
    'currentTripId': snapshot.currentTripId,
    'nextSeq': snapshot.nextSeq,
    'trips': snapshot.trips.map(_tripToJson).toList(),
    'journal': snapshot.journal,
    'exclusions': snapshot.exclusions.map(
      (tripId, exclusions) => MapEntry(tripId, {
        'itemIds': exclusions.itemIds.toList(),
        'placeIds': exclusions.placeIds.toList(),
        'slots': exclusions.slots.toList(),
      }),
    ),
    if (snapshot.userPlaces.isNotEmpty) 'userPlaces': snapshot.userPlaces.map(_placeToJson).toList(),
  });
}

/// Throws [FormatException] when [encoded] is not a trip snapshot at all.
/// Individual trips with no id or unreadable dates are dropped; the rest load.
TripSnapshot decodeTripSnapshot(String encoded) {
  final raw = jsonDecode(encoded);
  if (raw is! Map || raw['trips'] is! List) {
    throw const FormatException('trip snapshot has no trip list');
  }
  final trips = <Trip>[];
  final ids = <String>{};
  for (final item in raw['trips'] as List) {
    if (item is! Map) continue;
    final trip = _tripFromJson(item);
    if (trip == null || !ids.add(trip.id)) continue;
    trips.add(trip);
  }
  final seq = raw['nextSeq'];
  final current = raw['currentTripId'];
  final version = raw['version'] is int ? raw['version'] as int : 1;
  final userPlaces = <Place>[];
  final placeList = raw['userPlaces'];
  if (placeList is List) {
    for (final item in placeList) {
      if (item is Map) userPlaces.add(_placeFromJson(item));
    }
  }
  return TripSnapshot(
    trips: trips,
    currentTripId: current is String && ids.contains(current) ? current : null,
    nextSeq: math.max(seq is int ? seq : 100, _seqAfter(trips)),
    journal: version >= 2 ? _journalFromJson(raw['journal']) : const {},
    exclusions: version >= 2 ? _exclusionsFromJson(raw['exclusions']) : const {},
    userPlaces: userPlaces,
  );
}

Map<String, Object?> _placeToJson(Place place) {
  return {
    'id': place.id,
    'name': place.name,
    'localName': place.localName,
    'category': place.category.name,
    'cityName': place.cityName,
    'dataOriginMock': place.dataOriginMock,
    'aiOrderSentence': place.aiOrderSentence,
    'claims': place.claims.map(_claimToJson).toList(),
  };
}

Place _placeFromJson(Map raw) {
  final claims = <Claim>[];
  final claimList = raw['claims'];
  if (claimList is List) {
    for (final item in claimList) {
      if (item is Map) claims.add(_claimFromJson(item));
    }
  }
  return Place(
    id: '${raw['id']}',
    name: '${raw['name'] ?? ''}',
    localName: raw['localName'] as String?,
    category: _enum(PlaceCategory.values, raw['category'], PlaceCategory.attraction),
    cityName: '${raw['cityName'] ?? ''}',
    dataOriginMock: raw['dataOriginMock'] == true,
    aiOrderSentence: raw['aiOrderSentence'] as String?,
    claims: claims,
  );
}

Map<String, Object?> _claimToJson(Claim claim) {
  return {
    'field': claim.field,
    'value': claim.value,
    'validity': claim.validity.name,
    'sourceName': claim.sourceName,
    'sourceKind': claim.sourceKind.name,
    'sourceUrl': claim.sourceUrl,
    'collectedAt': claim.collectedAt?.toIso8601String(),
    'verifiedAt': claim.verifiedAt?.toIso8601String(),
  };
}

Claim _claimFromJson(Map raw) {
  return Claim(
    field: '${raw['field'] ?? ''}',
    value: raw['value'] as String?,
    validity: _enum(FactValidity.values, raw['validity'], FactValidity.unknown),
    sourceName: '${raw['sourceName'] ?? ''}',
    sourceKind: _enum(SourceKind.values, raw['sourceKind'], SourceKind.user),
    sourceUrl: raw['sourceUrl'] as String?,
    collectedAt: _date(raw['collectedAt']),
    verifiedAt: _date(raw['verifiedAt']),
  );
}

/// Smallest sequence number that cannot collide with ids already on disk.
int _seqAfter(List<Trip> trips) {
  var next = 100;
  void see(String id) {
    final match = RegExp(r'-(\d+)$').firstMatch(id);
    final value = match == null ? null : int.tryParse(match.group(1)!);
    if (value != null && value >= next) next = value + 1;
  }

  for (final trip in trips) {
    see(trip.id);
    for (final city in trip.cities) {
      see(city.id);
    }
  }
  return next;
}

Map<String, Map<String, String>> _journalFromJson(Object? raw) {
  final result = <String, Map<String, String>>{};
  if (raw is! Map) return result;
  for (final trip in raw.entries) {
    final days = trip.value;
    if (days is! Map) continue;
    final notes = <String, String>{
      for (final day in days.entries)
        if (day.value is String && (day.value as String).isNotEmpty) '${day.key}': day.value as String,
    };
    if (notes.isNotEmpty) result['${trip.key}'] = notes;
  }
  return result;
}

Map<String, ProposalExclusions> _exclusionsFromJson(Object? raw) {
  final result = <String, ProposalExclusions>{};
  if (raw is! Map) return result;
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final exclusions = ProposalExclusions(
      itemIds: _strings(value['itemIds']).toSet(),
      placeIds: _strings(value['placeIds']).toSet(),
      slots: _strings(value['slots']).toSet(),
    );
    if (!exclusions.isEmpty) result['${entry.key}'] = exclusions;
  }
  return result;
}

Map<String, Object?> _tripToJson(Trip trip) {
  return {
    'id': trip.id,
    'title': trip.title,
    'countryCode': trip.countryCode,
    'countryName': trip.countryName,
    'start': trip.start.toIso8601String(),
    'end': trip.end.toIso8601String(),
    'status': trip.status.name,
    'purpose': trip.purpose,
    'tasteTags': trip.tasteTags,
    'budgetAmount': trip.budgetAmount,
    'budgetCurrency': trip.budgetCurrency,
    'companionCount': trip.companionCount,
    'pendingLocalEdits': trip.pendingLocalEdits,
    'dataOriginMock': trip.dataOriginMock,
    'weatherSkipped': trip.weatherSkipped,
    'cities': trip.cities.map(_cityToJson).toList(),
    'links': trip.links.map((id, link) => MapEntry(id, _linkToJson(link))),
    'activeDays': trip.activeDays.map(_dayToJson).toList(),
    'proposalDays': trip.proposalDays?.map(_dayToJson).toList(),
  };
}

Trip? _tripFromJson(Map raw) {
  final id = raw['id'];
  var start = _date(raw['start']);
  var end = _date(raw['end']);
  if (id is! String || id.isEmpty || start == null || end == null) return null;
  if (end.isBefore(start)) (start, end) = (end, start);
  final tripStart = start;
  final tripEnd = end;
  final links = <String, TripPlaceLink>{};
  final linkRaw = raw['links'];
  if (linkRaw is Map) {
    for (final entry in linkRaw.entries) {
      if (entry.value is Map) links['${entry.key}'] = _linkFromJson(entry.value as Map);
    }
  }
  return Trip(
    id: id,
    title: '${raw['title'] ?? ''}',
    countryCode: '${raw['countryCode'] ?? ''}',
    countryName: '${raw['countryName'] ?? ''}',
    start: tripStart,
    end: tripEnd,
    status: _enum(TripStatus.values, raw['status'], TripStatus.draft),
    purpose: '${raw['purpose'] ?? ''}',
    tasteTags: _strings(raw['tasteTags']),
    budgetAmount: raw['budgetAmount'] is int ? raw['budgetAmount'] as int : null,
    budgetCurrency: _text(raw['budgetCurrency']),
    companionCount: raw['companionCount'] is int ? raw['companionCount'] as int : 0,
    pendingLocalEdits: raw['pendingLocalEdits'] is int ? raw['pendingLocalEdits'] as int : 0,
    dataOriginMock: raw['dataOriginMock'] == true,
    weatherSkipped: raw['weatherSkipped'] == true,
    cities: _maps(raw['cities']).map((city) => _cityFromJson(city, tripStart, tripEnd)).toList(),
    links: links,
    activeDays: _days(raw['activeDays']),
    proposalDays: raw['proposalDays'] == null ? null : _days(raw['proposalDays']),
  );
}

List<DayPlan> _days(Object? raw) {
  return [
    for (final day in _maps(raw))
      if (_date(day['date']) != null) _dayFromJson(day),
  ];
}

Map<String, Object?> _cityToJson(City city) {
  return {
    'id': city.id,
    'name': city.name,
    'countryCode': city.countryCode,
    'start': city.start.toIso8601String(),
    'end': city.end.toIso8601String(),
    'sortOrder': city.sortOrder,
    'coordinateConfirmed': city.coordinateConfirmed,
    'coordinateLabel': city.coordinateLabel,
    'coordinateSource': city.coordinateSource,
    if (city.coordinateCandidateId != null) 'coordinateCandidateId': city.coordinateCandidateId,
  };
}

City _cityFromJson(Map raw, DateTime tripStart, DateTime tripEnd) {
  return City(
    id: '${raw['id']}',
    name: '${raw['name'] ?? ''}',
    countryCode: '${raw['countryCode'] ?? ''}',
    start: _date(raw['start']) ?? tripStart,
    end: _date(raw['end']) ?? tripEnd,
    sortOrder: raw['sortOrder'] is int ? raw['sortOrder'] as int : 0,
    coordinateConfirmed: raw['coordinateConfirmed'] == true,
    coordinateLabel: _text(raw['coordinateLabel']),
    coordinateSource: _text(raw['coordinateSource']),
    coordinateCandidateId: _text(raw['coordinateCandidateId']),
  );
}

Map<String, Object?> _linkToJson(TripPlaceLink link) {
  return {'decision': link.decision.name, 'saved': link.saved};
}

TripPlaceLink _linkFromJson(Map raw) {
  return TripPlaceLink(decision: _enum(Decision.values, raw['decision'], Decision.none), saved: raw['saved'] == true);
}

Map<String, Object?> _dayToJson(DayPlan day) {
  return {'date': day.date.toIso8601String(), 'items': day.items.map(_itemToJson).toList()};
}

DayPlan _dayFromJson(Map raw) {
  return DayPlan(date: _date(raw['date'])!, items: _maps(raw['items']).map(_itemFromJson).toList());
}

Map<String, Object?> _itemToJson(PlanItem item) {
  return {
    'id': item.id,
    'kind': item.kind.name,
    'title': item.title,
    'placeId': item.placeId,
    'start': item.start?.toIso8601String(),
    'end': item.end?.toIso8601String(),
    'categoryLabel': item.categoryLabel,
    'unconfirmedFields': item.unconfirmedFields,
    'warnings': item.warnings.map((warning) => warning.name).toList(),
    'locked': item.locked,
    'hoursConflict': item.hoursConflict,
    'dwellIsProposal': item.dwellIsProposal,
    'note': item.note,
  };
}

PlanItem _itemFromJson(Map raw) {
  return PlanItem(
    id: '${raw['id']}',
    kind: _enum(ItemKind.values, raw['kind'], ItemKind.gap),
    title: '${raw['title'] ?? ''}',
    placeId: _text(raw['placeId']),
    start: _date(raw['start']),
    end: _date(raw['end']),
    categoryLabel: _text(raw['categoryLabel']),
    unconfirmedFields: _strings(raw['unconfirmedFields']),
    warnings: [
      for (final name in _strings(raw['warnings']))
        if (ItemWarning.values.any((value) => value.name == name)) _enum(ItemWarning.values, name, ItemWarning.hoursUnconfirmed),
    ],
    locked: raw['locked'] == true,
    hoursConflict: raw['hoursConflict'] == true,
    dwellIsProposal: raw['dwellIsProposal'] == true,
    note: _text(raw['note']),
  );
}

List<Map> _maps(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().toList();
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((item) => '$item').toList();
}

DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String? _text(Object? raw) => raw is String ? raw : null;
