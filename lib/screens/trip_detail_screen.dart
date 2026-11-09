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

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  static const _maxWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const EmptyPane(title: '여행', message: '여행을 고르세요.');
    final next = controller.destinationFor(trip);
    final total = trip.companionCount + 1;
    final unconfirmed = trip.cities.where((city) => !city.coordinateConfirmed).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - _maxWidth) / 2).clamp(AppSpace.page, double.infinity);
        return ListView(
          key: const Key('trip-detail-scroll'),
          padding: EdgeInsets.fromLTRB(side, AppSpace.xs, side, AppSpace.lg),
          children: [
            if (onClose != null) BackRow(onPressed: onClose!),
            Text(displayTitle(trip.title), style: AppType.title),
            const SizedBox(height: AppSpace.xxs),
            Text('${statusLabel(trip.status)} · ${trip.countryCode} ${trip.countryName}', style: AppType.footnote),
            const SizedBox(height: AppSpace.xxs),
            Text(formatRange(trip.start, trip.end), style: AppType.body),
            if (trip.pendingLocalEdits > 0) ...[
              const SizedBox(height: AppSpace.xxs),
              Text('이 기기에만 있는 수정 ${trip.pendingLocalEdits}건', style: AppType.footnote),
            ],
            const SectionLabel('다음 일정'),
            if (next == null)
              Text(trip.activeDays.isEmpty ? '적용된 일정이 없습니다.' : nextScheduleLine(trip, controller.now), style: AppType.body)
            else
              ScheduleBlock(item: next),
            const SizedBox(height: AppSpace.sm),
            AppButton(
              key: const Key('detail-open-itinerary'),
              label: trip.activeDays.isEmpty ? '일정 만들러 가기' : '일정 보기',
              filled: trip.activeDays.isEmpty,
              onPressed: () {
                if (controller.currentTripId != trip.id) controller.selectTrip(trip.id);
                controller.selectTab(2);
              },
            ),
            const SectionLabel('목적'),
            Text(trip.purpose.isEmpty ? '없음' : trip.purpose, style: AppType.body),
            const SectionLabel('취향'),
            if (trip.tasteTags.isEmpty)
              const Text('없음', style: AppType.body)
            else
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  for (final tag in trip.tasteTags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadii.chip)),
                      child: Text(tag, style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
                    ),
                ],
              ),
            const SectionLabel('예산'),
            Text(moneyLabel(trip.budgetAmount, trip.budgetCurrency), style: AppType.body),
            const SectionLabel('동행'),
            const Text('동행 인원 (본인 제외)', style: AppType.footnote),
            const SizedBox(height: 2),
            Text('${trip.companionCount}명 · 본인 포함 총 $total명', key: const Key('detail-companions'), style: AppType.body),
            SectionLabel('도시 ${trip.cities.length}곳'),
            if (trip.cities.isEmpty) const Text('도시가 없습니다.', style: AppType.body),
            for (final city in trip.cities) _CityRow(tripId: trip.id, city: city),
            if (unconfirmed > 0) ...[
              Text('위치가 확인되지 않은 도시 $unconfirmed곳은 탐색과 지도에 나오지 않습니다.', style: AppType.footnote),
              const SizedBox(height: AppSpace.xs),
              AppButton(
                key: const Key('detail-confirm-cities'),
                label: '도시 위치 확인',
                filled: false,
                onPressed: () {
                  if (controller.currentTripId != trip.id) controller.selectTrip(trip.id);
                  controller.openCityEdit();
                  controller.selectTab(1);
                },
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            AppButton(
              key: const Key('detail-delete-trip'),
              label: '여행 삭제',
              filled: false,
              destructive: true,
              onPressed: () => _confirmDelete(context, controller, trip),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, TripController controller, Trip trip) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text('‘${displayTitle(trip.title)}’ 여행을 삭제할까요?', style: AppType.headline),
          content: const Text('일정과 장소 선택이 이 기기에서 함께 지워집니다. 되돌릴 수 없습니다.', style: AppType.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            TextButton(
              key: const Key('confirm-delete-trip'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(dialogContext);
                controller.deleteTrip(trip.id);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.tripId, required this.city});

  final String tripId;
  final City city;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: AppDecor.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${city.name} · ${city.countryCode}', style: AppType.headline),
            const SizedBox(height: 2),
            Text(formatRange(city.start, city.end), style: AppType.footnote),
            const SizedBox(height: AppSpace.xxs),
            if (!city.coordinateConfirmed)
              Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, size: 16, color: AppColors.warningFg),
                  const SizedBox(width: AppSpace.xxs),
                  Expanded(child: Text('도시 위치가 확인되지 않았습니다.', style: AppType.footnoteStrong.copyWith(color: AppColors.warningFg))),
                ],
              )
            else ...[
              Text('좌표 ${city.coordinateLabel}', style: AppType.body),
              Text('출처 ${city.coordinateSource}', style: AppType.footnote),
              const SizedBox(height: AppSpace.xs),
              AppButton(
                key: Key('detail-relocate-${city.id}'),
                label: '위치 다시 고르기',
                filled: false,
                onPressed: () {
                  final controller = TripScope.of(context);
                  if (controller.currentTripId != tripId) controller.selectTrip(tripId);
                  controller.openCityEdit();
                  controller.selectTab(1);
                  controller.startRelocate(city.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
