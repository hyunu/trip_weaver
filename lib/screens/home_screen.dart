import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/schedule_block.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final mine = controller.userTrips;
    final samples = controller.sampleTrips;
    if (mine.isEmpty && samples.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FillOrScroll(
          children: [
            const PageHeader(title: '여행', titleKey: Key('screen-title-home')),
            const Expanded(child: Center(child: QuietEmpty(title: '여행이 없습니다.', message: '날짜와 도시를 정하면 이 목록에 나타납니다.', icon: CupertinoIcons.airplane))),
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: AppButton(key: const Key('create-trip'), label: '여행 만들기', onPressed: controller.openCreate))),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    return ScrollHost(
      id: 'home',
      builder: (context, scroll) {
        return ListView(
          key: const Key('home-scroll'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(child: PageHeader(title: '여행', titleKey: Key('screen-title-home'))),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(key: const Key('create-trip'), label: '새 여행', filled: false, onPressed: controller.openCreate),
                  ),
                ),
              ],
            ),
            StatusBanners(sample: controller.homeShowsSample, offline: controller.offline),
            if (mine.isNotEmpty) ..._TripSections(trips: mine, tablet: tablet, now: controller.now),
            if (samples.isNotEmpty) ...[
              Row(
                children: [
                  const Expanded(child: SectionLabel('샘플 여행')),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('hide-all-samples'),
                        onPressed: controller.hideAllSamples,
                        child: const Text('샘플 모두 숨기기'),
                      ),
                    ),
                  ),
                ],
              ),
              Text('데모용입니다. 내 여행과 별도로 보여 주며 저장 파일에는 남지 않습니다.', style: AppType.footnote.copyWith(color: AppColors.secondary)),
              const SizedBox(height: AppSpace.xs),
              ..._TripSections(trips: samples, tablet: tablet, now: controller.now, sampleStyle: true),
            ],
          ],
        );
      },
    );
  }
}

List<Widget> _TripSections({required List<Trip> trips, required bool tablet, required DateTime now, bool sampleStyle = false}) {
  final ongoing = trips.where((trip) => isOngoing(trip, now)).toList();
  final upcoming = trips.where((trip) => !isOngoing(trip, now) && !isPast(trip, now)).toList();
  final nextTrip = ongoing.isEmpty ? nearestUpcomingTrip(trips, now) : null;
  final past = trips.where((trip) => isPast(trip, now)).toList();
  return [
    if (nextTrip != null) _NextTripCountdownCard(trip: nextTrip, tablet: tablet),
    if (ongoing.isNotEmpty) ...[
      const SectionLabel('진행 중'),
      _HeroCard(trip: ongoing.first, tablet: tablet),
      for (final trip in ongoing.skip(1)) _TripCard(trip: trip, tablet: tablet),
    ],
    if (upcoming.isNotEmpty) ...[
      const SectionLabel('예정'),
      for (final trip in upcoming) _TripCard(trip: trip, tablet: tablet),
    ],
    if (past.isNotEmpty) ...[
      const SectionLabel('지난 여행'),
      for (final trip in past) _TripCard(trip: trip, tablet: tablet),
    ],
  ];
}

class _NextTripCountdownCard extends StatelessWidget {
  const _NextTripCountdownCard({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final countdown = countdownToTrip(trip, controller.now);
    return _CardTap(
      key: const Key('next-trip-countdown'),
      selected: tablet && controller.currentTripId == trip.id,
      onTap: () => _openTrip(controller, trip, tablet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(countdown, key: const Key('next-trip-d-label'), style: AppType.title.copyWith(color: AppColors.accent)),
          const SizedBox(height: AppSpace.xxs),
          Text('다음 여행', style: AppType.footnoteStrong.copyWith(color: AppColors.secondary)),
          const SizedBox(height: AppSpace.xxs),
          Text(displayTitle(trip.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.headline),
          const SizedBox(height: 2),
          Text('${formatRange(trip.start, trip.end)} · ${formatMonthDay(trip.start)} 출발', style: AppType.footnote),
          const SizedBox(height: 2),
          Text(citySummary(trip), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.footnote),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final next = controller.destinationFor(trip);
    final selected = tablet && controller.currentTripId == trip.id;
    return _CardTap(
      key: Key('trip-card-${trip.id}'),
      selected: selected,
      onTap: () => _openTrip(controller, trip, tablet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(statusLabel(trip.status), style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
              const Spacer(),
              Text(trip.countryCode, style: AppType.footnoteStrong),
              if (!tablet) const _Chevron(),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(displayTitle(trip.title), key: const Key('hero-title'), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppType.title),
          const SizedBox(height: AppSpace.xxs),
          Text(formatRange(trip.start, trip.end), key: const Key('hero-period'), style: AppType.footnote),
          const SizedBox(height: 2),
          Text(citySummary(trip), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.footnote),
          const SizedBox(height: AppSpace.sm),
          const Text('다음 일정', style: AppType.section),
          const SizedBox(height: AppSpace.xs),
          if (next == null)
            Text(nextScheduleLine(trip, controller.now), style: AppType.body)
          else ...[
            ScheduleBlock(item: next),
            const SizedBox(height: AppSpace.xs),
            if (controller.showReferenceClock(trip))
              Text(
                '기준 시각 ${formatMonthDay(controller.now)} ${formatHm(controller.now)}${trip.dataOriginMock ? ' · 샘플' : ''}',
                style: AppType.footnote,
              ),
            if (controller.showReferenceClock(trip)) const SizedBox(height: AppSpace.xs),
            AppButton(
              key: const Key('hero-open-itinerary'),
              label: '일정에서 보기',
              onPressed: () {
                if (controller.currentTripId != trip.id) controller.selectTrip(trip.id);
                controller.reviewingProposal = false;
                controller.selectedDate = dateOnly(next.start ?? controller.now);
                controller.selectedItemId = next.id;
                controller.selectTab(2);
              },
            ),
          ],
        ],
      ),
    );
  }
}

void _openTrip(TripController controller, Trip trip, bool tablet) {
  if (tablet) {
    controller.selectTrip(trip.id);
  } else {
    controller.openHome(trip.id);
  }
}

class _CardTap extends StatelessWidget {
  const _CardTap({super.key, required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.card);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: AppColors.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 1.5 : 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpace.xxs),
      child: Icon(CupertinoIcons.chevron_forward, size: 16, color: AppColors.tertiary),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return _CardTap(
      key: Key('trip-card-${trip.id}'),
      selected: tablet && controller.currentTripId == trip.id,
      onTap: () => _openTrip(controller, trip, tablet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(displayTitle(trip.title), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppType.headline)),
              const SizedBox(width: AppSpace.xs),
              Text(statusLabel(trip.status), style: AppType.footnote),
              if (!tablet) const _Chevron(),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(formatRange(trip.start, trip.end), style: AppType.footnote),
          const SizedBox(height: 2),
          Text('${citySummary(trip)} · ${trip.countryCode}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.footnote),
          const SizedBox(height: 6),
          Text(nextScheduleLine(trip, controller.now), style: AppType.footnoteStrong),
        ],
      ),
    );
  }
}
