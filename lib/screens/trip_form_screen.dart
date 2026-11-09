import 'package:flutter/material.dart';

import '../data/countries.dart';
import '../logic/trip_rules.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final draft = TripDraft();
  final titleController = TextEditingController();
  final purposeController = TextEditingController();
  final budgetController = TextEditingController();
  final tagController = TextEditingController();
  final countryController = TextEditingController(text: 'KR');
  Map<String, String> errors = {};

  @override
  void dispose() {
    titleController.dispose();
    purposeController.dispose();
    budgetController.dispose();
    tagController.dispose();
    countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = countryNames.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.onClose != null) BackRow(onPressed: widget.onClose!),
        const Text('여행 만들기', style: AppType.title),
        const SizedBox(height: 12),
        _field('제목', titleController, error: errors['title'], onChanged: (value) => draft.title = value),
        const SizedBox(height: 12),
        const Text('대표 국가', style: AppType.footnoteStrong),
        const SizedBox(height: 4),
        TextField(
          controller: countryController,
          style: AppType.body,
          textCapitalization: TextCapitalization.characters,
          decoration: AppFields.decoration('두 글자 코드'),
          onChanged: (value) => setState(() => draft.countryCode = value.toUpperCase()),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: countryNames.containsKey(draft.countryCode) ? draft.countryCode : null,
          isExpanded: true,
          decoration: AppFields.decoration('국가 이름'),
          items: [
            for (final entry in names) DropdownMenuItem(value: entry.key, child: Text('${entry.value} · ${entry.key}', style: AppType.body)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              draft.countryCode = value;
              countryController.text = value;
            });
          },
        ),
        if (errors['country'] != null) _error(errors['country']!),
        const SizedBox(height: 12),
        _dateRow('시작일', draft.start, errors['start'], (date) => setState(() => draft.start = date)),
        const SizedBox(height: 8),
        _dateRow('종료일', draft.end, errors['end'], (date) => setState(() => draft.end = date)),
        const SizedBox(height: 12),
        _field('목적', purposeController, maxLines: 3, onChanged: (value) => draft.purpose = value),
        const SizedBox(height: 12),
        const Text('취향', style: AppType.footnoteStrong),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(controller: tagController, style: AppType.body, decoration: AppFields.decoration('직접 입력')),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: '추가',
              filled: false,
              onPressed: () {
                final word = tagController.text.trim();
                if (word.isEmpty) return;
                setState(() {
                  draft.tasteTags.add(word);
                  tagController.clear();
                });
              },
            ),
          ],
        ),
        if (draft.tasteTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in draft.tasteTags)
                InputChip(
                  label: Text(tag, style: AppType.footnote),
                  onDeleted: () => setState(() => draft.tasteTags.remove(tag)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text('예산', style: AppType.footnoteStrong),
        const SizedBox(height: 4),
        TextField(
          controller: budgetController,
          style: AppType.body,
          keyboardType: TextInputType.number,
          decoration: AppFields.decoration('금액'),
          onChanged: (value) => draft.budgetAmount = value,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: draft.budgetCurrency.isEmpty ? null : draft.budgetCurrency,
          isExpanded: true,
          decoration: AppFields.decoration('통화'),
          items: [for (final code in currencyCodes) DropdownMenuItem(value: code, child: Text(code, style: AppType.body))],
          onChanged: (value) => setState(() => draft.budgetCurrency = value ?? ''),
        ),
        if (errors['budget'] != null) _error(errors['budget']!),
        const SizedBox(height: 12),
        const Text('동행 인원 (본인 제외)', style: AppType.footnoteStrong),
        const Text('총인원은 이 숫자에 본인을 더합니다.', style: AppType.footnote),
        const SizedBox(height: 8),
        Row(
          children: [
            AppButton(label: '−', filled: false, onPressed: draft.companionCount == 0 ? null : () => setState(() => draft.companionCount -= 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${draft.companionCount}', style: AppType.headline),
            ),
            AppButton(label: '+', filled: false, onPressed: () => setState(() => draft.companionCount += 1)),
          ],
        ),
        const SectionLabel('도시'),
        for (var index = 0; index < draft.cities.length; index++) _cityDraft(index),
        if (errors['cities'] != null) _error(errors['cities']!),
        const SizedBox(height: 8),
        AppButton(
          label: '도시 추가',
          filled: false,
          onPressed: () => setState(() => draft.cities.add(CityDraft(start: draft.start, end: draft.end))),
        ),
        const SizedBox(height: 16),
        AppButton(label: '저장', onPressed: _save),
      ],
    );
  }

  void _save() {
    draft.title = titleController.text;
    draft.purpose = purposeController.text;
    draft.budgetAmount = budgetController.text;
    draft.countryCode = countryController.text.trim().toUpperCase();
    final next = validateTripDraft(draft);
    setState(() => errors = next);
    if (next.isNotEmpty) return;
    TripScope.of(context).createTrip(draft);
  }

  Widget _cityDraft(int index) {
    final city = draft.cities[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: AppType.body,
            decoration: AppFields.decoration('도시 이름'),
            onChanged: (value) => city.name = value,
          ),
          if (errors['city-$index-name'] != null) _error(errors['city-$index-name']!),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: city.countryCode,
            isExpanded: true,
            decoration: AppFields.decoration('국가'),
            items: [for (final entry in countryNames.entries) DropdownMenuItem(value: entry.key, child: Text(entry.key, style: AppType.body))],
            onChanged: (value) => setState(() => city.countryCode = value ?? city.countryCode),
          ),
          const SizedBox(height: 8),
          _dateRow('도시 시작', city.start, null, (date) => setState(() => city.start = date)),
          const SizedBox(height: 8),
          _dateRow('도시 종료', city.end, errors['city-$index-dates'], (date) => setState(() => city.end = date)),
        ],
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value, String? error, ValueChanged<DateTime> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.footnoteStrong),
        const SizedBox(height: 4),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final now = TripScope.of(context).now;
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(2024),
                lastDate: DateTime(2032),
              );
              if (picked != null) onPick(dateOnly(picked));
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(value == null ? '날짜를 고르세요' : '${value.year}.${value.month}.${value.day}', style: AppType.body),
            ),
          ),
        ),
        if (error != null) _error(error),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, {String? error, int maxLines = 1, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.footnoteStrong),
        const SizedBox(height: 4),
        TextField(controller: controller, style: AppType.body, maxLines: maxLines, decoration: AppFields.decoration(label), onChanged: onChanged),
        if (error != null) _error(error),
      ],
    );
  }

  Widget _error(String text) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: AppType.footnote.copyWith(color: AppColors.danger)));

}
