import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../map/geo.dart';
import '../map/place_pins.dart';
import '../map/trip_map.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/schedule_block.dart';

class UnderwayScreen extends StatelessWidget {
  const UnderwayScreen({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const NeedTrip(title: '여행 중', titleKey: Key('screen-title-underway'));
    final today = dayFor(trip.activeDays, controller.now);
    final next = controller.destinationFor(trip);
    final nextPlace = controller.placeById(next?.placeId);
    final focus = nextPlace == null ? null : placeGeo(nextPlace);
    final visits = visitPins(today, controller.placeById, emphasizePlaceId: nextPlace?.id, now: controller.now);
    final skip = visits.map((pin) => pin.placeId).toSet();
    final nearby = focus == null ? const <MapPin>[] : nearbyPins(controller.places, focus, skip);
    final pins = [...visits, ...nearby];
    final map = pins.isEmpty
        ? const MapFrame(expand: true, child: QuietEmpty(message: '좌표가 확인된 장소가 없습니다.', icon: CupertinoIcons.map))
        : MapFrame(
            expand: true,
            note: routeEstimateNote,
            child: TripMap(pins: pins, focus: focus, onPinTap: (pin) => _openPin(controller, pin)),
          );
    final steps = _DestinationColumn(nearby: nearby);
    if (!tablet) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: '여행 중', titleKey: const Key('screen-title-underway'), subtitle: cityTripLabel(controller.selectedCity?.name, trip.title)),
                StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 248, child: map),
          Expanded(child: steps),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PageHeader(title: '여행 중', titleKey: const Key('screen-title-underway'), subtitle: cityTripLabel(controller.selectedCity?.name, trip.title)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: map),
              const VerticalDivider(width: 1),
              Expanded(child: steps),
            ],
          ),
        ),
      ],
    );
  }

  void _openPin(TripController controller, MapPin pin) {
    if (pin.nearby) {
      controller.openPlace(pin.placeId, tablet: tablet);
      controller.selectTab(1);
      return;
    }
    controller.openItem(pin.id, tablet: tablet);
    controller.selectTab(2);
  }
}

class _DestinationColumn extends StatelessWidget {
  const _DestinationColumn({required this.nearby});

  final List<MapPin> nearby;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const SizedBox.shrink();
    final next = controller.destinationFor(trip);
    final today = dayFor(trip.activeDays, controller.now);
    final previous = today == null ? null : previousVisit(today.items, controller.now);
    final remaining = controller.remainingFor(trip);
    final nextPlace = next == null ? null : controller.placeById(next.placeId);
    final focus = nextPlace == null ? null : placeGeo(nextPlace);
    return ListView(
      key: const Key('underway-steps'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('기준 시각 ${formatMonthDay(controller.now)} ${formatHm(controller.now)} · 샘플', style: AppType.footnote),
        if (previous != null) ...[
          const SizedBox(height: 4),
          Text('앞선 ${kindLabel(previous.kind)} ${previous.title}은 ${previous.end == null ? '끝났습니다' : '${formatHm(previous.end!)}에 끝났습니다'}.', style: AppType.footnote),
        ],
        const SizedBox(height: 12),
        if (trip.activeDays.isEmpty)
          const Text('적용된 일정이 없습니다.', style: AppType.body)
        else if (next == null)
          const Text('오늘 남은 방문이 없습니다.', style: AppType.body)
        else ...[
          const Text('다음 목적지', style: AppType.footnoteStrong),
          const SizedBox(height: 8),
          ScheduleBlock(item: next, emphasize: true),
          const SizedBox(height: 8),
          const Text('대체 경로 없음', style: AppType.footnote),
        ],
        if (nearby.isNotEmpty) ...[
          const SectionLabel('주변 장소'),
          for (final pin in nearby) _NearbyRow(pin: pin, focus: focus),
        ],
        if (remaining.isNotEmpty) ...[
          const SectionLabel('오늘 남은 일정'),
          for (final item in remaining) ...[
            ScheduleBlock(
              item: item,
              onTap: () {
                controller.selectedDate = dateOnly(item.start ?? controller.now);
                controller.selectedItemId = item.id;
                controller.selectTab(2);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.pin, required this.focus});

  final MapPin pin;
  final GeoPoint? focus;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final place = controller.placeById(pin.placeId);
    final distance = focus == null ? null : straightLineLabel(distanceMeters(focus!, pin.point));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: () {
            controller.openPlace(pin.placeId, tablet: AdaptiveScope.of(context).tablet);
            controller.selectTab(1);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: AppDecor.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place == null ? pin.label : '${pin.label} · ${categoryLabel(place.category)}', style: AppType.headline),
                if (distance != null) Text(distance, style: AppType.footnote),
                if (place != null && place.suspended) Text(badgeLabel(FactValidity.suspended), style: AppType.footnote.copyWith(color: AppColors.warningFg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
