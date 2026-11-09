import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/countries.dart';
import '../data/sample_catalog.dart';
import '../logic/add_to_schedule.dart';
import '../logic/propose.dart';
import '../format.dart';
import '../logic/schedule.dart';
import '../logic/trip_rules.dart';
import '../logic/city_lookup.dart';
import '../logic/geocoder.dart';
import '../logic/user_place.dart';
import '../map/geo.dart';
import '../model/journal.dart';
import '../model/models.dart';
import 'trip_store.dart';

/// Sample catalog anchor time for tests and capture fixtures.
final DateTime sampleNow = DateTime(2026, 11, 8, 10, 40);

enum SaveStatus { idle, saving, saved, failed }

class TripController extends ChangeNotifier {
  /// In widget tests, pins [now] when no explicit [now] is passed.
  @visibleForTesting
  static DateTime? debugFixedNow;

  TripController({DateTime? now, SampleCatalog? catalog, TripStore? store, CityGeocoder? geocoder, bool? preloadSamples})
    : _explicitNow = now,
      _store = store,
      _bundledCatalog = catalog ?? buildSampleCatalog(),
      geocoder = geocoder ?? OfflineSampleGeocoder() {
    _now = _readNow();
  _seedSampleIds(_bundledCatalog);
    final loadSamples = preloadSamples ?? (store == null || catalog != null);
    if (loadSamples) {
      _installBundledCatalog(_bundledCatalog, markActive: true);
    } else {
      trips = [];
      places = [];
      currentTripId = null;
      onboardingComplete = false;
      bundledSamplesActive = false;
      selectedDate = dateOnly(this.now);
      journalDate = dateOnly(this.now);
      selectedCityId = null;
    }
  }

  final DateTime? _explicitNow;
  final SampleCatalog _bundledCatalog;
  late DateTime _now;
  bool onboardingComplete = true;
  bool bundledSamplesActive = false;

  bool get fixedClock => _explicitNow != null || debugFixedNow != null;

  DateTime get now => _now;

  SaveStatus saveStatus = SaveStatus.idle;
  String? saveError;
  String? restoreNotice;
  String? lastSaveSnack;

  DateTime _readNow() => _explicitNow ?? debugFixedNow ?? DateTime.now();

  void refreshClock() {
    if (fixedClock) return;
    final fresh = DateTime.now();
    if (_sameMinute(fresh, _now)) return;
    _now = fresh;
    super.notifyListeners();
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day && a.hour == b.hour && a.minute == b.minute;

  bool showReferenceClock([Trip? trip]) => fixedClock || (trip?.dataOriginMock ?? false);

  final CityGeocoder geocoder;
  late List<Trip> trips;
  late List<Place> places;
  String? currentTripId;
  String? selectedPlaceId;
  String? selectedItemId;
  String? selectedCityId;
  late DateTime selectedDate;
  late DateTime journalDate;
  int tabIndex = 0;
  bool reviewingProposal = false;
  bool homePushed = false;
  bool explorePushed = false;
  bool itineraryPushed = false;
  bool creating = false;
  String? editingTripId;
  bool editingCity = false;
  bool offline = false;

  void setOffline(bool value) {
    if (offline == value) return;
    offline = value;
    notifyListeners();
  }
  bool itineraryDeferred = false;
  String? itineraryError;
  String? itineraryNotice;
  PlaceCategory? categoryFilter;
  String searchQuery = '';
  final Map<String, String> verificationNotes = {};
  final Map<String, List<GeoCandidate>> cityCandidates = {};
  final Set<String> locatingCityIds = {};
  final Map<String, String> citySearchQueries = {};
  final Set<String> relocatingCityIds = {};
  final Map<String, double> scrollOffsets = {};
  final Map<String, ProposalExclusions> _proposalExclusions = {};
  final JournalBook journal = JournalBook();
  int _seq = 100;
  final TripStore? _store;
  late final Set<String> _sampleTripIds;
  late final Set<String> _samplePlaceIds;
  Future<void> _saveChain = Future<void>.value();

  Future<void> get persistenceSettled => _saveChain;

  Future<void> restore() async {
    final store = _store;
    if (store == null) return;
    try {
      final snapshot = await store.read();
      if (snapshot == null) {
        onboardingComplete = false;
        bundledSamplesActive = false;
        trips = [];
        places = [];
        currentTripId = null;
        selectedCityId = null;
      } else {
        _applySnapshot(snapshot);
      }
    } on TripStoreCorruptException catch (_) {
      restoreNotice = '저장 파일을 읽지 못해 백업해 두었습니다. 샘플 데이터로 다시 시작합니다.';
      _installBundledCatalog(_bundledCatalog, markActive: true);
      onboardingComplete = true;
    } on Object {
      _installBundledCatalog(_bundledCatalog, markActive: true);
      onboardingComplete = true;
    }
    super.notifyListeners();
  }

  void _seedSampleIds(SampleCatalog seed) {
    _samplePlaceIds = {for (final place in seed.places) place.id};
    _sampleTripIds = {
      for (final trip in seed.trips)
        if (trip.dataOriginMock) trip.id
    };
  }

  void _installBundledCatalog(SampleCatalog seed, {required bool markActive}) {
    trips = List<Trip>.of(seed.trips);
    places = List<Place>.of(seed.places);
    currentTripId = seed.currentTripId;
    bundledSamplesActive = markActive;
    selectedDate = dateOnly(now);
    journalDate = dateOnly(now);
    final trip = current;
    if (trip != null && trip.cities.isNotEmpty) {
      selectedCityId = trip.cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => trip.cities.first).id;
    } else {
      selectedCityId = null;
    }
  }

  void _ensureBundledSamplesPresent() {
    final existing = trips.map((trip) => trip.id).toSet();
  final missing = _bundledCatalog.trips.where((trip) => trip.dataOriginMock && !existing.contains(trip.id)).toList();
    if (missing.isEmpty) return;
    trips = [...trips, ...missing];
    for (final place in _bundledCatalog.places) {
      if (places.every((item) => item.id != place.id)) places.add(place);
    }
  }

  void _applySnapshot(TripSnapshot snapshot) {
    for (final trip in snapshot.trips) {
      if (_sampleTripIds.contains(trip.id)) trip.dataOriginMock = true;
    }
    trips = snapshot.trips;
    currentTripId = snapshot.currentTripId;
    onboardingComplete = snapshot.onboardingComplete;
    bundledSamplesActive = snapshot.bundledSamplesActive;
    if (snapshot.nextSeq > _seq) _seq = snapshot.nextSeq;
    journal.replaceAll(snapshot.journal);
    _proposalExclusions
      ..clear()
      ..addAll(snapshot.exclusions);
    mergeUserPlaces(snapshot.userPlaces);
    if (bundledSamplesActive) _ensureBundledSamplesPresent();
    final trip = current;
    if (trip == null || trip.cities.isEmpty) {
      selectedCityId = null;
    } else if (selectedCityId == null || trip.cities.every((city) => city.id != selectedCityId)) {
      selectedCityId = trip.cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => trip.cities.first).id;
    }
  }

  String? _persistedCurrentTripId() {
    if (currentTripId != null) {
      for (final trip in trips) {
        if (trip.id == currentTripId && !trip.dataOriginMock) return currentTripId;
      }
      if (bundledSamplesActive && trips.any((trip) => trip.id == currentTripId && trip.dataOriginMock)) {
        return currentTripId;
      }
    }
    for (final trip in trips) {
      if (!trip.dataOriginMock) return trip.id;
    }
    return null;
  }

  List<Trip> _persistedTrips() {
    final saved = <Trip>[...trips.where((trip) => !trip.dataOriginMock)];
    for (final trip in trips.where((trip) => trip.dataOriginMock)) {
      final relocated = trip.cities.any((city) => city.coordinateCandidateId != null);
      if (relocated) saved.add(trip);
    }
    return saved;
  }

  TripSnapshot _snapshot() => TripSnapshot(
    trips: _persistedTrips(),
    currentTripId: _persistedCurrentTripId(),
    nextSeq: _seq,
    journal: journal.export(),
    exclusions: Map<String, ProposalExclusions>.from(_proposalExclusions),
    userPlaces: _userPlacesForSave(),
    onboardingComplete: onboardingComplete,
    bundledSamplesActive: bundledSamplesActive,
  );

  bool get showOnboarding => !onboardingComplete;

  List<Trip> get userTrips => trips.where((trip) => !trip.dataOriginMock).toList();

  List<Trip> get sampleTrips => trips.where((trip) => trip.dataOriginMock).toList();

  void browseBundledSamples() {
    onboardingComplete = true;
    bundledSamplesActive = true;
    _ensureBundledSamplesPresent();
    if (currentTripId == null || !trips.any((trip) => trip.id == currentTripId)) {
      final sample = sampleTrips;
      if (sample.isNotEmpty) {
        selectTrip(sample.first.id);
      }
    }
    notifyListeners();
  }

  void startOnboardingCreate() {
    onboardingComplete = true;
    openCreate();
  }

  void hideAllSamples() {
    final removing = current?.dataOriginMock ?? false;
    trips.removeWhere((trip) => trip.dataOriginMock);
    bundledSamplesActive = false;
    if (removing) {
      currentTripId = userTrips.isEmpty ? null : userTrips.first.id;
      selectedCityId = null;
      homePushed = false;
    }
    notifyListeners();
  }

  void clearRestoreNotice() {
    restoreNotice = null;
  }

  void clearSaveSnack() {
    lastSaveSnack = null;
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _enqueueSave();
  }

  void _enqueueSave() {
    final store = _store;
    if (store == null) return;
    final encoded = encodeTripSnapshot(_snapshot());
    _saveChain = _saveChain.catchError((Object _) {}).then((_) async {
      try {
        await store.write(encoded);
        saveStatus = SaveStatus.saved;
        saveError = null;
        lastSaveError = null;
      } on Object catch (error) {
        saveStatus = SaveStatus.failed;
        saveError = '$error';
        lastSaveError = error;
        lastSaveSnack = '여행 데이터를 저장하지 못했습니다. 다시 시도해 주세요.';
        super.notifyListeners();
      }
    });
  }

  Future<void> retrySave() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.write(encodeTripSnapshot(_snapshot()));
      saveStatus = SaveStatus.saved;
      saveError = null;
      lastSaveError = null;
      lastSaveSnack = null;
      super.notifyListeners();
    } on Object catch (error) {
      saveStatus = SaveStatus.failed;
      saveError = '$error';
      lastSaveError = error;
      lastSaveSnack = '여행 데이터를 저장하지 못했습니다. 다시 시도해 주세요.';
      super.notifyListeners();
    }
  }

  /// The error from the most recent failed save, cleared by the next successful one.
  Object? lastSaveError;

  Trip? get current {
    for (final trip in trips) {
      if (trip.id == currentTripId) return trip;
    }
    return null;
  }

  Place? placeById(String? id) {
    if (id == null) return null;
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  City? get selectedCity {
    final trip = current;
    if (trip == null || selectedCityId == null) return null;
    for (final city in trip.cities) {
      if (city.id == selectedCityId) return city;
    }
    return null;
  }

  List<DayPlan> visibleDays(Trip trip) {
    if (reviewingProposal && trip.proposalDays != null) return trip.proposalDays!;
    return trip.activeDays;
  }

  DayPlan? visibleDay(Trip trip) => dayFor(visibleDays(trip), planDate(trip));

  /// [selectedDate] when it falls inside [trip], otherwise today or the first day.
  DateTime planDate(Trip trip) {
    if (containsDay(trip.start, trip.end, selectedDate)) return selectedDate;
    return containsDay(trip.start, trip.end, now) ? dateOnly(now) : dateOnly(trip.start);
  }

  PlanItem? destinationFor(Trip trip) => nextDestination(trip, now);

  List<PlanItem> remainingFor(Trip trip) {
    final today = dayFor(trip.activeDays, now);
    final next = destinationFor(trip);
    if (today == null || next == null) return const [];
    return remainingAfter(today.items, next);
  }

  bool get homeShowsSample => sampleTrips.isNotEmpty;

  void mergeUserPlaces(Iterable<Place> saved) {
    for (final place in saved) {
      if (_samplePlaceIds.contains(place.id)) continue;
      final index = places.indexWhere((item) => item.id == place.id);
      if (index >= 0) {
        places[index] = place;
      } else {
        places.add(place);
      }
    }
  }

  List<Place> _userPlacesForSave() => places.where((place) => !_samplePlaceIds.contains(place.id)).toList();

  GeoPoint? cityGeo(City? city) => geoFromLabel(city?.coordinateLabel);

  void saveScroll(String key, double offset) => scrollOffsets[key] = offset;

  double scrollOf(String key) => scrollOffsets[key] ?? 0;

  bool get hasOngoingTrip => trips.any((trip) => isOngoing(trip, now));

  Trip? get firstOngoingTrip {
    for (final trip in trips) {
      if (isOngoing(trip, now)) return trip;
    }
    return null;
  }

  void selectTab(int index) {
    if (index == 3 && !hasOngoingTrip) return;
    if (index == 3) {
      final trip = current;
      if (trip == null || !isOngoing(trip, now)) {
        final ongoing = firstOngoingTrip;
        if (ongoing != null) selectTrip(ongoing.id);
      }
    }
    tabIndex = index;
    notifyListeners();
  }

  void selectTrip(String id) {
    if (id != currentTripId) itineraryNotice = null;
    if (id != editingTripId) editingTripId = null;
    currentTripId = id;
    final trip = current;
    if (trip != null) {
      if (!containsDay(trip.start, trip.end, selectedDate)) {
        selectedDate = containsDay(trip.start, trip.end, now) ? dateOnly(now) : dateOnly(trip.start);
      }
      journalDate = containsDay(trip.start, trip.end, now) ? dateOnly(now) : dateOnly(trip.start);
      if (trip.cities.isEmpty) {
        selectedCityId = null;
      } else if (selectedCityId == null || trip.cities.every((city) => city.id != selectedCityId)) {
        selectedCityId = trip.cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => trip.cities.first).id;
      }
    }
    notifyListeners();
  }

  void openHome(String id) {
    selectTrip(id);
    homePushed = true;
    creating = false;
    notifyListeners();
  }

  void closeHome() {
    homePushed = false;
    notifyListeners();
  }

  void openCreate() {
    creating = true;
    editingTripId = null;
    homePushed = false;
    notifyListeners();
  }

  void openEditTrip(String id) {
    if (trips.every((trip) => trip.id != id)) return;
    if (currentTripId != id) selectTrip(id);
    editingTripId = id;
    creating = false;
    notifyListeners();
  }

  void closeEditTrip() {
    editingTripId = null;
    notifyListeners();
  }

  void closeCreate() {
    creating = false;
    notifyListeners();
  }

  void openPlace(String id, {required bool tablet}) {
    selectedPlaceId = id;
    if (!tablet) explorePushed = true;
    editingCity = false;
    notifyListeners();
  }

  void closeExplore() {
    explorePushed = false;
    notifyListeners();
  }

  void openItem(String id, {required bool tablet}) {
    selectedItemId = id;
    if (!tablet) itineraryPushed = true;
    notifyListeners();
  }

  void closeItinerary() {
    itineraryPushed = false;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    selectedDate = dateOnly(date);
    selectedItemId = null;
    notifyListeners();
  }

  void selectJournalDate(DateTime date) {
    journalDate = dateOnly(date);
    notifyListeners();
  }

  String? journalText([DateTime? day]) {
    final trip = current;
    if (trip == null) return null;
    return journal.text(trip.id, day ?? journalDate);
  }

  void saveJournal(String raw) {
    final trip = current;
    if (trip == null) return;
    if (!journal.save(trip.id, journalDate, raw)) return;
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  void selectCity(String id) {
    selectedCityId = id;
    notifyListeners();
  }

  void setCategory(PlaceCategory? category) {
    categoryFilter = categoryFilter == category ? null : category;
    notifyListeners();
  }

  void setQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  List<Place> visiblePlaces() {
    final city = selectedCity;
    if (city == null || !city.coordinateConfirmed) return const [];
    final query = searchQuery.trim();
    return places.where((place) {
      if (place.cityName != city.name) return false;
      if (categoryFilter != null && place.category != categoryFilter) return false;
      if (query.isEmpty) return true;
      final local = place.localName ?? '';
      return place.name.contains(query) || local.contains(query);
    }).toList();
  }

  void setDecision(String placeId, Decision decision) {
    final trip = current;
    if (trip == null) return;
    final link = trip.links.putIfAbsent(placeId, TripPlaceLink.new);
    link.decision = decision;
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  List<DateTime> scheduledDaysFor(String placeId) {
    final trip = current;
    if (trip == null) return const [];
    return daysWithPlace(trip, placeId);
  }

  /// Puts [placeId] on [day] in the active schedule immediately (locked pin).
  String? addPlaceToSchedule(String placeId, DateTime day) {
    final trip = current;
    final place = placeById(placeId);
    if (trip == null || place == null) return '장소를 찾을 수 없습니다.';
    final error = insertPlaceOnDay(trip, place, day, 'sched-${_seq++}');
    if (error != null) return error;
    final link = trip.links.putIfAbsent(placeId, TripPlaceLink.new);
    if (link.decision == Decision.excluded) link.decision = Decision.none;
    trip.pendingLocalEdits += 1;
    selectedDate = dateOnly(day);
    itineraryNotice = '${day.month}월 ${day.day}일 일정에 ${place.name}을(를) 넣었습니다. 새로 제안받으면 빈 시간을 채웁니다.';
    notifyListeners();
    return null;
  }

  void toggleSaved(String placeId) {
    final trip = current;
    if (trip == null) return;
    final link = trip.links.putIfAbsent(placeId, TripPlaceLink.new);
    link.saved = !link.saved;
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  TripPlaceLink linkFor(String placeId) {
    return current?.links[placeId] ?? TripPlaceLink();
  }

  void markVisitDone(String itemId) {
    final trip = current;
    if (trip == null || trip.visitDoneIds.contains(itemId)) return;
    if (_findItem(itemId) == null) return;
    trip.visitDoneIds.add(itemId);
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  void skipVisit(String itemId) => markVisitDone(itemId);

  void toggleLock(String itemId) {
    final item = _findItem(itemId);
    if (item == null || current == null) return;
    item.locked = !item.locked;
    current!.pendingLocalEdits += 1;
    notifyListeners();
  }

  void deleteItem(String itemId) {
    final trip = current;
    if (trip == null) return;
    final days = reviewingProposal ? trip.proposalDays : trip.activeDays;
    if (days == null) return;
    for (final day in days) {
      if (reviewingProposal) {
        for (final item in day.items.where((item) => item.id == itemId)) {
          _proposalExclusions.putIfAbsent(trip.id, ProposalExclusions.new).record(item, day.date);
        }
      }
      day.items.removeWhere((item) => item.id == itemId);
    }
    if (selectedItemId == itemId) {
      selectedItemId = null;
      itineraryPushed = false;
    }
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  PlanItem? _findItem(String itemId) {
    final trip = current;
    if (trip == null) return null;
    final days = _editableDays(trip);
    if (days == null) return null;
    for (final day in days) {
      for (final item in day.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  List<DayPlan>? _editableDays(Trip trip) => reviewingProposal ? trip.proposalDays : trip.activeDays;

  DayPlan? editableDay() {
    final trip = current;
    if (trip == null) return null;
    final days = _editableDays(trip);
    if (days == null) return null;
    return dayForOrInsert(days, planDate(trip));
  }

  List<Place> placesForSelectedDay({String query = ''}) {
    final trip = current;
    if (trip == null) return const [];
    final city = cityOnDate(trip, planDate(trip));
    if (city == null) return const [];
    final needle = query.trim();
    return places.where((place) {
      if (place.cityName != city.name) return false;
      if (needle.isEmpty) return true;
      final local = place.localName ?? '';
      return place.name.contains(needle) || local.contains(needle);
    }).toList();
  }

  void addItineraryPlace(Place place) {
    final trip = current;
    final day = editableDay();
    if (trip == null || day == null) return;
    final start = suggestInsertStart(day, day.date);
    final kind = kindForPlace(place.category);
    final item = PlanItem(
      id: 'item-${_seq++}',
      kind: kind,
      title: place.name,
      placeId: place.id,
      categoryLabel: categoryLabel(place.category),
      start: start,
      end: start.add(defaultDuration(kind)),
      locked: true,
      dwellIsProposal: false,
    );
    day.items.add(item);
    sortItemsByStart(day);
    trip.pendingLocalEdits += 1;
    itineraryNotice = '일정에 ${place.name}을(를) 넣었습니다.';
    selectedItemId = item.id;
    notifyListeners();
  }

  void addItineraryMemo({required String title, String? note}) {
    final trip = current;
    final day = editableDay();
    if (trip == null || day == null || title.trim().isEmpty) return;
    final start = suggestInsertStart(day, day.date);
    final item = PlanItem(
      id: 'item-${_seq++}',
      kind: ItemKind.rest,
      title: title.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      start: start,
      end: start.add(defaultDuration(ItemKind.rest)),
      locked: true,
      dwellIsProposal: false,
    );
    day.items.add(item);
    sortItemsByStart(day);
    trip.pendingLocalEdits += 1;
    selectedItemId = item.id;
    notifyListeners();
  }

  void addItineraryTransport({required String title, String? note}) {
    final trip = current;
    final day = editableDay();
    if (trip == null || day == null || title.trim().isEmpty) return;
    final start = suggestInsertStart(day, day.date);
    final item = PlanItem(
      id: 'item-${_seq++}',
      kind: ItemKind.move,
      title: title.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      start: start,
      end: start.add(defaultDuration(ItemKind.move)),
      locked: true,
      dwellIsProposal: false,
    );
    day.items.add(item);
    sortItemsByStart(day);
    trip.pendingLocalEdits += 1;
    selectedItemId = item.id;
    notifyListeners();
  }

  void addItineraryLodging({required String title, String? note}) {
    final trip = current;
    final day = editableDay();
    if (trip == null || day == null || title.trim().isEmpty) return;
    final start = suggestInsertStart(day, day.date);
    final item = PlanItem(
      id: 'item-${_seq++}',
      kind: ItemKind.stay,
      title: title.trim(),
      categoryLabel: '숙소',
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      start: start,
      end: start.add(const Duration(hours: 10)),
      locked: true,
      dwellIsProposal: false,
    );
    day.items.add(item);
    sortItemsByStart(day);
    trip.pendingLocalEdits += 1;
    selectedItemId = item.id;
    notifyListeners();
  }

  void reorderItineraryItem(int oldIndex, int newIndex) {
    final trip = current;
    final day = editableDay();
    if (trip == null || day == null) return;
    if (oldIndex < 0 || oldIndex >= day.items.length || newIndex < 0 || newIndex > day.items.length) return;
    reorderDayItems(day, oldIndex, newIndex);
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  void updateItemTime(String itemId, {required DateTime start, required DateTime end}) {
    final trip = current;
    final item = _findItem(itemId);
    final day = editableDay();
    if (trip == null || item == null || day == null || !end.isAfter(start)) return;
    final date = day.date;
    item.start = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    item.end = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    sortItemsByStart(day);
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  /// Items removed from the proposal under review; asking again leaves them out.
  int excludedCount(Trip trip) => _proposalExclusions[trip.id]?.count ?? 0;

  void restoreExcluded() {
    final trip = current;
    if (trip == null || _proposalExclusions.remove(trip.id) == null) return;
    requestItinerary();
  }

  PlanItem? selectedItem() => selectedItemId == null ? null : _findItem(selectedItemId!);

  void openActiveItem(PlanItem item, {required bool tablet}) {
    reviewingProposal = false;
    selectedDate = dateOnly(item.start ?? now);
    selectedItemId = item.id;
    itineraryPushed = !tablet;
    tabIndex = 2;
    notifyListeners();
  }

  void startReview() {
    if (current?.proposalDays == null) return;
    reviewingProposal = true;
    itineraryNotice = null;
    selectedItemId = null;
    itineraryPushed = false;
    notifyListeners();
  }

  void showActive() {
    reviewingProposal = false;
    selectedItemId = null;
    itineraryPushed = false;
    notifyListeners();
  }

  void applyProposal() {
    final trip = current;
    if (trip?.proposalDays == null) return;
    trip!.activeDays = trip.proposalDays!.map((day) => day.clone()).toList();
    trip.proposalDays = null;
    _proposalExclusions.remove(trip.id);
    reviewingProposal = false;
    selectedItemId = null;
    itineraryPushed = false;
    itineraryNotice = '제안을 적용했습니다. 이제 이 일정이 여행 중 화면의 기준입니다.';
    trip.pendingLocalEdits += 1;
    notifyListeners();
  }

  void discardProposal() {
    final trip = current;
    if (trip == null || trip.proposalDays == null) return;
    trip.proposalDays = null;
    _proposalExclusions.remove(trip.id);
    reviewingProposal = false;
    selectedItemId = null;
    itineraryPushed = false;
    itineraryNotice = trip.activeDays.isEmpty ? '제안을 버렸습니다.' : '제안을 버렸습니다. 지금 일정은 그대로입니다.';
    notifyListeners();
  }

  void requestItinerary() {
    final trip = current;
    if (trip == null) return;
    itineraryNotice = null;
    if (offline) {
      itineraryDeferred = true;
      itineraryError = null;
      notifyListeners();
      return;
    }
    if (trip.cities.isEmpty) {
      itineraryError = '도시가 없어 일정을 만들지 않습니다.';
      notifyListeners();
      return;
    }
    final viewing = visibleDays(trip);
    final pins = mergePins([viewing, if (!identical(viewing, trip.activeDays)) trip.activeDays, if (trip.proposalDays != null && !identical(viewing, trip.proposalDays)) trip.proposalDays!]);
    final proposal = proposeItinerary(trip, places, pinnedFrom: pins, exclude: _proposalExclusions[trip.id]);
    if (proposal == null) return;
    trip.proposalDays = proposal;
    reviewingProposal = true;
    itineraryDeferred = false;
    itineraryError = null;
    selectedItemId = null;
    itineraryPushed = false;
    selectedDate = planDate(trip);
    notifyListeners();
  }

  void requestVerification(String placeId) {
    verificationNotes[placeId] = '확인 요청을 이 기기에 남겼습니다. 검증 결과는 아직 없습니다.';
    notifyListeners();
  }

  void openCityEdit() {
    editingCity = true;
    explorePushed = false;
    notifyListeners();
  }

  void closeCityEdit() {
    editingCity = false;
    for (final id in relocatingCityIds) {
      cityCandidates.remove(id);
    }
    relocatingCityIds.clear();
    notifyListeners();
  }

  /// Reopens candidate picking for a city whose location is already confirmed.
  /// The confirmed coordinate stays until another candidate is picked.
  Future<void> startRelocate(String cityId) async {
    if (_cityById(cityId) == null) return;
    relocatingCityIds.add(cityId);
    if (offline) {
      notifyListeners();
      return;
    }
    await findCandidates(cityId);
  }

  void cancelRelocate(String cityId) {
    if (!relocatingCityIds.remove(cityId)) return;
    cityCandidates.remove(cityId);
    notifyListeners();
  }

  City? _cityById(String cityId) {
    final trip = current;
    if (trip == null) return null;
    for (final item in trip.cities) {
      if (item.id == cityId) return item;
    }
    return null;
  }

  String citySearchQuery(String cityId) {
    final city = _cityById(cityId);
    if (city == null) return '';
    return citySearchQueries.putIfAbsent(cityId, () => city.name);
  }

  void setCitySearchQuery(String cityId, String value) {
    citySearchQueries[cityId] = value;
    notifyListeners();
  }

  Future<void> findCandidates(String cityId, {String? query}) async {
    if (offline) return;
    final city = _cityById(cityId);
    if (city == null) return;
    final text = (query ?? citySearchQuery(cityId)).trim();
    if (text.isEmpty) return;
    locatingCityIds.add(cityId);
    cityCandidates.remove(cityId);
    notifyListeners();
    final results = await geocoder.search(text, countryCode: city.countryCode);
    locatingCityIds.remove(cityId);
    cityCandidates[cityId] = results;
    notifyListeners();
  }

  Future<void> searchCityAutocomplete(String cityId, String query) async {
    setCitySearchQuery(cityId, query);
    if (offline || query.trim().length < 2) {
      cityCandidates.remove(cityId);
      notifyListeners();
      return;
    }
    await findCandidates(cityId, query: query);
  }

  void pickMapPoint(String cityId, GeoPoint point, {String label = '지도에서 고른 위치'}) {
    pickCandidate(cityId, candidateFromPoint(point, label: label));
  }

  String? addUserPlace({required String name, required PlaceCategory category, required String cityName, GeoPoint? point}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '장소 이름을 입력하세요.';
    final city = cityName.trim();
    if (city.isEmpty) return '도시 이름이 없습니다.';
    final trip = current;
    final geo = point ?? cityGeo(selectedCity) ?? const GeoPoint(0, 0);
    if (geo.lat == 0 && geo.lon == 0) return '도시 좌표가 없습니다. 도시 위치를 먼저 확인하세요.';
    final id = 'place-${_seq++}';
    places.add(buildUserPlace(id: id, name: trimmed, category: category, cityName: city, point: geo));
    if (trip != null) trip.pendingLocalEdits += 1;
    notifyListeners();
    return null;
  }

  void pickCandidate(String cityId, GeoCandidate candidate) {
    final trip = current;
    final city = _cityById(cityId);
    if (trip == null || city == null) return;
    if (!isCurrentLocation(city, candidate)) {
      city.coordinateConfirmed = true;
      city.coordinateLabel = candidate.coordinateLabel;
      city.coordinateSource = candidate.sourceName;
      city.coordinateCandidateId = candidate.id;
      trip.pendingLocalEdits += 1;
    }
    relocatingCityIds.remove(cityId);
    cityCandidates.remove(cityId);
    notifyListeners();
  }

  void deleteTrip(String id) {
    trips.removeWhere((trip) => trip.id == id);
    _proposalExclusions.remove(id);
    if (editingTripId == id) editingTripId = null;
    if (currentTripId == id) {
      currentTripId = null;
      homePushed = false;
      explorePushed = false;
      itineraryPushed = false;
      selectedPlaceId = null;
      selectedItemId = null;
    }
    notifyListeners();
  }

  String? createTrip(TripDraft draft) {
    final errors = validateTripDraft(draft);
    if (errors.isNotEmpty) return errors.values.first;
    final id = 'trip-${_seq++}';
    final country = draft.countryCode.trim().toUpperCase();
    final amount = draft.budgetAmount.trim().isEmpty ? null : int.parse(draft.budgetAmount.trim());
    final currency = draft.budgetCurrency.trim().isEmpty ? null : draft.budgetCurrency.trim();
    final cities = <City>[];
    for (var index = 0; index < draft.cities.length; index++) {
      final city = draft.cities[index];
      cities.add(
        City(
          id: 'city-${_seq++}',
          name: city.name.trim(),
          countryCode: city.countryCode.trim().toUpperCase(),
          start: dateOnly(city.start!),
          end: dateOnly(city.end!),
          sortOrder: index,
        ),
      );
    }
    trips.add(
      Trip(
        id: id,
        title: draft.title.trim(),
        countryCode: country,
        countryName: countryNames[country] ?? country,
        start: dateOnly(draft.start!),
        end: dateOnly(draft.end!),
        status: TripStatus.draft,
        purpose: draft.purpose.trim(),
        tasteTags: draft.tasteTags,
        budgetAmount: amount,
        budgetCurrency: currency,
        companionCount: draft.companionCount,
        cities: cities,
      ),
    );
    creating = false;
    selectTrip(id);
    homePushed = true;
    notifyListeners();
    return null;
  }

  String? updateTrip(String id, TripDraft draft) {
    final errors = validateTripDraft(draft);
    if (errors.isNotEmpty) return errors.values.first;
    if (draft.cities.isEmpty) return '도시를 하나 이상 추가하세요.';
    Trip? trip;
    for (final item in trips) {
      if (item.id == id) {
        trip = item;
        break;
      }
    }
    if (trip == null) return '여행을 찾을 수 없습니다.';

    bool dropped(DayPlan day) => editRemovesDay(trip!, draft, day.date);
    final droppedItemIds = {
      for (final day in [...trip.activeDays, ...?trip.proposalDays])
        if (dropped(day)) ...day.items.map((item) => item.id),
    };
    trip.activeDays = trip.activeDays.where((day) => !dropped(day)).toList();
    final proposal = trip.proposalDays?.where((day) => !dropped(day)).toList();
    trip.proposalDays = proposal == null || proposal.isEmpty ? null : proposal;
    if (trip.proposalDays == null && currentTripId == id) reviewingProposal = false;
    if (currentTripId == id && droppedItemIds.contains(selectedItemId)) {
      selectedItemId = null;
      itineraryPushed = false;
    }

    final previous = {for (final city in trip.cities) city.id: city};
    final cities = <City>[];
    for (var index = 0; index < draft.cities.length; index++) {
      final source = draft.cities[index];
      final name = source.name.trim();
      final countryCode = source.countryCode.trim().toUpperCase();
      final existing = source.id == null ? null : previous.remove(source.id);
      if (existing == null) {
        cities.add(City(id: 'city-${_seq++}', name: name, countryCode: countryCode, start: dateOnly(source.start!), end: dateOnly(source.end!), sortOrder: index));
        continue;
      }
      if (existing.name != name || existing.countryCode != countryCode) {
        existing
          ..coordinateConfirmed = false
          ..coordinateLabel = null
          ..coordinateSource = null
          ..coordinateCandidateId = null;
        relocatingCityIds.remove(existing.id);
        cityCandidates.remove(existing.id);
      }
      existing
        ..name = name
        ..countryCode = countryCode
        ..start = dateOnly(source.start!)
        ..end = dateOnly(source.end!)
        ..sortOrder = index;
      cities.add(existing);
    }
    for (final removed in previous.keys) {
      relocatingCityIds.remove(removed);
      cityCandidates.remove(removed);
    }

    final country = draft.countryCode.trim().toUpperCase();
    trip
      ..title = draft.title.trim()
      ..countryCode = country
      ..countryName = countryNames[country] ?? country
      ..start = dateOnly(draft.start!)
      ..end = dateOnly(draft.end!)
      ..purpose = draft.purpose.trim()
      ..tasteTags = List<String>.of(draft.tasteTags)
      ..budgetAmount = draft.budgetAmount.trim().isEmpty ? null : int.parse(draft.budgetAmount.trim())
      ..budgetCurrency = draft.budgetCurrency.trim().isEmpty ? null : draft.budgetCurrency.trim()
      ..companionCount = draft.companionCount
      ..cities = cities
      ..pendingLocalEdits += 1;

    editingTripId = null;
    if (currentTripId == id) {
      final fallback = containsDay(trip.start, trip.end, now) ? dateOnly(now) : dateOnly(trip.start);
      if (!containsDay(trip.start, trip.end, selectedDate)) selectedDate = fallback;
      if (!containsDay(trip.start, trip.end, journalDate)) journalDate = fallback;
      if (cities.every((city) => city.id != selectedCityId)) {
        selectedCityId = cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => cities.first).id;
      }
    }
    notifyListeners();
    return null;
  }
}
