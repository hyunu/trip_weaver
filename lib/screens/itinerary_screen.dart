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
      return LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
                child: SingleChildScrollView(primary: false, child: header),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: _DateChips(trip: trip)),
              Expanded(child: _DayPane(trip: trip, tablet: false)),
            ],
          );
        },
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
        final mapHeight = (constraints.maxHeight - 176).clamp(0.0, 220.0);
        final showMap = mapHeight >= 96;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showMap)
              const SizedBox.shrink()
            else if (pins.isEmpty)
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
    final reviewing = controller.reviewingProposal;
    final summary = trip.proposalDays == null ? null : summarizeProposal(trip.proposalDays!);
    final excluded = controller.excludedCount(trip);
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
                  key: const Key('request-itinerary'),
                  label: trip.activeDays.isEmpty && trip.proposalDays == null ? '일정 만들기' : '새로 제안받기',
                  onPressed: controller.offline ? null : controller.requestItinerary,
                ),
              ),
              if (trip.proposalDays != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    key: const Key('toggle-proposal'),
                    label: reviewing ? '현재 일정 보기' : '제안 검토',
                    filled: false,
                    onPressed: reviewing ? controller.showActive : controller.startReview,
                  ),
                ),
              ],
            ],
          ),
          if (controller.offline || controller.itineraryDeferred) ...[
            const SizedBox(height: 6),
            Text(
              controller.offline ? '오프라인에서는 일정을 만들 수 없습니다. 연결되면 다시 누르세요.' : '오프라인일 때 누른 일정 만들기는 실행되지 않았습니다. 다시 누르세요.',
              key: const Key('itinerary-offline-note'),
              style: AppType.footnote,
            ),
          ],
          if (controller.itineraryError != null) ...[
            const SizedBox(height: 6),
            Text(controller.itineraryError!, style: AppType.footnote.copyWith(color: AppColors.danger)),
          ],
          if (controller.itineraryNotice != null && !reviewing) ...[
            const SizedBox(height: 6),
            Text(controller.itineraryNotice!, key: const Key('itinerary-notice'), style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
          ],
          if (reviewing) ...[
            const SizedBox(height: AppSpace.xs),
            Container(
              key: const Key('proposal-review'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(AppRadii.control)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('아직 적용하지 않은 일정입니다.', style: AppType.headline.copyWith(color: AppColors.warningFg)),
                  const SizedBox(height: 2),
                  Text(
                    trip.activeDays.isEmpty ? '적용하면 이 여행의 일정이 됩니다.' : '적용하면 지금 일정을 이 제안으로 바꿉니다.',
                    style: AppType.footnote.copyWith(color: AppColors.warningFg),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 2),
                    Text(summary.line, key: const Key('proposal-summary'), style: AppType.footnoteStrong.copyWith(color: AppColors.warningFg)),
                    if (summary.visits == 0 && summary.pinned == 0)
                      Text(
                        '탐색에서 「일정에 선택」한 장소가 없어 식사 자리만 제안했습니다.',
                        key: const Key('proposal-no-places'),
                        style: AppType.footnote.copyWith(color: AppColors.warningFg),
                      ),
                  ],
                  if (excluded > 0) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      '제안에서 뺀 항목 $excluded개는 새로 제안받아도 다시 넣지 않습니다.',
                      key: const Key('proposal-excluded'),
                      style: AppType.footnote.copyWith(color: AppColors.warningFg),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('restore-excluded'),
                        onPressed: controller.offline ? null : controller.restoreExcluded,
                        child: const Text('뺀 항목 되살려 다시 제안받기'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      Expanded(child: AppButton(key: const Key('apply-proposal'), label: '이 일정 적용', onPressed: controller.applyProposal)),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: AppButton(key: const Key('discard-proposal'), label: '제안 버리기', filled: false, destructive: true, onPressed: () => _confirmDiscard(context, controller)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _confirmDiscard(BuildContext context, TripController controller) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('이 제안을 버릴까요?', style: AppType.headline),
        content: const Text('검토 중인 제안과 그 안에서 고친 내용이 사라집니다. 지금 일정은 바뀌지 않습니다.', style: AppType.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            key: const Key('confirm-discard-proposal'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.discardProposal();
            },
            child: const Text('버리기'),
          ),
        ],
      );
    },
  );
}

String _countNote(DayPlan? day, {required bool short}) {
  final counts = dayCounts(day);
  if (counts.items == 0) return '일정 없음';
  final base = short ? '${counts.items}개' : '일정 ${counts.items}개';
  return counts.pinned == 0 ? base : '$base · 고정 ${counts.pinned}';
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
          final selected = sameDay(day, controller.planDate(trip));
          final today = sameDay(day, controller.now);
          return DateToken(
            key: Key('date-chip-${day.month}-${day.day}'),
            label: '${day.month}.${day.day} ${today ? '오늘' : weekdayKo(day)}',
            note: _countNote(dayFor(controller.visibleDays(trip), day), short: true),
            selected: selected,
            width: 100,
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
        final selected = sameDay(day, controller.planDate(trip));
        final today = sameDay(day, controller.now);
        return DateRailTile(
          key: Key('date-rail-${day.month}-${day.day}'),
          label: formatMonthDay(day),
          note: '${today ? '${weekdayKo(day)} · 오늘' : weekdayKo(day)} · ${_countNote(dayFor(controller.visibleDays(trip), day), short: false)}',
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
            children: [
              if (trip.activeDays.isEmpty && !controller.reviewingProposal)
                const QuietEmpty(
                  key: Key('itinerary-none'),
                  title: '아직 일정이 없습니다.',
                  message: '일정 만들기를 누르면 적용하기 전에 제안을 먼저 보여 줍니다.',
                  icon: CupertinoIcons.calendar,
                )
              else
                QuietEmpty(
                  key: const Key('itinerary-day-empty'),
                  message: controller.reviewingProposal ? '이 날짜에는 제안된 일정이 없습니다.' : '이 날짜에는 적용된 일정이 없습니다.',
                ),
            ],
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
      return const EmptyPane(title: '일정 항목', message: '일정을 고르세요.');
    }
    final place = controller.placeById(item.placeId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        ScheduleBlock(item: item, proposal: controller.reviewingProposal),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('item-lock'),
                label: item.locked ? '고정 해제' : '고정',
                filled: false,
                selected: item.locked,
                onPressed: () => controller.toggleLock(item.id),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: AppButton(
                key: const Key('item-delete'),
                label: controller.reviewingProposal ? '제안에서 빼기' : '일정에서 삭제',
                filled: false,
                destructive: true,
                onPressed: () => _confirmDelete(context, controller, item),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.locked ? '고정한 항목은 새로 제안받아도 이 날짜, 이 시각에 그대로 남습니다.' : '고정하면 새로 제안받아도 이 항목이 같은 시각에 남습니다.',
          key: const Key('item-lock-note'),
          style: AppType.footnote,
        ),
        if (place != null) ...[
          const SizedBox(height: 16),
          PlacePanel(place: place, shrinkWrap: true),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, TripController controller, PlanItem item) {
    final proposal = controller.reviewingProposal;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('‘${item.title}’ 항목을 ${proposal ? '제안에서 뺄까요?' : '일정에서 삭제할까요?'}', style: AppType.headline),
          content: Text(proposal ? '적용하지 않은 제안에서만 빠집니다. 새로 제안받아도 다시 넣지 않습니다.' : '이 날짜의 일정에서 지워집니다. 되돌릴 수 없습니다.', style: AppType.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            TextButton(
              key: const Key('confirm-delete-item'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(dialogContext);
                controller.deleteItem(item.id);
              },
              child: Text(proposal ? '빼기' : '삭제'),
            ),
          ],
        );
      },
    );
  }
}
