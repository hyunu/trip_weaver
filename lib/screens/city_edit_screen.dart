import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class CityEditScreen extends StatelessWidget {
  const CityEditScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  static const _maxWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const EmptyPane(title: '도시 위치', message: '여행을 고르세요.');
    final remaining = trip.cities.where((city) => !city.coordinateConfirmed).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - _maxWidth) / 2).clamp(AppSpace.page, double.infinity);
        return ListView(
          key: const Key('city-edit-scroll'),
          padding: EdgeInsets.fromLTRB(side, AppSpace.xs, side, AppSpace.lg),
          children: [
            if (onClose != null) BackRow(onPressed: onClose!),
            const Text('도시 위치', key: Key('screen-title-city-edit'), style: AppType.title),
            const SizedBox(height: AppSpace.xxs),
            Text(trip.title, style: AppType.footnote),
            const SizedBox(height: AppSpace.xs),
            Text(
              remaining == 0 ? '모든 도시의 위치가 확인되었습니다. 탐색과 지도에서 쓸 수 있습니다.' : '위치를 확인한 도시만 탐색과 지도에 나옵니다. 확인할 도시 $remaining곳.',
              key: const Key('city-edit-summary'),
              style: AppType.body.copyWith(color: AppColors.secondary),
            ),
            if (controller.offline) const OfflineBanner(visible: true),
            const SizedBox(height: AppSpace.sm),
            if (trip.cities.isEmpty) const QuietEmpty(message: '이 여행에는 도시가 없습니다.', icon: CupertinoIcons.map),
            for (final city in trip.cities) _CityEditor(city: city),
          ],
        );
      },
    );
  }
}

class _CityEditor extends StatelessWidget {
  const _CityEditor({required this.city});

  final City city;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final candidates = controller.cityCandidates[city.id];
    return Container(
      key: Key('city-editor-${city.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${city.name} · ${city.countryCode}', style: AppType.headline),
          const SizedBox(height: 2),
          Text(formatRange(city.start, city.end), style: AppType.footnote),
          const SizedBox(height: AppSpace.xs),
          if (city.coordinateConfirmed) ...[
            _Status(confirmed: true),
            const SizedBox(height: AppSpace.xxs),
            Text('좌표 ${city.coordinateLabel}', style: AppType.body),
            Text('출처 ${city.coordinateSource}', style: AppType.footnote),
          ] else ...[
            _Status(confirmed: false),
            const SizedBox(height: AppSpace.sm),
            AppButton(
              key: Key('find-candidates-${city.id}'),
              label: candidates == null ? '위치 후보 찾기' : '다시 찾기',
              filled: candidates == null,
              onPressed: controller.offline ? null : () => controller.findCandidates(city.id),
            ),
            if (controller.offline) ...[
              const SizedBox(height: AppSpace.xxs),
              const Text('오프라인이라 위치 후보를 찾지 않습니다.', style: AppType.footnote),
            ],
            if (candidates != null && candidates.isEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text('‘${city.name}’ 이름으로 찾은 위치 후보가 없습니다.', style: AppType.footnote),
            ],
            if (candidates != null && candidates.isNotEmpty) ...[
              const SectionLabel('후보를 하나 고르세요'),
              const Text('고르기 전에는 좌표를 저장하지 않습니다.', style: AppType.footnote),
              for (var index = 0; index < candidates.length; index++)
                _CandidateRow(
                  key: Key('candidate-${city.id}-$index'),
                  candidate: candidates[index],
                  onTap: () => controller.pickCandidate(city.id, candidates[index]),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final color = confirmed ? AppColors.accent : AppColors.warningFg;
    return Row(
      children: [
        Icon(confirmed ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_circle, size: 16, color: color),
        const SizedBox(width: AppSpace.xxs),
        Expanded(
          child: Text(
            confirmed ? '위치 확인됨' : '도시 위치가 확인되지 않았습니다.',
            style: AppType.footnoteStrong.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({super.key, required this.candidate, required this.onTap});

  final GeoCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.control);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Material(
        color: AppColors.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.label, style: AppType.headline),
                      const SizedBox(height: 2),
                      Text('${candidate.coordinateLabel} · ${candidate.sourceName}', style: AppType.footnote),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward, size: 16, color: AppColors.tertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
