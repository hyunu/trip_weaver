import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/schedule.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';

class ScrollHost extends StatefulWidget {
  const ScrollHost({super.key, required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  State<ScrollHost> createState() => _ScrollHostState();
}

class _ScrollHostState extends State<ScrollHost> {
  ScrollController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final stored = TripScope.of(context).scrollOf(widget.id);
    final controller = ScrollController(initialScrollOffset: stored);
    controller.addListener(() {
      if (!controller.hasClients) return;
      TripScope.of(context).saveScroll(widget.id, controller.offset);
    });
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller!);
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.titleKey, this.subtitle, this.subtitleWidget});

  final String title;
  final Key titleKey;
  final String? subtitle;
  final Widget? subtitleWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, key: titleKey, style: AppType.largeTitle),
          if (subtitleWidget != null) ...[
            const SizedBox(height: AppSpace.xxs),
            subtitleWidget!,
          ] else if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xxs),
            Text(subtitle!, style: AppType.footnote, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// 헤더 부제에 현재 여행을 보여 주고, 탭을 떠나지 않고 여행을 바꿀 수 있게 한다.
class TripContextSubtitle extends StatelessWidget {
  const TripContextSubtitle({super.key, this.trailingLine});

  final String? trailingLine;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final trip = controller.current;
    if (trip == null) return const SizedBox.shrink();
    final label = cityTripLabel(controller.selectedCity?.name, trip.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TripSwitcherControl(label: label, tripId: trip.id),
        if (trailingLine != null) ...[
          const SizedBox(height: 2),
          Text(trailingLine!, style: AppType.footnote.copyWith(color: AppColors.secondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}

class TripSwitcherControl extends StatelessWidget {
  const TripSwitcherControl({super.key, required this.label, required this.tripId});

  final String label;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '현재 여행 $label, 여행 바꾸기',
      child: InkWell(
        key: const Key('trip-switcher'),
        borderRadius: BorderRadius.circular(AppRadii.control),
        onTap: () => _openTripPicker(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: AppType.footnoteStrong.copyWith(color: AppColors.accent), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const Icon(CupertinoIcons.chevron_down, size: 14, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTripPicker(BuildContext context) {
    final controller = TripScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _TripPickerSheet(controller: controller, selectedId: tripId),
    );
  }
}

class _TripPickerSheet extends StatelessWidget {
  const _TripPickerSheet({required this.controller, required this.selectedId});

  final TripController controller;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final ongoing = controller.trips.where((trip) => isOngoing(trip, now)).toList();
    final upcoming = controller.trips.where((trip) => !isOngoing(trip, now) && !isPast(trip, now)).toList();
    final past = controller.trips.where((trip) => isPast(trip, now)).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shrinkWrap: true,
        children: [
          Text('여행 바꾸기', style: AppType.title),
          const SizedBox(height: AppSpace.sm),
          if (ongoing.isNotEmpty) ...[
            Text('진행 중', style: AppType.section),
            for (final trip in ongoing) _TripPickerTile(trip: trip, selected: trip.id == selectedId, onTap: () => _pick(context, trip.id)),
          ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('예정', style: AppType.section),
            for (final trip in upcoming) _TripPickerTile(trip: trip, selected: trip.id == selectedId, onTap: () => _pick(context, trip.id)),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('지난 여행', style: AppType.section),
            for (final trip in past) _TripPickerTile(trip: trip, selected: trip.id == selectedId, onTap: () => _pick(context, trip.id)),
          ],
        ],
      ),
    );
  }

  void _pick(BuildContext context, String id) {
    controller.selectTrip(id);
    Navigator.of(context).pop();
  }
}

class _TripPickerTile extends StatelessWidget {
  const _TripPickerTile({required this.trip, required this.selected, required this.onTap});

  final Trip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('trip-picker-${trip.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(displayTitle(trip.title), style: AppType.headline.copyWith(color: selected ? AppColors.accent : AppColors.ink)),
      subtitle: Text('${formatRange(trip.start, trip.end)} · ${statusLabel(trip.status)}', style: AppType.footnote),
      trailing: selected ? const Icon(CupertinoIcons.check_mark, color: AppColors.accent, size: 18) : null,
      onTap: onTap,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xs),
      child: Text(text, style: AppType.section),
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    required this.background,
    required this.foreground,
    required this.icon,
    this.bannerKey,
    this.margin = const EdgeInsets.only(top: AppSpace.sm),
  });

  final String message;
  final Color background;
  final Color foreground;
  final IconData icon;
  final Key? bannerKey;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: bannerKey,
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.sm),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.control)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(message, style: AppType.banner.copyWith(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const NoticeBanner(
      bannerKey: Key('sample-banner'),
      message: '샘플 데이터입니다. 실제 장소 정보가 아닙니다.',
      background: AppColors.sampleBg,
      foreground: AppColors.sampleFg,
      icon: CupertinoIcons.exclamationmark_circle_fill,
    );
  }
}

class LocalPackageStatus extends StatelessWidget {
  const LocalPackageStatus({super.key, required this.placeCount});

  final int placeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Text(
        '일정은 이 기기에 있습니다 · 장소 $placeCount곳 · 지도 패키지는 받지 않았습니다',
        key: const Key('package-status'),
        maxLines: 2,
        style: AppType.caption,
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const NoticeBanner(
      message: '오프라인. 저장된 데이터만 표시합니다.',
      background: AppColors.offlineBg,
      foreground: AppColors.offlineFg,
      icon: CupertinoIcons.wifi_slash,
    );
  }
}

class MapTileNotice extends StatelessWidget {
  const MapTileNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      bannerKey: Key('map-tile'),
      message: '지도 타일을 불러오지 못했습니다. 연결을 확인하세요.',
      background: AppColors.offlineBg,
      foreground: AppColors.offlineFg,
      icon: CupertinoIcons.wifi_slash,
      margin: EdgeInsets.all(AppSpace.xs),
    );
  }
}

class StatusBanners extends StatelessWidget {
  const StatusBanners({super.key, required this.sample, this.offline = false});

  final bool sample;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OfflineBanner(visible: offline),
        SampleBanner(visible: sample),
      ],
    );
  }
}

class FactBadge extends StatelessWidget {
  const FactBadge(this.validity, {super.key});

  final FactValidity validity;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    switch (validity) {
      case FactValidity.corroborated:
        background = AppColors.accentSoft;
        foreground = AppColors.accent;
      case FactValidity.collected:
        background = AppColors.canvas;
        foreground = AppColors.ink;
      case FactValidity.conflicted:
        background = AppColors.conflictBg;
        foreground = AppColors.conflictFg;
      case FactValidity.stale:
        background = AppColors.warningBg;
        foreground = AppColors.warningFg;
      case FactValidity.suspended:
        background = const Color(0xFFF3E8E4);
        foreground = AppColors.danger;
      case FactValidity.unknown:
        background = AppColors.canvas;
        foreground = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.xxs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.chip)),
      child: Text(badgeLabel(validity), style: AppType.caption.copyWith(color: foreground, fontWeight: FontWeight.w600)),
    );
  }
}

/// 현지 간판·택시용 한자/현지어 표기. 위 [Place.name]이 한국어로 읽는 이름입니다.
class PlaceLocalCaption extends StatelessWidget {
  const PlaceLocalCaption({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final local = place.localName?.trim();
    if (local == null || local.isEmpty) {
      return Text('현지 간판 표기 없음', style: AppType.footnote.copyWith(color: AppColors.tertiary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('현지 간판·택시용', style: AppType.footnoteStrong.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 2),
        Text(local, style: AppType.footnote),
      ],
    );
  }
}

class BackRow extends StatelessWidget {
  const BackRow({super.key, required this.onPressed, this.label = '뒤로'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          alignment: Alignment.centerLeft,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(CupertinoIcons.chevron_back, size: 18, color: AppColors.accent),
        label: Text(label, style: AppType.headline.copyWith(color: AppColors.accent)),
      ),
    );
  }
}

class QuietEmpty extends StatelessWidget {
  const QuietEmpty({super.key, required this.message, this.title, this.icon = CupertinoIcons.square_list});

  final String message;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(title!, style: AppType.headline, textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpace.xs),
          Text(message, style: AppType.footnote, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.square_list, size: 22, color: AppColors.accent),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(title, style: AppType.title, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.xs),
                Text(message, style: AppType.body.copyWith(color: AppColors.secondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-height column whose [Expanded] children share the spare space, and
/// which scrolls instead of overflowing when the content is taller than the
/// screen (short phones, large text).
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }
}

class NeedTrip extends StatelessWidget {
  const NeedTrip({super.key, required this.title, required this.titleKey});

  final String title;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      child: FillOrScroll(
        children: [
          PageHeader(title: title, titleKey: titleKey),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const QuietEmpty(message: '여행을 만들거나 고르면 이 화면을 쓸 수 있습니다.', icon: CupertinoIcons.map),
                    const SizedBox(height: AppSpace.md),
                    AppButton(label: '여행 홈으로', onPressed: () => TripScope.of(context).selectTab(0)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.note});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    final noteColor = selected ? const Color(0xE6FFFFFF) : AppColors.secondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.accent : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: selected ? AppColors.accent : AppColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.headline.copyWith(color: foreground)),
                if (note != null) Text(note!, style: AppType.caption.copyWith(color: noteColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DateToken extends StatelessWidget {
  const DateToken({super.key, required this.label, required this.note, required this.selected, required this.onTap, this.width = 84, this.semanticsLabel});

  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  /// Spoken instead of the compact visual label, e.g. '11월 8일 일요일, 기록 없음'.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    final noteColor = selected ? const Color(0xE6FFFFFF) : AppColors.secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? AppColors.accent : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            width: width,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: selected ? AppColors.accent : AppColors.line),
            ),
            // The strip that hosts these tokens has a fixed height; at large
            // text scales the label shrinks to fit instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppType.headline.copyWith(color: foreground)),
                  Text(note, maxLines: 1, style: AppType.caption.copyWith(color: noteColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DateRailTile extends StatelessWidget {
  const DateRailTile({super.key, required this.label, required this.note, required this.selected, required this.onTap});

  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          color: selected ? AppColors.accentSoft : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.headline.copyWith(color: selected ? AppColors.accent : AppColors.ink)),
              const SizedBox(height: 2),
              Text(note, style: AppType.caption.copyWith(color: selected ? AppColors.accent : AppColors.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class MapFrame extends StatelessWidget {
  const MapFrame({super.key, required this.child, this.note, this.expand = false});

  final Widget child;
  final String? note;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final frame = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.map),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.map),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expand) Expanded(child: child) else child,
            if (note != null)
              // An expanded frame has a fixed height shared with the map, so
              // the note's growth is capped to leave the map visible.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: expand ? 1.5 : double.infinity,
                child: ColoredBox(
                  color: AppColors.moveBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
                    child: Text(note!, style: AppType.footnote.copyWith(color: AppColors.offlineFg)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.xs, AppSpace.page, 0),
      child: frame,
    );
  }
}
