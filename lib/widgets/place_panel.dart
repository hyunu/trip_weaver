import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
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
      padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.xs, AppSpace.page, AppSpace.lg),
      children: [
        if (onClose != null) BackRow(onPressed: onClose!),
        if (!showFacts && showSources) ...[
          const Text('출처', style: AppType.title),
          const SizedBox(height: AppSpace.xxs),
          Text(place.name, style: AppType.headline),
          const SizedBox(height: AppSpace.md),
        ],
        if (showFacts) ...[
          Text(place.name, key: const Key('place-name'), style: AppType.title),
          const SizedBox(height: AppSpace.xxs),
          Text(place.localName ?? '현지어 이름 미확인', style: AppType.footnote),
          const SizedBox(height: AppSpace.xxs),
          Text(categoryLabel(place.category), style: AppType.section.copyWith(color: AppColors.ink)),
          _SampleLimit(place: place, offline: controller.offline),
          if (placeSuggestion(place.id) != null) ...[
            const SizedBox(height: AppSpace.sm),
            const Text('이 여행에 넣은 이유', style: AppType.footnoteStrong),
            const SizedBox(height: AppSpace.xxs),
            Text(placeSuggestion(place.id)!, style: AppType.body),
          ],
          if (place.suspended) ...[
            const SizedBox(height: AppSpace.sm),
            const NoticeBanner(
              message: '이 장소는 일정 자동 생성에서 빠집니다.',
              background: AppColors.warningBg,
              foreground: AppColors.warningFg,
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: '관심 저장',
            filled: false,
            selected: link.saved,
            onPressed: () => controller.toggleSaved(place.id),
          ),
          if (link.saved) ...[
            const SizedBox(height: AppSpace.xxs),
            const Text('이 여행에 저장됨', style: AppType.footnote),
          ],
          const SizedBox(height: AppSpace.xs),
          AppButton(
            label: '일정에 선택',
            filled: link.decision != Decision.selected,
            selected: link.decision == Decision.selected,
            onPressed: () => controller.setDecision(place.id, Decision.selected),
          ),
          const SizedBox(height: AppSpace.xs),
          AppButton(
            label: link.decision == Decision.excluded ? '제외됨' : '제외',
            filled: false,
            destructive: true,
            selected: link.decision == Decision.excluded,
            onPressed: () => controller.setDecision(place.id, link.decision == Decision.excluded ? Decision.none : Decision.excluded),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        for (final field in factFieldOrder)
          _FactBlock(field: field, claims: place.claimsFor(field), showValue: showFacts || showSources, showSources: showSources),
        if (showSources) ...[
          const SectionLabel('후기'),
          Text(
            place.dataOriginMock ? '샘플에는 후기 원문이 없습니다. 별점이나 문장으로 이 장소를 앞세우지 않습니다.' : '후기 자료가 연결되지 않았습니다.',
            style: AppType.body,
          ),
          const SizedBox(height: AppSpace.xs),
          AppButton(label: '후기는 나중에 확인', filled: false, onPressed: () => controller.requestVerification(place.id)),
        ],
        if (showFacts) ...[
          const SizedBox(height: AppSpace.md),
          AppButton(label: '자료 다시 확인', filled: false, onPressed: () => controller.requestVerification(place.id)),
          if (controller.verificationNotes[place.id] != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(controller.verificationNotes[place.id]!, style: AppType.footnote),
          ],
          if (place.category == PlaceCategory.restaurant) ...[
            const SectionLabel('주문에 쓸 문장'),
            const Text('메뉴가 확인되지 않아 메뉴 이름을 넣지 않습니다.', style: AppType.body),
            if (place.aiOrderSentence != null) ...[
              const SizedBox(height: AppSpace.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: AppDecor.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.moveBg, borderRadius: BorderRadius.circular(AppRadii.chip)),
                      child: Text('AI 문구', style: AppType.caption.copyWith(color: AppColors.move, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(place.aiOrderSentence!, style: AppType.body),
                    const SizedBox(height: AppSpace.xxs),
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
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fieldLabel(field), style: AppType.section.copyWith(color: AppColors.ink)),
          const SizedBox(height: AppSpace.xs),
          if (claims.isEmpty && showValue) ...[
            const FactBadge(FactValidity.unknown),
            const SizedBox(height: AppSpace.xxs),
            const Text('확인되지 않음', style: AppType.body),
          ],
          for (final claim in claims) ...[
            if (showValue) ...[
              FactBadge(claim.validity),
              const SizedBox(height: AppSpace.xxs),
              Text(claim.value ?? '확인되지 않음', style: AppType.body),
            ],
            if (showSources) ...[
              const SizedBox(height: AppSpace.xxs),
              Text('출처 종류 ${sourceKindLabel(claim.sourceKind)}', style: AppType.caption),
              Text('출처 ${claim.sourceName}', style: AppType.caption),
              Text(claim.sourceUrl == null ? 'URL 없음' : claim.sourceUrl!, style: AppType.caption),
              Text('수집 ${formatStamp(claim.collectedAt)}', style: AppType.caption),
              Text('검증 ${formatStamp(claim.verifiedAt)}', style: AppType.caption),
            ],
            const SizedBox(height: AppSpace.xs),
          ],
        ],
      ),
    );
  }
}

class _SampleLimit extends StatefulWidget {
  const _SampleLimit({required this.place, required this.offline});

  final Place place;
  final bool offline;

  @override
  State<_SampleLimit> createState() => _SampleLimitState();
}

class _SampleLimitState extends State<_SampleLimit> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.place.dataOriginMock && !widget.offline) return const SizedBox.shrink();
    final title = widget.offline ? '오프라인 · 이 화면의 자료만' : '샘플 장소 · 한계 보기';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            key: const Key('place-sample-limit'),
            onPressed: () => setState(() => open = !open),
            style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Text(open ? '$title · 접기' : title, style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
          ),
          if (open)
            Text(
              widget.offline
                  ? '연결이 없어 좌표, 주소, 영업시간을 다시 받지 않습니다. 화면에 있는 값은 마지막으로 이 기기에 둔 자료입니다.'
                  : '좌표와 주소, 영업시간은 앱에 넣어 둔 예시입니다. 오늘 문을 여는지, 가격, 예약은 이 화면이 보증하지 않습니다.',
              style: AppType.footnote,
            ),
        ],
      ),
    );
  }
}
