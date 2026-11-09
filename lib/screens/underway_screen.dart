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
import '../widgets/next_stop_card.dart';
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
    final visits = visitPins(
      today,
      controller.placeById,
      emphasizePlaceId: nextPlace?.id,
      now: controller.now,
      doneIds: trip.visitDoneIds,
    );
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = (constraints.maxHeight * 0.45).clamp(0.0, 248.0);
                return Column(
                  children: [
                    if (mapHeight >= 120) SizedBox(height: mapHeight, child: map),
                    Expanded(child: steps),
                  ],
                );
              },
            ),
          ),
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
    final item = _activeItem(controller, pin.id);
    if (item != null) controller.openActiveItem(item, tablet: tablet);
  }

  PlanItem? _activeItem(TripController controller, String id) {
    for (final day in controller.current?.activeDays ?? const <DayPlan>[]) {
      for (final item in day.items) {
        if (item.id == id) return item;
      }
    }
    return null;
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
    final previous = today == null ? null : previousVisit(today.items, controller.now, doneIds: trip.visitDoneIds);
    final remaining = controller.remainingFor(trip);
    final nextPlace = next == null ? null : controller.placeById(next.placeId);
    final focus = nextPlace == null ? null : placeGeo(nextPlace);
    final tablet = AdaptiveScope.of(context).tablet;
    final progress = today == null ? null : visitProgress(today.items, controller.now, doneIds: trip.visitDoneIds);
    void open(PlanItem item) => controller.openActiveItem(item, tablet: tablet);
    return ListView(
      key: const Key('underway-steps'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (controller.showReferenceClock(trip))
          Text('기준 시각 ${formatMonthDay(controller.now)} ${formatHm(controller.now)}${trip.dataOriginMock ? ' · 샘플' : ''}', style: AppType.footnote),
        if (progress != null && progress.total > 0) ...[
          const SizedBox(height: 4),
          Text('오늘 방문 ${progress.total}곳 중 ${progress.done}곳 끝남', key: const Key('underway-progress'), style: AppType.footnoteStrong),
        ],
        if (previous != null) ...[
          const SizedBox(height: 4),
          Text('앞선 일정: ${previous.title}${previous.end == null ? '' : ' · ${formatHm(previous.end!)} 종료'}', style: AppType.footnote),
        ],
        const SizedBox(height: 12),
        if (trip.activeDays.isEmpty)
          _NoPlan(trip: trip)
        else if (next == null)
          _NothingNext(trip: trip, today: today, onOpen: open)
        else ...[
          const Text('다음 목적지', style: AppType.footnoteStrong),
          const SizedBox(height: 8),
          NextStopCard(item: next, place: nextPlace, onOpenDetail: () => open(next)),
        ],
        if (nearby.isNotEmpty) ...[
          const SectionLabel('주변 장소'),
          for (final pin in nearby) _NearbyRow(pin: pin, focus: focus),
        ],
        if (remaining.isNotEmpty) ...[
          const SectionLabel('오늘 남은 일정'),
          for (final item in remaining) ...[
            ScheduleBlock(item: item, onTap: () => open(item)),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final pending = trip.proposalDays != null;
    return Column(
      key: const Key('underway-no-plan'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuietEmpty(
          title: '적용된 일정이 없습니다.',
          message: pending ? '검토할 제안이 있습니다. 적용하면 여기서 다음 목적지를 보여 줍니다.' : '일정 탭에서 일정을 만들어 적용하면 여기서 다음 목적지를 보여 줍니다.',
          icon: CupertinoIcons.calendar,
        ),
        Center(
          child: AppButton(
            key: const Key('underway-open-itinerary'),
            label: pending ? '제안 검토하기' : '일정 만들러 가기',
            onPressed: () {
              if (pending) controller.startReview();
              controller.selectTab(2);
            },
          ),
        ),
      ],
    );
  }
}

class _NothingNext extends StatelessWidget {
  const _NothingNext({required this.trip, required this.today, required this.onOpen});

  final Trip trip;
  final DayPlan? today;
  final void Function(PlanItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final now = dateOnly(controller.now);
    final later = laterVisit(trip, controller.now);
    final String message;
    if (now.isBefore(dateOnly(trip.start))) {
      message = '여행은 ${formatMonthDay(trip.start)}에 시작합니다.';
    } else if (now.isAfter(dateOnly(trip.end))) {
      message = '여행 기간이 끝났습니다.';
    } else if (today == null) {
      message = '오늘은 적용된 일정이 없습니다.';
    } else {
      message = '오늘 남은 방문이 없습니다.';
    }
    return Column(
      key: const Key('underway-nothing-next'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: AppType.body),
        if (later != null) ...[
          const SizedBox(height: 12),
          Text('${formatMonthDay(later.day.date)} 첫 방문', style: AppType.footnoteStrong),
          const SizedBox(height: 8),
          ScheduleBlock(key: const Key('underway-later'), item: later.item, onTap: () => onOpen(later.item)),
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
