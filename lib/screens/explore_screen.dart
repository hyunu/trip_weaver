import 'package:flutter/material.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: '탐색', titleKey: const Key('screen-title-explore'), subtitle: cityTripLabel(controller.selectedCity?.name, trip.title)),
              StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
            ],
          ),
        ),
        if (pins.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: TripMap(
              pins: pins,
              onPinTap: (pin) => controller.openPlace(pin.placeId, tablet: tablet),
            ),
          ),
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
              decoration: InputDecoration(
                hintText: blocked ? '저장된 장소' : '장소 이름',
                hintStyle: AppType.body.copyWith(color: AppColors.tertiary),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
              ),
              readOnly: blocked,
              onChanged: blocked ? null : controller.setQuery,
            ),
            const SizedBox(height: 8),
            if (blocked) ...[
              const Text('도시 위치가 확인되지 않았습니다.', style: AppType.body),
              const SizedBox(height: 8),
              AppButton(label: '도시 편집으로 이동', filled: false, onPressed: controller.openCityEdit),
            ] else ...[
              AppButton(key: const Key('search-city'), label: '이 도시에서 찾기', onPressed: () => controller.setQuery(controller.searchQuery)),
              const SizedBox(height: 12),
              const Text('후기 자료가 연결되지 않아 추천 순서가 없습니다.', style: AppType.footnote),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const Text('이 조건의 장소가 없습니다.', style: AppType.body)
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('place-card-${place.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.openPlace(place.id, tablet: tablet),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
