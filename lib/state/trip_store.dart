import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/models.dart';

class TripSnapshot {
  const TripSnapshot({required this.trips, required this.currentTripId, required this.nextSeq});

  final List<Trip> trips;
  final String? currentTripId;
  final int nextSeq;
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

  @override
  Future<TripSnapshot?> read() async {
    if (!file.existsSync()) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty) return null;
    return decodeTripSnapshot(text);
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
    'version': 1,
    'currentTripId': snapshot.currentTripId,
    'nextSeq': snapshot.nextSeq,
    'trips': snapshot.trips.map(_tripToJson).toList(),
  });
}

TripSnapshot decodeTripSnapshot(String encoded) {
  final raw = jsonDecode(encoded);
  if (raw is! Map) {
    return const TripSnapshot(trips: [], currentTripId: null, nextSeq: 100);
  }
  final trips = <Trip>[];
  final list = raw['trips'];
  if (list is List) {
    for (final item in list) {
      if (item is Map) trips.add(_tripFromJson(item));
    }
  }
  final seq = raw['nextSeq'];
  return TripSnapshot(
    trips: trips,
    currentTripId: raw['currentTripId'] as String?,
    nextSeq: seq is int ? seq : 100,
  );
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

Trip _tripFromJson(Map raw) {
  final links = <String, TripPlaceLink>{};
  final linkRaw = raw['links'];
  if (linkRaw is Map) {
    for (final entry in linkRaw.entries) {
      if (entry.value is Map) links['${entry.key}'] = _linkFromJson(entry.value as Map);
    }
  }
  return Trip(
    id: '${raw['id']}',
    title: '${raw['title'] ?? ''}',
    countryCode: '${raw['countryCode'] ?? ''}',
    countryName: '${raw['countryName'] ?? ''}',
    start: _date(raw['start']) ?? DateTime(1970),
    end: _date(raw['end']) ?? DateTime(1970),
    status: _enum(TripStatus.values, raw['status'], TripStatus.draft),
    purpose: '${raw['purpose'] ?? ''}',
    tasteTags: _strings(raw['tasteTags']),
    budgetAmount: raw['budgetAmount'] is int ? raw['budgetAmount'] as int : null,
    budgetCurrency: raw['budgetCurrency'] as String?,
    companionCount: raw['companionCount'] is int ? raw['companionCount'] as int : 0,
    pendingLocalEdits: raw['pendingLocalEdits'] is int ? raw['pendingLocalEdits'] as int : 0,
    dataOriginMock: raw['dataOriginMock'] == true,
    weatherSkipped: raw['weatherSkipped'] == true,
    cities: _maps(raw['cities']).map(_cityFromJson).toList(),
    links: links,
    activeDays: _maps(raw['activeDays']).map(_dayFromJson).toList(),
    proposalDays: raw['proposalDays'] == null ? null : _maps(raw['proposalDays']).map(_dayFromJson).toList(),
  );
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

City _cityFromJson(Map raw) {
  return City(
    id: '${raw['id']}',
    name: '${raw['name'] ?? ''}',
    countryCode: '${raw['countryCode'] ?? ''}',
    start: _date(raw['start']) ?? DateTime(1970),
    end: _date(raw['end']) ?? DateTime(1970),
    sortOrder: raw['sortOrder'] is int ? raw['sortOrder'] as int : 0,
    coordinateConfirmed: raw['coordinateConfirmed'] == true,
    coordinateLabel: raw['coordinateLabel'] as String?,
    coordinateSource: raw['coordinateSource'] as String?,
    coordinateCandidateId: raw['coordinateCandidateId'] is String ? raw['coordinateCandidateId'] as String : null,
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
  return DayPlan(date: _date(raw['date']) ?? DateTime(1970), items: _maps(raw['items']).map(_itemFromJson).toList());
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
    placeId: raw['placeId'] as String?,
    start: _date(raw['start']),
    end: _date(raw['end']),
    categoryLabel: raw['categoryLabel'] as String?,
    unconfirmedFields: _strings(raw['unconfirmedFields']),
    warnings: [
      for (final name in _strings(raw['warnings']))
        if (ItemWarning.values.any((value) => value.name == name)) _enum(ItemWarning.values, name, ItemWarning.hoursUnconfirmed),
    ],
    locked: raw['locked'] == true,
    hoursConflict: raw['hoursConflict'] == true,
    dwellIsProposal: raw['dwellIsProposal'] == true,
    note: raw['note'] as String?,
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
  return DateTime.parse(raw);
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
