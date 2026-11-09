import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class CityEditScreen extends StatelessWidget {
  const CityEditScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const EmptyPane(title: '도시', message: '여행을 고르세요.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        const Text('도시', style: AppType.title),
        const SizedBox(height: 8),
        Text(trip.title, style: AppType.footnote),
        const SizedBox(height: 12),
        for (final city in trip.cities) _CityEditor(city: city),
      ],
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
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${city.name} · ${city.countryCode}', style: AppType.headline),
          const SizedBox(height: 2),
          Text(formatRange(city.start, city.end), style: AppType.footnote),
          const SizedBox(height: 8),
          if (city.coordinateConfirmed) ...[
            Text('좌표 ${city.coordinateLabel}', style: AppType.body),
            Text('출처 ${city.coordinateSource}', style: AppType.footnote),
          ] else ...[
            const Text('도시 위치가 확인되지 않았습니다.', style: AppType.body),
            const SizedBox(height: 8),
            AppButton(
              label: '위치 후보 찾기',
              onPressed: controller.offline ? null : () => controller.findCandidates(city.id),
            ),
            if (controller.offline) ...[
              const SizedBox(height: 4),
              const Text('오프라인이라 위치 후보를 찾지 않습니다.', style: AppType.footnote),
            ],
            if (candidates != null && candidates.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('위치 후보가 없습니다.', style: AppType.body),
            ],
            if (candidates != null && candidates.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('하나를 고르기 전에는 좌표를 저장하지 않습니다.', style: AppType.footnote),
              for (final candidate in candidates)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppButton(
                    label: '${candidate.label} · ${candidate.sourceName}',
                    filled: false,
                    onPressed: () => controller.pickCandidate(city.id, candidate),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
