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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: Key('item-${item.id}'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proposal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('제안', style: AppType.footnoteStrong.copyWith(color: AppColors.warningFg)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KindChip(label: kindLabel(item.kind), foreground: tone.foreground, background: tone.chip),
                  if (item.categoryLabel != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.categoryLabel!, style: AppType.footnote))),
                  ] else
                    const Spacer(),
                  if (item.locked) Text('고정', style: AppType.footnoteStrong.copyWith(color: AppColors.accent)),
                ],
              ),
              if (item.unconfirmedFields.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Marker(label: '미확인 값', detail: item.unconfirmedFields.join(' · '), foreground: AppColors.warningFg, background: const Color(0xFFF3E0B8)),
              ],
              if (item.hoursConflict) ...[
                const SizedBox(height: 6),
                const _Marker(label: '충돌', detail: '운영시간', foreground: AppColors.conflictFg, background: AppColors.conflictBg),
              ],
              const SizedBox(height: 6),
              Text(itemTimeLabel(item), style: AppType.footnote),
              if (item.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.title, style: emphasize ? AppType.title : AppType.headline),
              ],
              for (final warning in item.warnings) ...[
                const SizedBox(height: 4),
                Text(warningLabel(warning), style: AppType.footnote.copyWith(color: AppColors.warningFg)),
              ],
              if (item.note != null) ...[const SizedBox(height: 4), Text(item.note!, style: AppType.footnote)],
              if (item.dwellIsProposal) ...[const SizedBox(height: 4), const Text('체류 시간은 제안값입니다.', style: AppType.footnote)],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: AppType.footnoteStrong.copyWith(color: foreground)),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: AppType.footnoteStrong.copyWith(color: foreground)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(detail, style: AppType.footnote.copyWith(color: foreground)))),
      ],
    );
  }
}

class _Tone {
  const _Tone(this.background, this.foreground, this.chip);

  final Color background;
  final Color foreground;
  final Color chip;
}

_Tone _tone(ItemKind kind) {
  switch (kind) {
    case ItemKind.move:
      return const _Tone(Color(0xFFF7FAFC), AppColors.move, AppColors.moveBg);
    case ItemKind.stay:
      return const _Tone(Colors.white, AppColors.stay, AppColors.accentSoft);
    case ItemKind.meal:
      return const _Tone(Color(0xFFFFF9F6), AppColors.meal, AppColors.mealBg);
    case ItemKind.rest:
      return const _Tone(Color(0xFFF8F7F4), AppColors.rest, AppColors.restBg);
    case ItemKind.gap:
      return const _Tone(AppColors.warningBg, AppColors.warningFg, Color(0xFFF3E0B8));
  }
}
