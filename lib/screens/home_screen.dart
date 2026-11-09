import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/schedule_block.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    if (controller.trips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(title: '여행', titleKey: Key('screen-title-home')),
            const Expanded(child: Center(child: QuietEmpty(title: '여행이 없습니다.', message: '날짜와 도시를 정하면 이 목록에 나타납니다.', icon: CupertinoIcons.airplane))),
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: AppButton(label: '여행 만들기', onPressed: controller.openCreate))),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    final ongoing = controller.trips.where((trip) => isOngoing(trip, controller.now)).toList();
    final upcoming = controller.trips.where((trip) => !isOngoing(trip, controller.now) && !isPast(trip, controller.now)).toList();
    final past = controller.trips.where((trip) => isPast(trip, controller.now)).toList();
    return ScrollHost(
      id: 'home',
      builder: (context, scroll) {
        return ListView(
          key: const Key('home-scroll'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const PageHeader(title: '여행', titleKey: Key('screen-title-home')),
            StatusBanners(sample: controller.homeShowsSample, offline: controller.offline),
            if (ongoing.isNotEmpty) ...[
              const SectionLabel('진행 중'),
              _HeroCard(trip: ongoing.first),
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(key: const Key('create-trip'), label: '여행 만들기', onPressed: controller.openCreate),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final next = controller.destinationFor(trip);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(statusLabel(trip.status), style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
              const Spacer(),
              Text(trip.countryCode, style: AppType.footnoteStrong),
            ],
          ),
          const SizedBox(height: 4),
          Text(trip.title, key: const Key('hero-title'), style: AppType.title),
          const SizedBox(height: 4),
          Text(formatRange(trip.start, trip.end), key: const Key('hero-period'), style: AppType.footnote),
          const SizedBox(height: 2),
          Text('${trip.cities.map((city) => city.name).join(', ')} · 도시 ${trip.cities.length}곳', style: AppType.footnote),
          if (trip.pendingLocalEdits > 0) ...[
            const SizedBox(height: 2),
            Text('이 기기에만 있는 수정 ${trip.pendingLocalEdits}건', style: AppType.footnote),
          ],
          const SizedBox(height: 12),
          const Text('다음 행동', style: AppType.footnoteStrong),
          const SizedBox(height: 8),
          if (next == null)
            Text(nextScheduleLine(trip, controller.now), style: AppType.body)
          else ...[
            ScheduleBlock(item: next),
            const SizedBox(height: 8),
            Text('기준 시각 ${formatMonthDay(controller.now)} ${formatHm(controller.now)} · 샘플', style: AppType.footnote),
            const SizedBox(height: 8),
            AppButton(
              label: '일정에서 보기',
              onPressed: () {
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

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.tablet});

  final Trip trip;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final selected = controller.currentTripId == trip.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (tablet) {
              controller.selectTrip(trip.id);
            } else {
              controller.openHome(trip.id);
            }
          },
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
                  children: [
                    Expanded(child: Text(trip.title, style: AppType.headline)),
                    Text(statusLabel(trip.status), style: AppType.footnote),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formatRange(trip.start, trip.end), style: AppType.footnote),
                const SizedBox(height: 2),
                Text('${trip.cities.map((city) => city.name).join(', ')} · 도시 ${trip.cities.length}곳 · ${trip.countryCode}', style: AppType.footnote),
                const SizedBox(height: 6),
                Text(nextScheduleLine(trip, controller.now), style: AppType.footnoteStrong),
                if (trip.pendingLocalEdits > 0) ...[
                  const SizedBox(height: 2),
                  Text('이 기기에만 있는 수정 ${trip.pendingLocalEdits}건', style: AppType.footnote),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
