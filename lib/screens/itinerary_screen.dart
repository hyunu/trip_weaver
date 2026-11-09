import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../map/place_pins.dart';
import '../map/trip_map.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/place_panel.dart';
import '../widgets/schedule_block.dart';

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({super.key, required this.tablet, required this.wide});

  final bool tablet;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const NeedTrip(title: '일정', titleKey: Key('screen-title-itinerary'));
    final header = _ItineraryHeader(trip: trip);
    if (!tablet) {
      return Column(
        children: [
          header,
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: _DateChips(trip: trip)),
          Expanded(child: _DayPane(trip: trip, tablet: false)),
        ],
      );
    }
    if (!wide) {
      return Column(
        children: [
          header,
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: _DateChips(trip: trip)),
                      Expanded(child: _DayPane(trip: trip, tablet: true)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                const SizedBox(width: 360, child: ItemFacts()),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 240, child: _DateColumn(trip: trip)),
              const VerticalDivider(width: 1),
              Expanded(child: _DayPane(trip: trip, tablet: true)),
              const VerticalDivider(width: 1),
              const SizedBox(width: 340, child: ItemFacts()),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayPane extends StatelessWidget {
  const _DayPane({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final day = controller.visibleDay(trip);
    final next = controller.destinationFor(trip);
    final nextToday = next?.start != null && day != null && sameDay(next!.start!, day.date);
    final pins = visitPins(day, controller.placeById, now: controller.now, emphasizePlaceId: nextToday ? next.placeId : null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = (constraints.maxHeight - 176).clamp(120.0, 220.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pins.isEmpty)
              const MapFrame(child: QuietEmpty(message: '이 날짜에 좌표가 확인된 장소가 없습니다.', icon: CupertinoIcons.map))
            else
              MapFrame(
                note: routeEstimateNote,
                child: SizedBox(
                  height: mapHeight,
                  child: TripMap(
                    pins: pins,
                    onPinTap: (pin) => controller.openItem(pin.id, tablet: tablet),
                  ),
                ),
              ),
            Expanded(child: _Timeline(trip: trip, tablet: tablet)),
          ],
        );
      },
    );
  }
}

class _ItineraryHeader extends StatelessWidget {
  const _ItineraryHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final deferred = controller.offline || controller.itineraryDeferred;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '일정', titleKey: const Key('screen-title-itinerary'), subtitle: cityTripLabel(controller.selectedCity?.name, trip.title)),
          StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
          if (trip.weatherSkipped) ...[
            const SizedBox(height: 8),
            const Text('날씨 자료가 없어 날씨로 일정을 바꾸지 않았습니다.', style: AppType.footnote),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: deferred ? '온라인이 되면 생성합니다' : '일정 만들기',
                  onPressed: controller.requestItinerary,
                ),
              ),
              if (trip.proposalDays != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: '제안 검토',
                    filled: false,
                    onPressed: controller.reviewingProposal ? controller.showActive : controller.startReview,
                  ),
                ),
              ],
            ],
          ),
          if (controller.itineraryError != null) ...[
            const SizedBox(height: 6),
            Text(controller.itineraryError!, style: AppType.footnote.copyWith(color: AppColors.danger)),
          ],
          if (controller.reviewingProposal) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('아직 적용하지 않은 일정입니다.', style: AppType.body),
                  const SizedBox(height: 8),
                  AppButton(label: '이 일정 적용', onPressed: controller.applyProposal),
                  const SizedBox(height: 8),
                  AppButton(label: '제안 버리기', filled: false, destructive: true, onPressed: controller.discardProposal),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChips extends StatelessWidget {
  const _DateChips({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final days = tripDays(trip);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = sameDay(day, controller.selectedDate);
          final today = sameDay(day, controller.now);
          return DateToken(
            label: '${day.month}.${day.day}',
            note: today ? '오늘' : weekdayKo(day),
            selected: selected,
            width: 84,
            onTap: () => controller.selectDate(day),
          );
        },
      ),
    );
  }
}

class _DateColumn extends StatelessWidget {
  const _DateColumn({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final days = tripDays(trip);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final selected = sameDay(day, controller.selectedDate);
        final today = sameDay(day, controller.now);
        return DateRailTile(
          label: formatMonthDay(day),
          note: today ? '${weekdayKo(day)} · 오늘' : weekdayKo(day),
          selected: selected,
          onTap: () => controller.selectDate(day),
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final day = controller.visibleDay(trip);
    final items = day?.items ?? const <PlanItem>[];
    return ScrollHost(
      id: 'itinerary',
      builder: (context, scroll) {
        if (items.isEmpty) {
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: const [QuietEmpty(message: '이 날짜의 일정이 없습니다.')],
          );
        }
        return ListView.separated(
          key: const Key('itinerary-scroll'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return ScheduleBlock(
              item: item,
              proposal: controller.reviewingProposal,
              selected: controller.selectedItemId == item.id,
              onTap: () => controller.openItem(item.id, tablet: tablet),
            );
          },
        );
      },
    );
  }
}

class ItemFacts extends StatelessWidget {
  const ItemFacts({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final item = controller.selectedItem();
    if (item == null) {
      return const EmptyPane(title: '장소 사실', message: '일정을 고르세요.');
    }
    final place = controller.placeById(item.placeId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        ScheduleBlock(item: item, proposal: controller.reviewingProposal),
        const SizedBox(height: 12),
        AppButton(label: item.locked ? '고정 해제' : '고정', filled: item.locked, onPressed: () => controller.toggleLock(item.id)),
        const SizedBox(height: 8),
        AppButton(
          label: '이 항목을 삭제합니다.',
          filled: false,
          destructive: true,
          onPressed: () => _confirmDelete(context, controller, item.id),
        ),
        if (place != null) ...[
          const SizedBox(height: 16),
          PlacePanel(place: place, shrinkWrap: true),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, TripController controller, String id) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('이 항목을 삭제합니다.', style: AppType.headline),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소', style: AppType.headline)),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                controller.deleteItem(id);
              },
              child: const Text('삭제', style: AppType.headline),
            ),
          ],
        );
      },
    );
  }
}
