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

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const EmptyPane(title: '여행', message: '여행을 고르세요.');
    final next = controller.destinationFor(trip);
    final total = trip.companionCount + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        Text(trip.title, style: AppType.title),
        const SizedBox(height: 4),
        Text('${statusLabel(trip.status)} · ${trip.countryCode} ${trip.countryName}', style: AppType.footnote),
        const SizedBox(height: 4),
        Text(formatRange(trip.start, trip.end), style: AppType.body),
        const SizedBox(height: 12),
        const Text('다음 행동', style: AppType.footnoteStrong),
        const SizedBox(height: 8),
        if (next == null)
          Text(trip.activeDays.isEmpty ? '적용된 일정이 없습니다.' : nextScheduleLine(trip, controller.now), style: AppType.body)
        else
          ScheduleBlock(item: next),
        if (trip.pendingLocalEdits > 0) ...[
          const SizedBox(height: 8),
          Text('이 기기에만 있는 수정 ${trip.pendingLocalEdits}건', style: AppType.footnote),
        ],
        const SectionLabel('목적'),
        Text(trip.purpose.isEmpty ? '없음' : trip.purpose, style: AppType.body),
        const SectionLabel('취향'),
        if (trip.tasteTags.isEmpty)
          const Text('없음', style: AppType.body)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
        Text('${trip.companionCount}', style: AppType.body),
        const SizedBox(height: 2),
        Text('총인원은 이 숫자에 본인을 더합니다. 총인원 $total명.', style: AppType.footnote),
        const SectionLabel('도시'),
        for (final city in trip.cities) _CityRow(city: city),
        const SizedBox(height: 20),
        AppButton(
          label: '이 여행을 삭제합니다.',
          filled: false,
          destructive: true,
          onPressed: () => _confirmDelete(context, controller, trip.id),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, TripController controller, String id) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('이 여행을 삭제합니다.', style: AppType.headline),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소', style: AppType.headline)),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                controller.deleteTrip(id);
              },
              child: const Text('삭제', style: AppType.headline),
            ),
          ],
        );
      },
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city});

  final City city;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: AppDecor.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${city.name} · ${city.countryCode}', style: AppType.headline),
            const SizedBox(height: 2),
            Text(formatRange(city.start, city.end), style: AppType.footnote),
            const SizedBox(height: 4),
            if (!city.coordinateConfirmed)
              const Text('도시 위치가 확인되지 않았습니다.', style: AppType.body)
            else ...[
              Text('좌표 ${city.coordinateLabel}', style: AppType.body),
              Text('출처 ${city.coordinateSource}', style: AppType.footnote),
            ],
          ],
        ),
      ),
    );
  }
}
