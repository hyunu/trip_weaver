import 'package:flutter/foundation.dart';

import '../data/countries.dart';
import '../data/sample_catalog.dart';
import '../logic/propose.dart';
import '../logic/schedule.dart';
import '../logic/trip_rules.dart';
import '../logic/city_lookup.dart';
import '../model/journal.dart';
import '../model/models.dart';
import 'trip_store.dart';

class TripController extends ChangeNotifier {
  TripController({DateTime? now, SampleCatalog? catalog, TripStore? store})
    : now = now ?? DateTime(2026, 11, 8, 10, 40),
      _store = store {
    final seed = catalog ?? buildSampleCatalog();
    trips = seed.trips;
    places = seed.places;
    _sampleTripIds = {for (final trip in seed.trips) if (trip.dataOriginMock) trip.id};
    currentTripId = seed.currentTripId;
    selectedDate = dateOnly(this.now);
    journalDate = dateOnly(this.now);
    final trip = current;
    if (trip != null && trip.cities.isNotEmpty) {
      selectedCityId = trip.cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => trip.cities.first).id;
    }
  }

  final DateTime now;
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
  bool editingCity = false;
  bool offline = false;
  bool itineraryDeferred = false;
  String? itineraryError;
  String? itineraryNotice;
  PlaceCategory? categoryFilter;
  String searchQuery = '';
  final Map<String, String> verificationNotes = {};
  final Map<String, List<GeoCandidate>> cityCandidates = {};
  final Set<String> relocatingCityIds = {};
  final Map<String, double> scrollOffsets = {};
  final Map<String, ProposalExclusions> _proposalExclusions = {};
  final JournalBook journal = JournalBook();
  int _seq = 100;
  final TripStore? _store;
  late final Set<String> _sampleTripIds;
  Future<void> _saveChain = Future<void>.value();

  Future<void> get persistenceSettled => _saveChain;

  Future<void> restore() async {
    final store = _store;
    if (store == null) return;
    TripSnapshot? snapshot;
    try {
      snapshot = await store.read();
    } on Object {
      snapshot = null;
    }
    if (snapshot == null) return;
    for (final trip in snapshot.trips) {
      if (_sampleTripIds.contains(trip.id)) trip.dataOriginMock = true;
    }
    trips = snapshot.trips;
    currentTripId = snapshot.currentTripId;
    if (snapshot.nextSeq > _seq) _seq = snapshot.nextSeq;
    final trip = current;
    if (trip == null || trip.cities.isEmpty) {
      selectedCityId = null;
    } else if (selectedCityId == null || trip.cities.every((city) => city.id != selectedCityId)) {
      selectedCityId = trip.cities.firstWhere((city) => city.coordinateConfirmed, orElse: () => trip.cities.first).id;
    }
    super.notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    final store = _store;
    if (store == null) return;
    final encoded = encodeTripSnapshot(TripSnapshot(trips: trips, currentTripId: currentTripId, nextSeq: _seq));
    _saveChain = _saveChain.then((_) async {
      try {
        await store.write(encoded);
        lastSaveError = null;
      } on Object catch (error) {
        lastSaveError = error;
      }
    });
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

  bool get homeShowsSample => trips.any((trip) => trip.dataOriginMock);

  void saveScroll(String key, double offset) => scrollOffsets[key] = offset;

  double scrollOf(String key) => scrollOffsets[key] ?? 0;

  void selectTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  void selectTrip(String id) {
    if (id != currentTripId) itineraryNotice = null;
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
    homePushed = false;
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
    final days = reviewingProposal ? trip.proposalDays : trip.activeDays;
    if (days == null) return null;
    for (final day in days) {
      for (final item in day.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
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
  void startRelocate(String cityId) {
    if (_cityById(cityId) == null) return;
    relocatingCityIds.add(cityId);
    if (offline) {
      notifyListeners();
      return;
    }
    findCandidates(cityId);
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

  void findCandidates(String cityId) {
    if (offline) return;
    cityCandidates[cityId] = candidatesForCity(_cityById(cityId)?.name ?? '');
    notifyListeners();
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
}
