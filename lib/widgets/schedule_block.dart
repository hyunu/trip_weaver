import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../theme/app_theme.dart';

class ScheduleBlock extends StatelessWidget {
  const ScheduleBlock({super.key, required this.item, this.emphasize = false, this.proposal = false, this.selected = false, this.onTap});

  final PlanItem item;
  final bool emphasize;
  final bool proposal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(item.kind);
    return Material(
      color: tone.background,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          key: Key('item-${item.id}'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: selected ? AppColors.accent : tone.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KindChip(label: kindLabel(item.kind), foreground: tone.foreground, background: tone.chip),
                  if (proposal) ...[
                    const SizedBox(width: AppSpace.xs),
                    const _KindChip(label: '제안', foreground: AppColors.warningFg, background: AppColors.markerBg),
                  ],
                  if (item.categoryLabel != null) ...[
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.categoryLabel!, style: AppType.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (item.locked)
                    Padding(
                      key: Key('item-pinned-${item.id}'),
                      padding: const EdgeInsets.only(left: AppSpace.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.pin_fill, size: 12, color: AppColors.accent),
                          const SizedBox(width: 2),
                          Text('고정', style: AppType.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              if (item.unconfirmedFields.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                _Marker(label: '미확인 값', detail: item.unconfirmedFields.join(' · '), foreground: AppColors.warningFg, background: AppColors.markerBg),
              ],
              if (item.hoursConflict) ...[
                const SizedBox(height: AppSpace.xs),
                const _Marker(label: '충돌', detail: '운영시간', foreground: AppColors.conflictFg, background: AppColors.conflictBg),
              ],
              const SizedBox(height: AppSpace.xs),
              Text(itemTimeLabel(item), style: AppType.footnote),
              if (item.title.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(item.title, style: emphasize ? AppType.cardTitle : AppType.headline),
              ],
              for (final warning in item.warnings) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(warningLabel(warning), style: AppType.footnote.copyWith(color: AppColors.warningFg)),
              ],
              if (item.note != null) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(item.note!, style: AppType.footnote),
              ],
              if (item.dwellIsProposal && !item.locked) ...[
                const SizedBox(height: AppSpace.xxs),
                const Text('체류 시간은 제안값입니다.', style: AppType.footnote),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.foreground, required this.background});

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.chip)),
      child: Text(label, style: AppType.caption.copyWith(color: foreground, fontWeight: FontWeight.w600)),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.label, required this.detail, required this.foreground, required this.background});

  final String label;
  final String detail;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 3),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.chip)),
          child: Text(label, style: AppType.caption.copyWith(color: foreground, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(detail, style: AppType.footnote.copyWith(color: foreground)),
          ),
        ),
      ],
    );
  }
}

class _Tone {
  const _Tone(this.background, this.foreground, this.chip, this.border);

  final Color background;
  final Color foreground;
  final Color chip;
  final Color border;
}

_Tone _tone(ItemKind kind) {
  switch (kind) {
    case ItemKind.move:
      return const _Tone(Color(0xFFF7FAFC), AppColors.move, AppColors.moveBg, AppColors.line);
    case ItemKind.stay:
      return const _Tone(Colors.white, AppColors.stay, AppColors.accentSoft, AppColors.line);
    case ItemKind.meal:
      return const _Tone(Color(0xFFFFF9F6), AppColors.meal, AppColors.mealBg, AppColors.line);
    case ItemKind.rest:
      return const _Tone(Color(0xFFF8F7F4), AppColors.rest, AppColors.restBg, AppColors.line);
    case ItemKind.gap:
      return const _Tone(AppColors.warningBg, AppColors.warningFg, AppColors.markerBg, AppColors.markerBg);
  }
}
