import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
import '../format.dart';
import '../logic/schedule.dart';
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
      key: Key(pane == FactPane.facts
          ? 'place-facts'
          : pane == FactPane.sources
              ? 'place-sources'
              : 'place-combined'),
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
          Row(
            children: [
              IconButton(
                key: const Key('place-save'),
                tooltip: '관심 저장',
                onPressed: () => controller.toggleSaved(place.id),
                icon: Icon(
                  link.saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: link.saved ? AppColors.danger : AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: AppButton(
                  key: const Key('place-add-schedule'),
                  label: '일정에 추가',
                  onPressed: place.suspended
                      ? null
                      : () => _ScheduleDateSheet.open(context, place: place),
                ),
              ),
              IconButton(
                key: const Key('place-exclude'),
                tooltip: link.decision == Decision.excluded ? '제외 해제' : '일정 제안에서 제외',
                onPressed: () => controller.setDecision(place.id, link.decision == Decision.excluded ? Decision.none : Decision.excluded),
                icon: Icon(
                  CupertinoIcons.ellipsis_circle,
                  color: link.decision == Decision.excluded ? AppColors.danger : AppColors.secondary,
                ),
              ),
            ],
          ),
          if (link.saved) ...[
            const SizedBox(height: AppSpace.xxs),
            const Text('이 여행에 저장됨', style: AppType.footnote),
          ],
          if (link.decision == Decision.excluded) ...[
            const SizedBox(height: AppSpace.xxs),
            const Text('일정 자동 제안에서 빠집니다', style: AppType.footnote),
          ],
          Builder(
            builder: (context) {
              final scheduled = controller.scheduledDaysFor(place.id);
              if (scheduled.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Text(scheduleDaysLabel(scheduled), style: AppType.footnoteStrong),
              );
            },
          ),
          const SizedBox(height: AppSpace.md),
        ],
        for (final field in factFieldOrder) _FactBlock(field: field, claims: place.claimsFor(field), showValue: showFacts || showSources, showSources: showSources),
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

class _ScheduleDateSheet extends StatelessWidget {
  const _ScheduleDateSheet({required this.place});

  final Place place;

  static Future<void> open(BuildContext context, {required Place place}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ScheduleDateSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current!;
    final days = tripDays(trip);
    final scheduled = controller.scheduledDaysFor(place.id).toSet();
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.55;
    return SafeArea(
      child: SizedBox(
        key: const Key('schedule-date-sheet'),
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${place.name} · 날짜 고르기', style: AppType.headline),
              const SizedBox(height: AppSpace.xs),
              const Text('고른 날짜의 적용된 일정에 바로 넣습니다. 새로 제안받으면 빈 시간을 채웁니다.', style: AppType.footnote),
              const SizedBox(height: AppSpace.sm),
              Expanded(
                child: ListView(
                  children: [
                    for (final day in days)
                      ListTile(
                      key: Key('schedule-pick-${day.month}-${day.day}'),
                      enabled: !scheduled.contains(dateOnly(day)),
                      title: Text('${formatDot(day)} (${weekdayKo(day)})', style: AppType.body),
                      subtitle: scheduled.contains(dateOnly(day))
                          ? const Text('이미 일정에 있음', style: AppType.footnote)
                          : Text(trip.cityOn(day)?.name ?? '도시 미배정', style: AppType.footnote),
                      trailing: const Icon(CupertinoIcons.plus_circle, color: AppColors.accent),
                      onTap: scheduled.contains(dateOnly(day))
                          ? null
                          : () {
                              final error = controller.addPlaceToSchedule(place.id, day);
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                                return;
                              }
                              Navigator.pop(context);
                            },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Text(open ? '$title · 접기' : title, style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
          ),
          if (open)
            Text(
              widget.offline ? '연결이 없어 좌표, 주소, 영업시간을 다시 받지 않습니다. 화면에 있는 값은 마지막으로 이 기기에 둔 자료입니다.' : '좌표와 주소, 영업시간은 앱에 넣어 둔 예시입니다. 오늘 문을 여는지, 가격, 예약은 이 화면이 보증하지 않습니다.',
              style: AppType.footnote,
            ),
        ],
      ),
    );
  }
}
