import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../model/journal.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const NeedTrip(title: '기록', titleKey: Key('screen-title-journal'));
    if (!tablet) {
      return ScrollHost(
        id: 'journal',
        builder: (context, scroll) {
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              PageHeader(title: '기록', titleKey: const Key('screen-title-journal'), subtitle: '${cityTripLabel(controller.selectedCity?.name, trip.title)} · ${formatRange(trip.start, trip.end)}'),
              StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
              const SizedBox(height: 12),
              _DateStrip(trip: trip),
              const SizedBox(height: 16),
              const _EmptyRecord(),
              const SizedBox(height: 12),
              const _RecordSections(),
            ],
          );
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: '기록', titleKey: const Key('screen-title-journal'), subtitle: '${cityTripLabel(controller.selectedCity?.name, trip.title)} · ${formatRange(trip.start, trip.end)}'),
              StatusBanners(sample: trip.dataOriginMock, offline: controller.offline),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Expanded(
          child: Row(
            children: [
              SizedBox(width: 360, child: _DateList()),
              VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EmptyRecord(),
                      SizedBox(height: 12),
                      _RecordSections(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final days = tripDays(trip);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = sameDay(day, controller.journalDate);
          final noted = controller.journalText(day) != null;
          return _DateChip(day: day, selected: selected, noted: noted, onTap: () => controller.selectJournalDate(day));
        },
      ),
    );
  }
}

class _DateList extends StatelessWidget {
  const _DateList();

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const SizedBox.shrink();
    final days = tripDays(trip);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final selected = sameDay(day, controller.journalDate);
        final noted = controller.journalText(day) != null;
        return InkWell(
          onTap: () => controller.selectJournalDate(day),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            color: selected ? AppColors.accentSoft : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatMonthDay(day), style: AppType.headline.copyWith(color: selected ? AppColors.accent : AppColors.ink)),
                Text(noted ? '기록 있음' : '기록 없음', style: AppType.footnote),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day, required this.selected, required this.noted, required this.onTap});

  final DateTime day;
  final bool selected;
  final bool noted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    final note = selected ? Colors.white : AppColors.secondary;
    return Material(
      color: selected ? AppColors.accent : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.month}.${day.day}', style: AppType.headline.copyWith(color: foreground)),
              Text(noted ? '기록 있음' : '기록 없음', style: AppType.footnote.copyWith(color: note)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  const _EmptyRecord();

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return Container(
      key: const Key('journal-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.book, size: 24, color: AppColors.tertiary),
          const SizedBox(height: 8),
          Text(formatMonthDay(controller.journalDate), style: AppType.footnote),
          const SizedBox(height: 4),
          const Text('기록이 없습니다', style: AppType.title),
          const SizedBox(height: 8),
          const Text('사진과 여행 기록은 사진 단계에서 사용할 수 있습니다.', style: AppType.body),
          const SizedBox(height: 8),
          const Text('촬영 시각이 있는 사진 0장', style: AppType.footnote),
        ],
      ),
    );
  }
}

class _RecordSections extends StatelessWidget {
  const _RecordSections();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      child: const Column(
        children: [
          _InfoRow(title: '날짜별 앨범', detail: '표시할 사진이 없습니다.'),
          Divider(height: 1, color: AppColors.line),
          _StorySection(),
        ],
      ),
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection();

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    final saved = controller.journalText();
    if (trip == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('하루 이야기', style: AppType.headline),
          const SizedBox(height: 2),
          Text(saved == null ? '작성된 이야기가 없습니다.' : '이 기기에만 저장된 이야기', style: AppType.footnote),
          const SizedBox(height: 8),
          _StoryEditor(
            key: ValueKey('${trip.id}-${journalDayKey(controller.journalDate)}'),
            initial: saved ?? '',
          ),
        ],
      ),
    );
  }
}

class _StoryEditor extends StatefulWidget {
  const _StoryEditor({super.key, required this.initial});

  final String initial;

  @override
  State<_StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<_StoryEditor> {
  late final TextEditingController text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final unchanged = text.text.trim() == widget.initial.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('journal-story'),
          controller: text,
          style: AppType.body,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '이 날의 이야기를 적으세요',
            hintStyle: AppType.body.copyWith(color: AppColors.tertiary),
            filled: true,
            fillColor: AppColors.canvas,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            key: const Key('save-journal'),
            label: '저장',
            onPressed: unchanged ? null : () => controller.saveJournal(text.text),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.headline),
          const SizedBox(height: 2),
          Text(detail, style: AppType.footnote),
        ],
      ),
    );
  }
}
