import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import 'chrome.dart';

enum FactPane { combined, facts, sources }

class PlacePanel extends StatelessWidget {
  const PlacePanel({super.key, required this.place, this.pane = FactPane.combined, this.onClose, this.shrinkWrap = false});

  final Place place;
  final FactPane pane;
  final VoidCallback? onClose;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final link = controller.linkFor(place.id);
    final showFacts = pane != FactPane.sources;
    final showSources = pane != FactPane.facts;
    return ListView(
      key: Key(pane == FactPane.facts ? 'place-facts' : pane == FactPane.sources ? 'place-sources' : 'place-combined'),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        if (showFacts) ...[
          Text(place.name, key: const Key('place-name'), style: AppType.title),
          const SizedBox(height: 4),
          Text(place.localName ?? '현지어 이름 미확인', style: AppType.footnote),
          const SizedBox(height: 4),
          Text(categoryLabel(place.category), style: AppType.footnoteStrong),
          SampleBanner(visible: place.dataOriginMock),
          if (place.suspended) ...[
            const SizedBox(height: 12),
            const Text('이 장소는 일정 자동 생성에서 빠집니다.', style: AppType.body),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: '관심 저장',
            filled: link.saved,
            onPressed: () => controller.toggleSaved(place.id),
          ),
          if (link.saved) ...[
            const SizedBox(height: 4),
            const Text('이 여행에 저장됨', style: AppType.footnote),
          ],
          const SizedBox(height: 8),
          AppButton(
            label: '일정에 선택',
            filled: link.decision == Decision.selected,
            onPressed: () => controller.setDecision(place.id, Decision.selected),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: link.decision == Decision.excluded ? '제외됨' : '제외',
            filled: link.decision == Decision.excluded,
            onPressed: () => controller.setDecision(place.id, link.decision == Decision.excluded ? Decision.none : Decision.excluded),
          ),
          const SizedBox(height: 16),
        ],
        for (final field in factFieldOrder)
          _FactBlock(field: field, claims: place.claimsFor(field), showValue: showFacts || showSources, showSources: showSources),
        if (showSources) ...[
          const SectionLabel('후기'),
          const Text('후기 자료가 연결되지 않았습니다.', style: AppType.body),
        ],
        if (showFacts) ...[
          const SizedBox(height: 16),
          AppButton(label: '자료 다시 확인', filled: false, onPressed: () => controller.requestVerification(place.id)),
          if (controller.verificationNotes[place.id] != null) ...[
            const SizedBox(height: 8),
            Text(controller.verificationNotes[place.id]!, style: AppType.footnote),
          ],
          if (place.category == PlaceCategory.restaurant) ...[
            const SectionLabel('주문에 쓸 문장'),
            const Text('메뉴가 확인되지 않아 메뉴 이름을 넣지 않습니다.', style: AppType.body),
            if (place.aiOrderSentence != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE8EEF4), borderRadius: BorderRadius.circular(6)),
                      child: const Text('AI 문구', style: AppType.footnoteStrong),
                    ),
                    const SizedBox(height: 6),
                    Text(place.aiOrderSentence!, style: AppType.body),
                    const SizedBox(height: 4),
                    const Text('이 문장은 사실이 아닙니다.', style: AppType.footnote),
                  ],
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

class _FactBlock extends StatelessWidget {
  const _FactBlock({required this.field, required this.claims, required this.showValue, required this.showSources});

  final String field;
  final List<Claim> claims;
  final bool showValue;
  final bool showSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fieldLabel(field), style: AppType.footnoteStrong),
          const SizedBox(height: 6),
          if (claims.isEmpty && showValue) ...[
            const FactBadge(FactValidity.unknown),
            const SizedBox(height: 4),
            const Text('확인되지 않음', style: AppType.body),
          ],
          for (final claim in claims) ...[
            if (showValue) ...[
              FactBadge(claim.validity),
              const SizedBox(height: 4),
              Text(claim.value ?? '확인되지 않음', style: AppType.body),
            ],
            if (showSources) ...[
              const SizedBox(height: 4),
              Text('출처 종류 ${sourceKindLabel(claim.sourceKind)}', style: AppType.footnote),
              Text('출처 ${claim.sourceName}', style: AppType.footnote),
              Text(claim.sourceUrl == null ? 'URL 없음' : claim.sourceUrl!, style: AppType.footnote),
              Text('수집 ${formatStamp(claim.collectedAt)}', style: AppType.footnote),
              Text('검증 ${formatStamp(claim.verifiedAt)}', style: AppType.footnote),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
