import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';
import 'chrome.dart';

enum _AddKind { place, memo, transport, lodging }

class ItineraryAddSheet extends StatefulWidget {
  const ItineraryAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    final controller = TripScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TripScope(controller: controller, child: const ItineraryAddSheet()),
    );
  }

  @override
  State<ItineraryAddSheet> createState() => _ItineraryAddSheetState();
}

class _ItineraryAddSheetState extends State<ItineraryAddSheet> {
  _AddKind? _kind;
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
  final places = controller.placesForSelectedDay(query: _query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('일정에 추가', style: AppType.headline),
            const SizedBox(height: AppSpace.xs),
            if (_kind == null) ...[
              _KindTile(
                key: const Key('add-kind-place'),
                icon: Icons.place_outlined,
                label: '장소 검색',
                detail: '탐색 목록에서 고릅니다.',
                onTap: () => setState(() => _kind = _AddKind.place),
              ),
              _KindTile(
                key: const Key('add-kind-memo'),
                icon: Icons.sticky_note_2_outlined,
                label: '메모',
                detail: '직접 적은 일정이나 메모입니다.',
                onTap: () => setState(() => _kind = _AddKind.memo),
              ),
              _KindTile(
                key: const Key('add-kind-transport'),
                icon: Icons.directions_transit_outlined,
                label: '교통',
                detail: '항공·기차·버스 등 이동입니다.',
                onTap: () => setState(() => _kind = _AddKind.transport),
              ),
              _KindTile(
                key: const Key('add-kind-lodging'),
                icon: Icons.hotel_outlined,
                label: '숙소',
                detail: '호텔·숙박 체크인 등입니다.',
                onTap: () => setState(() => _kind = _AddKind.lodging),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _kind = null), child: const Text('← 유형 다시 고르기')),
              ),
              if (_kind == _AddKind.place) ...[
                TextField(
                  key: const Key('add-place-search'),
                  controller: _search,
                  decoration: const InputDecoration(hintText: '장소 이름 검색', labelText: '검색'),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AppSpace.xs),
                if (places.isEmpty)
                  const Text('이 날짜 도시에서 검색 결과가 없습니다.', style: AppType.footnote)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: places.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          key: Key('add-place-${place.id}'),
                          title: Text(place.name, style: AppType.body),
                          subtitle: Text(categoryLabel(place.category), style: AppType.footnote),
                          onTap: () {
                            controller.addItineraryPlace(place);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ] else ...[
                TextField(
                  key: const Key('add-item-title'),
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: _kind == _AddKind.memo ? '제목' : _kind == _AddKind.transport ? '교통 이름' : '숙소 이름',
                    hintText: _kind == _AddKind.transport ? '예: 인천→상하이 항공' : null,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                TextField(
                  key: const Key('add-item-note'),
                  controller: _note,
                  decoration: const InputDecoration(labelText: '메모(선택)', hintText: '예약 번호, 노선, 객실'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpace.sm),
                AppButton(
                  key: const Key('confirm-add-item'),
                  label: '추가',
                  onPressed: () => _submit(context, controller),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context, TripController controller) {
    final title = _title.text;
    switch (_kind) {
      case _AddKind.memo:
        controller.addItineraryMemo(title: title, note: _note.text);
      case _AddKind.transport:
        controller.addItineraryTransport(title: title, note: _note.text);
      case _AddKind.lodging:
        controller.addItineraryLodging(title: title, note: _note.text);
      case _AddKind.place:
      case null:
        return;
    }
    Navigator.pop(context);
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({super.key, required this.icon, required this.label, required this.detail, required this.onTap});

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label, style: AppType.headline),
      subtitle: Text(detail, style: AppType.footnote),
      onTap: onTap,
    );
  }
}

class ItineraryTimeSheet extends StatefulWidget {
  const ItineraryTimeSheet({super.key, required this.item});

  final PlanItem item;

  static Future<void> show(BuildContext context, PlanItem item) {
    final controller = TripScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TripScope(controller: controller, child: ItineraryTimeSheet(item: item)),
    );
  }

  @override
  State<ItineraryTimeSheet> createState() => _ItineraryTimeSheetState();
}

class _ItineraryTimeSheetState extends State<ItineraryTimeSheet> {
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    final anchor = widget.item.start ?? DateTime(2026, 1, 1, 9);
    final end = widget.item.end ?? anchor.add(const Duration(hours: 1));
    _start = TimeOfDay.fromDateTime(anchor);
    _end = TimeOfDay.fromDateTime(end);
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('‘${widget.item.title}’ 시간', style: AppType.headline),
            const SizedBox(height: AppSpace.sm),
            _TimeRow(
              key: const Key('time-edit-start'),
              label: '시작',
              value: _start,
              onPick: (value) => setState(() => _start = value),
            ),
            const SizedBox(height: AppSpace.xs),
            _TimeRow(
              key: const Key('time-edit-end'),
              label: '끝',
              value: _end,
              onPick: (value) => setState(() => _end = value),
            ),
            const SizedBox(height: AppSpace.sm),
            AppButton(
              key: const Key('confirm-time-edit'),
              label: '저장',
              onPressed: () {
                final day = controller.editableDay()?.date ?? widget.item.start ?? DateTime.now();
                final start = DateTime(day.year, day.month, day.day, _start.hour, _start.minute);
                final end = DateTime(day.year, day.month, day.day, _end.hour, _end.minute);
                controller.updateItemTime(widget.item.id, start: start, end: end);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({super.key, required this.label, required this.value, required this.onPick});

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label, style: AppType.footnoteStrong)),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(context: context, initialTime: value);
            if (picked != null) onPick(picked);
          },
          child: Text(formatHm(DateTime(2026, 1, 1, value.hour, value.minute)), style: AppType.headline),
        ),
      ],
    );
  }
}
