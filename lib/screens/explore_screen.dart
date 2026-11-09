import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
import '../format.dart';
import '../map/place_pins.dart';
import '../map/trip_map.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const NeedTrip(title: '탐색', titleKey: Key('screen-title-explore'));
    final city = controller.selectedCity;
    final blocked = city == null || !city.coordinateConfirmed;
    final results = controller.visiblePlaces();
    final pins = blocked ? const <MapPin>[] : explorePins(results, selectedId: controller.selectedPlaceId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = MediaQuery.textScalerOf(context).scale(17) > 17 * 1.25 || constraints.maxHeight < 640;
        final mapHeight = (constraints.maxHeight * 0.28).clamp(120.0, 240.0);
        final header = _ExploreHeader(trip: trip, sample: trip.dataOriginMock, offline: controller.offline);
        final map = pins.isEmpty
            ? null
            : SizedBox(
                height: mapHeight,
                child: MapFrame(
                  expand: true,
                  child: TripMap(pins: pins, onPinTap: (pin) => controller.openPlace(pin.placeId, tablet: tablet)),
                ),
              );
        final filters = _ExploreFilters(trip: trip, blocked: blocked, results: results, tablet: tablet);
        return Column(
          children: [
            if (!inline) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: header),
              if (map != null) ...[const SizedBox(height: 8), map],
            ],
            Expanded(
              child: ScrollHost(
                id: 'explore',
                builder: (context, scroll) {
                  return ListView(
                    key: const Key('explore-scroll'),
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (inline) ...[
                        header,
                        if (map != null) ...[const SizedBox(height: 8), map],
                      ],
                      filters,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.trip, required this.sample, required this.offline});

  final Trip trip;
  final bool sample;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PageHeader(
                title: '탐색',
                titleKey: const Key('screen-title-explore'),
                subtitle: cityTripLabel(controller.selectedCity?.name, trip.title),
              ),
            ),
            IconButton(
              key: const Key('explore-info'),
              tooltip: '장소 자료 안내',
              icon: const Icon(Icons.info_outline, color: AppColors.secondary),
              onPressed: () => _showCatalogInfo(context, sample: sample, offline: offline),
            ),
          ],
        ),
        _CatalogState(sample: sample, offline: offline),
      ],
    );
  }
}

class _ExploreFilters extends StatelessWidget {
  const _ExploreFilters({required this.trip, required this.blocked, required this.results, required this.tablet});

  final Trip trip;
  final bool blocked;
  final List<Place> results;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('place-query'),
          style: AppType.body,
          decoration: AppFields.decoration(blocked ? '저장된 장소' : '장소 이름으로 찾기'),
          readOnly: blocked,
          onChanged: blocked ? null : controller.setQuery,
        ),
        const SectionLabel('도시'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in trip.cities)
              SelectChip(
                label: item.name,
                note: item.coordinateConfirmed ? null : '위치 미확인',
                selected: item.id == controller.selectedCityId,
                onTap: () => controller.selectCity(item.id),
              ),
          ],
        ),
        const SectionLabel('분류'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in PlaceCategory.values)
              SelectChip(
                label: categoryLabel(category),
                selected: controller.categoryFilter == category,
                onTap: () => controller.setCategory(category),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (blocked) ...[
          const Text('도시 위치가 확인되지 않았습니다.', style: AppType.body),
          const SizedBox(height: 8),
          AppButton(label: '도시 편집으로 이동', filled: false, onPressed: controller.openCityEdit),
        ] else ...[
          if (!trip.dataOriginMock) ...[
            const SizedBox(height: 4),
            AppButton(
              key: const Key('add-user-place'),
              label: '직접 장소 추가',
              filled: false,
              onPressed: () {
                final city = controller.selectedCity;
                if (city != null) _AddPlaceSheet.open(context, city.name);
              },
            ),
          ],
          if (results.isEmpty)
            QuietEmpty(
              message: trip.dataOriginMock ? '이 조건의 장소가 없습니다.' : '이 조건의 장소가 없습니다. 직접 장소를 추가해 보세요.',
            )
          else ...[
            const SizedBox(height: 4),
            for (final place in results) _PlaceCard(place: place, tablet: tablet),
          ],
        ],
      ],
    );
  }
}

Future<void> _showCatalogInfo(BuildContext context, {required bool sample, required bool offline}) {
  final lines = <String>[
    if (offline) '오프라인입니다. 새 장소는 받지 않고, 찾기와 분류는 이 기기에 있는 목록만 거릅니다.',
    if (sample)
      '이 기기의 샘플 장소(dataOriginMock)입니다. 검색 결과가 아닙니다. 추천 문장은 이유이고, 영업시간 배지는 오늘 영업을 보증하지 않습니다.',
    if (!sample && !offline)
      '직접 추가한 장소와 이 기기에 저장된 목록입니다. 외부 장소 API는 연결되지 않았습니다.',
    sample ? '순서는 샘플에 넣은 순서입니다. 후기 점수로 줄을 세우지 않습니다.' : '후기 자료가 연결되지 않아 추천 순서가 없습니다.',
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          key: const Key('explore-info-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('장소 자료 안내', style: AppType.headline),
              for (final line in lines) ...[
                const SizedBox(height: 8),
                Text(line, style: AppType.body),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.tablet});

  final Place place;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final link = controller.linkFor(place.id);
    final selected = controller.selectedPlaceId == place.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          key: Key('place-card-${place.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.openPlace(place.id, tablet: tablet),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(categoryLabel(place.category), style: AppType.footnote)),
                    const SizedBox(width: 8),
                    Flexible(child: FactBadge(rowBadge(place))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(place.name, style: AppType.headline),
                const SizedBox(height: 2),
                Text(place.localName ?? '현지어 이름 미확인', style: AppType.footnote),
                const SizedBox(height: 8),
                Text(addressLine(place), style: AppType.footnote),
                if (placeSuggestion(place.id) != null) ...[
                  const SizedBox(height: 8),
                  Text(placeSuggestion(place.id)!, style: AppType.body),
                ],
                const SizedBox(height: 4),
                Text(decisionLabel(link.decision, saved: link.saved), style: AppType.footnoteStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogState extends StatelessWidget {
  const _CatalogState({required this.sample, required this.offline});

  final bool sample;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final filtered = controller.searchQuery.trim().isNotEmpty || controller.categoryFilter != null;
    if (!sample && !offline) {
      return Container(
        key: const Key('explore-catalog-state'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: const Color(0xFFE8F4EC), borderRadius: BorderRadius.circular(10)),
        child: Text(
          '직접 추가한 장소와 이 기기에 저장된 목록을 보여 줍니다. 샘플 여행과 달리 외부 장소 API는 연결되지 않았습니다.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppType.footnote,
        ),
      );
    }
    final String title;
    if (offline && sample) {
      title = '오프라인 · 저장된 샘플만';
    } else if (offline) {
      title = '오프라인 · 저장된 장소만';
    } else {
      title = '이 기기의 샘플 장소';
    }
    return Container(
      key: const Key('explore-catalog-state'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFE8EEF4), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.footnoteStrong),
          ),
          if (filtered)
            TextButton(
              key: const Key('explore-clear-filter'),
              onPressed: () {
                controller.setQuery('');
                final category = controller.categoryFilter;
                if (category != null) controller.setCategory(category);
              },
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Text('필터 지우기', style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet({required this.cityName});

  final String cityName;

  static Future<void> open(BuildContext context, String cityName) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _AddPlaceSheet(cityName: cityName),
      ),
    );
  }

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _nameController = TextEditingController();
  PlaceCategory _category = PlaceCategory.attraction;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final controller = TripScope.of(context);
    final error = controller.addUserPlace(name: _nameController.text, category: _category, cityName: widget.cityName);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('직접 장소 추가', style: AppType.headline),
          const SizedBox(height: 4),
          Text('${widget.cityName} · 사용자 입력 (dataOriginMock 아님)', style: AppType.footnote),
          const SizedBox(height: 12),
          TextField(
            key: const Key('user-place-name'),
            controller: _nameController,
            style: AppType.body,
            decoration: AppFields.decoration('장소 이름'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PlaceCategory>(
            key: const Key('user-place-category'),
            initialValue: _category,
            decoration: AppFields.decoration('분류'),
            items: [
              for (final category in PlaceCategory.values)
                DropdownMenuItem(value: category, child: Text(categoryLabel(category), style: AppType.body)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _category = value);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppType.footnote.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          AppButton(key: const Key('user-place-save'), label: '추가', onPressed: _save),
        ],
      ),
    );
  }
}
