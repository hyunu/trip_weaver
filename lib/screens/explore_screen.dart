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
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: '탐색', titleKey: const Key('screen-title-explore'), subtitle: cityTripLabel(controller.selectedCity?.name, trip.title)),
        _CatalogState(sample: trip.dataOriginMock, offline: controller.offline),
        if (!blocked) ...[
          const SizedBox(height: 8),
          AppButton(key: const Key('search-city'), label: '이 도시에서 찾기', onPressed: () => controller.setQuery(controller.searchQuery)),
          const SizedBox(height: 6),
          Text(
            trip.dataOriginMock ? '순서는 샘플에 넣은 순서입니다. 후기 점수로 줄을 세우지 않습니다.' : '후기 자료가 연결되지 않아 추천 순서가 없습니다.',
            style: AppType.footnote,
          ),
        ],
      ],
    );
    final map = pins.isEmpty
        ? null
        : SizedBox(
            height: 240,
            child: MapFrame(
              expand: true,
              child: TripMap(pins: pins, onPinTap: (pin) => controller.openPlace(pin.placeId, tablet: tablet)),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        // With large text or a short window the fixed header and map would
        // leave no room for the list, so everything scrolls together.
        final inline = MediaQuery.textScalerOf(context).scale(17) > 17 * 1.25 || constraints.maxHeight < 640;
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
                      TextField(
                        key: const Key('place-query'),
                        style: AppType.body,
                        decoration: AppFields.decoration(blocked ? '저장된 장소' : '장소 이름'),
                        readOnly: blocked,
                        onChanged: blocked ? null : controller.setQuery,
                      ),
                      const SizedBox(height: 8),
                      if (blocked) ...[
                        const Text('도시 위치가 확인되지 않았습니다.', style: AppType.body),
                        const SizedBox(height: 8),
                        AppButton(label: '도시 편집으로 이동', filled: false, onPressed: controller.openCityEdit),
                      ] else ...[
                        const SizedBox(height: 4),
                        if (results.isEmpty)
                          const QuietEmpty(message: '이 조건의 장소가 없습니다.')
                        else
                          for (final place in results) _PlaceCard(place: place, tablet: tablet),
                      ],
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
    if (!sample && !offline) return const SizedBox.shrink();
    final controller = TripScope.of(context);
    final filtered = controller.searchQuery.trim().isNotEmpty || controller.categoryFilter != null;
    final String title;
    final String body;
    if (offline && sample) {
      title = '오프라인 · 저장된 샘플만';
      body = '새 장소는 받지 않습니다. 찾기와 분류는 외탄, 루자쭈이, 예원, 덕흥관, 십육포만 거릅니다.';
    } else if (offline) {
      title = '오프라인 · 저장된 장소만';
      body = '새 장소는 받지 않습니다. 찾기와 분류는 이 기기에 있는 목록만 거릅니다.';
    } else {
      title = '이 기기의 샘플 장소';
      body = '검색 결과가 아닙니다. 추천 문장은 이유이고, 영업시간 배지는 오늘 영업을 보증하지 않습니다.';
    }
    return Container(
      key: const Key('explore-catalog-state'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(color: const Color(0xFFE8EEF4), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.footnoteStrong),
          const SizedBox(height: 2),
          Text(body, style: AppType.footnote),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('explore-clear-filter'),
              onPressed: () {
                controller.setQuery('');
                final category = controller.categoryFilter;
                if (category != null) controller.setCategory(category);
              },
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              child: Text(filtered ? '필터 지우고 샘플 전체 보기' : '샘플 전체 목록 유지', style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
            ),
          ),
        ],
      ),
    );
  }
}
