import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/countries.dart';
import '../format.dart';
import '../logic/trip_rules.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.onClose, this.trip});

  final VoidCallback? onClose;

  /// When set, the form edits this trip instead of creating one.
  final Trip? trip;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  late final TripDraft draft = widget.trip == null ? TripDraft(cities: [CityDraft()]) : TripDraft.fromTrip(widget.trip!);
  final titleController = TextEditingController();
  final purposeController = TextEditingController();
  final budgetController = TextEditingController();
  final tagController = TextEditingController();
  final Map<String, GlobalKey> _anchors = {};
  final Map<CityDraft, GlobalKey> _cityAnchors = {};
  Map<String, String> errors = {};
  bool _dirty = false;

  static const _maxWidth = 600.0;

  bool get _editing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    titleController.text = draft.title;
    purposeController.text = draft.purpose;
    budgetController.text = draft.budgetAmount;
  }

  @override
  void dispose() {
    titleController.dispose();
    purposeController.dispose();
    budgetController.dispose();
    tagController.dispose();
    super.dispose();
  }

  GlobalKey _anchor(String name) {
    if (name.startsWith('city-')) {
      final index = int.parse(name.substring(5));
      return _cityAnchors.putIfAbsent(draft.cities[index], GlobalKey.new);
    }
    return _anchors.putIfAbsent(name, GlobalKey.new);
  }

  void _edit(VoidCallback change, {List<String> clears = const []}) {
    setState(() {
      change();
      _dirty = true;
      for (final key in clears) {
        errors.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = countryNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final total = draft.companionCount + 1;
    if (widget.onClose == null) return _form(names, total);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _form(names, total),
    );
  }

  Widget _form(List<MapEntry<String, String>> names, int total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - _maxWidth) / 2).clamp(
          AppSpace.page,
          double.infinity,
        );
        return SingleChildScrollView(
          key: const Key('trip-form-scroll'),
          padding: EdgeInsets.fromLTRB(side, AppSpace.xs, side, AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.onClose != null)
                BackRow(label: '취소', onPressed: _close),
              Text(_editing ? '여행 편집' : '여행 만들기', key: const Key('form-heading'), style: AppType.title),
              const SizedBox(height: AppSpace.xxs),
              Text(
                _editing
                    ? '일정과 장소 선택은 그대로 둡니다. 기간을 줄이거나 도시를 빼면 그 날짜의 일정 항목이 지워집니다.'
                    : '제목, 국가, 기간, 도시는 꼭 필요합니다. 나머지는 나중에 채워도 됩니다.',
                style: AppType.footnote,
              ),
              const SectionLabel('기본 정보'),
              _labeled(
                '제목',
                key: _anchor('title'),
                error: errors['title'],
                child: TextField(
                  key: const Key('form-title'),
                  controller: titleController,
                  style: AppType.body,
                  textInputAction: TextInputAction.next,
                  decoration: AppFields.decoration('예: 가을 상하이 산책'),
                  onChanged: (value) =>
                      _edit(() => draft.title = value, clears: ['title']),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              _labeled(
                '대표 국가',
                key: _anchor('country'),
                error: errors['country'],
                child: DropdownButtonFormField<String>(
                  key: const Key('form-country'),
                  initialValue: countryNames.containsKey(draft.countryCode)
                      ? draft.countryCode
                      : null,
                  isExpanded: true,
                  decoration: AppFields.decoration('국가를 고르세요'),
                  items: [
                    for (final entry in names)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          '${entry.value} · ${entry.key}',
                          style: AppType.body,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _edit(() => draft.countryCode = value, clears: ['country']);
                  },
                ),
              ),
              const SectionLabel('기간'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dateField(
                      '시작일',
                      draft.start,
                      key: _anchor('start'),
                      fieldKey: const Key('form-start'),
                      error: errors['start'],
                      initial: () => draft.end,
                      onPick: (date) => _edit(() {
                        draft.start = date;
                        _fillCityDates();
                      }, clears: ['start', 'end']),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: _dateField(
                      '종료일',
                      draft.end,
                      key: _anchor('end'),
                      fieldKey: const Key('form-end'),
                      error: errors['end'],
                      initial: () => draft.start,
                      onPick: (date) => _edit(() {
                        draft.end = date;
                        _fillCityDates();
                      }, clears: ['end']),
                    ),
                  ),
                ],
              ),
              SectionLabel('도시 ${draft.cities.length}곳'),
              for (var index = 0; index < draft.cities.length; index++)
                _cityDraft(index),
              if (errors['cities'] != null)
                KeyedSubtree(
                  key: _anchor('cities'),
                  child: _error(errors['cities']!),
                ),
              const SizedBox(height: AppSpace.xs),
              AppButton(
                key: const Key('form-add-city'),
                label: '도시 추가',
                filled: false,
                onPressed: () => _edit(
                  () => draft.cities.add(
                    CityDraft(
                      countryCode: draft.countryCode,
                      start: draft.start,
                      end: draft.end,
                    ),
                  ),
                  clears: ['cities'],
                ),
              ),
              const SectionLabel('선택 사항'),
              _labeled(
                '목적',
                child: TextField(
                  controller: purposeController,
                  style: AppType.body,
                  maxLines: 3,
                  minLines: 2,
                  decoration: AppFields.decoration('예: 부모님과 천천히 걷기'),
                  onChanged: (value) => _edit(() => draft.purpose = value),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              _labeled(
                '취향',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('form-tag'),
                        controller: tagController,
                        style: AppType.body,
                        textInputAction: TextInputAction.done,
                        decoration: AppFields.decoration('예: 야경, 시장'),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    AppButton(
                      key: const Key('form-add-tag'),
                      label: '추가',
                      filled: false,
                      onPressed: _addTag,
                    ),
                  ],
                ),
              ),
              if (draft.tasteTags.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final tag in draft.tasteTags)
                      InputChip(
                        label: Text(
                          tag,
                          style: AppType.footnoteStrong.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        backgroundColor: AppColors.accentSoft,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        deleteIconColor: AppColors.accent,
                        deleteButtonTooltipMessage: '$tag 지우기',
                        onDeleted: () =>
                            _edit(() => draft.tasteTags.remove(tag)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              _labeled(
                '예산',
                key: _anchor('budget'),
                error: errors['budget'],
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('form-budget'),
                        controller: budgetController,
                        style: AppType.body,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppFields.decoration('금액'),
                        onChanged: (value) => _edit(
                          () => draft.budgetAmount = value,
                          clears: ['budget'],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: draft.budgetCurrency.isEmpty
                            ? null
                            : draft.budgetCurrency,
                        isExpanded: true,
                        decoration: AppFields.decoration('통화'),
                        items: [
                          for (final code in currencyCodes)
                            DropdownMenuItem(
                              value: code,
                              child: Text(code, style: AppType.body),
                            ),
                        ],
                        onChanged: (value) => _edit(
                          () => draft.budgetCurrency = value ?? '',
                          clears: ['budget'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              const Text('동행 인원', style: AppType.footnoteStrong),
              const SizedBox(height: AppSpace.xxs),
              Row(
                children: [
                  AppButton(
                    key: const Key('form-companion-minus'),
                    label: '−',
                    filled: false,
                    onPressed: draft.companionCount == 0
                        ? null
                        : () => _edit(() => draft.companionCount -= 1),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${draft.companionCount}',
                      key: const Key('form-companion-count'),
                      textAlign: TextAlign.center,
                      style: AppType.headline,
                    ),
                  ),
                  AppButton(
                    key: const Key('form-companion-plus'),
                    label: '+',
                    filled: false,
                    onPressed: () => _edit(() => draft.companionCount += 1),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text('본인 제외 · 총 $total명', style: AppType.footnote),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              if (errors.isNotEmpty) ...[
                Text(
                  '입력을 확인하세요. 고칠 곳이 ${errors.length}곳 있습니다.',
                  key: const Key('form-error-summary'),
                  style: AppType.footnoteStrong.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
              ],
              AppButton(
                key: const Key('form-save'),
                label: _editing ? '변경 저장' : '여행 만들기',
                onPressed: _save,
              ),
            ],
          ),
        );
      },
    );
  }

  void _fillCityDates() {
    for (final city in draft.cities) {
      city.start ??= draft.start;
      city.end ??= draft.end;
    }
  }

  void _addTag() {
    final word = tagController.text.trim();
    if (word.isEmpty) return;
    _edit(() {
      if (!draft.tasteTags.contains(word)) draft.tasteTags.add(word);
      tagController.clear();
    });
  }

  Future<void> _close() async {
    final onClose = widget.onClose;
    if (onClose == null) return;
    if (!_dirty) {
      onClose();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_editing ? '수정한 내용을 버릴까요?' : '작성 중인 여행을 버릴까요?', style: AppType.headline),
        content: Text(_editing ? '여행은 수정 전 그대로 남습니다.' : '입력한 내용은 저장되지 않습니다.', style: AppType.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_editing ? '계속 수정' : '계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    if (discard == true) onClose();
  }

  Future<void> _save() async {
    draft.title = titleController.text;
    draft.purpose = purposeController.text;
    draft.budgetAmount = budgetController.text;
    final next = validateTripDraft(draft);
    if (draft.cities.isEmpty) next['cities'] = '도시를 하나 이상 추가하세요.';
    setState(() => errors = next);
    if (next.isNotEmpty) {
      _revealFirstError(next);
      return;
    }
    final controller = TripScope.of(context);
    final trip = widget.trip;
    if (trip == null) {
      controller.createTrip(draft);
      return;
    }
    final impact = tripEditImpact(trip, draft);
    if (!impact.isEmpty && await _confirmRemoval(impact) != true) return;
    if (!mounted) return;
    controller.updateTrip(trip.id, draft);
  }

  Future<bool?> _confirmRemoval(TripEditImpact impact) {
    final dates = impact.days.map(formatMonthDay).join(', ');
    final pinned = impact.pinned == 0 ? '' : '(고정 ${impact.pinned}개 포함)';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('일정 항목 ${impact.items}개가 지워집니다', style: AppType.headline),
        content: Text(
          '기간 밖이 되거나 뺀 도시의 날짜($dates, ${impact.days.length}일)에 있는 적용된 일정 항목 ${impact.items}개$pinned가 지워집니다. '
          '다른 날짜의 일정과 장소 선택은 그대로입니다.',
          key: const Key('edit-removal-message'),
          style: AppType.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('계속 수정')),
          TextButton(
            key: const Key('confirm-edit-trip'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('지우고 저장'),
          ),
        ],
      ),
    );
  }

  void _revealFirstError(Map<String, String> found) {
    final order = ['title', 'country', 'start', 'end'];
    for (var index = 0; index < draft.cities.length; index++) {
      order.add('city-$index');
    }
    order.addAll(['cities', 'budget']);
    String? first;
    for (final name in order) {
      final hit = name.startsWith('city-')
          ? found.keys.any((key) => key.startsWith('$name-'))
          : found.containsKey(name);
      if (hit) {
        first = name;
        break;
      }
    }
    if (first == null) return;
    final target = _anchor(first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = target.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  Widget _cityDraft(int index) {
    final city = draft.cities[index];
    final names = countryNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final prefix = 'city-$index';
    return Container(
      key: ObjectKey(city),
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: AppDecor.card(),
      child: KeyedSubtree(
        key: _anchor(prefix),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('도시 ${index + 1}', style: AppType.headline),
                ),
                if (draft.cities.length > 1)
                  TextButton(
                    key: Key('form-remove-city-$index'),
                    onPressed: () => _edit(() {
                      _cityAnchors.remove(draft.cities.removeAt(index));
                      errors.removeWhere(
                        (key, _) => key.startsWith('city-') || key == 'cities',
                      );
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('빼기'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            TextFormField(
              key: Key('form-city-name-$index'),
              initialValue: city.name,
              style: AppType.body,
              decoration: AppFields.decoration('도시 이름 (예: 상하이)'),
              onChanged: (value) =>
                  _edit(() => city.name = value, clears: ['$prefix-name']),
            ),
            if (errors['$prefix-name'] != null) _error(errors['$prefix-name']!),
            const SizedBox(height: AppSpace.xs),
            DropdownButtonFormField<String>(
              initialValue: countryNames.containsKey(city.countryCode)
                  ? city.countryCode
                  : null,
              isExpanded: true,
              decoration: AppFields.decoration('국가'),
              items: [
                for (final entry in names)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${entry.value} · ${entry.key}',
                      style: AppType.body,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _edit(
                  () => city.countryCode = value,
                  clears: ['$prefix-country'],
                );
              },
            ),
            if (errors['$prefix-country'] != null)
              _error(errors['$prefix-country']!),
            const SizedBox(height: AppSpace.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dateField(
                    '시작일',
                    city.start,
                    fieldKey: Key('form-city-start-$index'),
                    initial: () => draft.start,
                    onPick: (date) => _edit(
                      () => city.start = date,
                      clears: ['$prefix-dates', 'cities'],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _dateField(
                    '종료일',
                    city.end,
                    fieldKey: Key('form-city-end-$index'),
                    initial: () => city.start ?? draft.start,
                    onPick: (date) => _edit(
                      () => city.end = date,
                      clears: ['$prefix-dates', 'cities'],
                    ),
                  ),
                ),
              ],
            ),
            if (errors['$prefix-dates'] != null)
              _error(errors['$prefix-dates']!),
          ],
        ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value, {
    Key? key,
    Key? fieldKey,
    String? error,
    required DateTime? Function() initial,
    required ValueChanged<DateTime> onPick,
  }) {
    final decoration = AppFields.decoration('날짜 고르기');
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.footnoteStrong),
        const SizedBox(height: AppSpace.xxs),
        InkWell(
          key: fieldKey,
          borderRadius: BorderRadius.circular(AppRadii.control),
          onTap: () async {
            final first = DateTime(2024);
            final last = DateTime(2032, 12, 31);
            var start = value ?? initial() ?? TripScope.of(context).now;
            if (start.isBefore(first)) start = first;
            if (start.isAfter(last)) start = last;
            final picked = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) onPick(dateOnly(picked));
          },
          child: InputDecorator(
            isEmpty: value == null,
            decoration: decoration.copyWith(
              suffixIcon: const Icon(
                CupertinoIcons.calendar,
                size: 18,
                color: AppColors.secondary,
              ),
              enabledBorder: error == null
                  ? decoration.enabledBorder
                  : decoration.errorBorder,
            ),
            child: Text(
              value == null ? '' : '${formatDot(value)} (${weekdayKo(value)})',
              style: AppType.body,
              maxLines: 1,
            ),
          ),
        ),
        if (error != null) _error(error),
      ],
    );
  }

  Widget _labeled(
    String label, {
    Key? key,
    String? error,
    required Widget child,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.footnoteStrong),
        const SizedBox(height: AppSpace.xxs),
        child,
        if (error != null) _error(error),
      ],
    );
  }

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xxs),
    child: Text(
      text,
      style: AppType.footnote.copyWith(color: AppColors.danger),
    ),
  );
}
