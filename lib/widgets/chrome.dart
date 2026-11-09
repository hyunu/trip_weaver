import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../model/models.dart';
import '../shell/scope.dart';
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
  const PageHeader({super.key, required this.title, required this.titleKey, this.subtitle});

  final String title;
  final Key titleKey;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, key: titleKey, style: AppType.largeTitle),
          if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppType.footnote)],
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: AppType.footnoteStrong.copyWith(color: AppColors.secondary)),
    );
  }
}

class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      key: const Key('sample-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.sampleBg, borderRadius: BorderRadius.circular(8)),
      child: const Text(
        '샘플 데이터입니다. 실제 장소 정보가 아닙니다.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: AppType.family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: AppColors.sampleFg),
      ),
    );
  }
}

class LocalPackageStatus extends StatelessWidget {
  const LocalPackageStatus({super.key, required this.placeCount});

  final int placeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '일정은 이 기기에 있습니다 · 장소 $placeCount곳 · 지도 패키지는 받지 않았습니다',
        key: const Key('package-status'),
        maxLines: 2,
        style: AppType.footnote,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFE8EEF4), borderRadius: BorderRadius.circular(10)),
      child: const Text('오프라인. 저장된 데이터만 표시합니다.', style: AppType.footnoteStrong),
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
        background = const Color(0xFFF2F2F7);
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
        background = const Color(0xFFF2F2F7);
        foreground = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(badgeLabel(validity), style: AppType.footnoteStrong.copyWith(color: foreground)),
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
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 0), alignment: Alignment.centerLeft),
        icon: const Icon(CupertinoIcons.chevron_back, size: 18, color: AppColors.accent),
        label: Text(label, style: AppType.headline.copyWith(color: AppColors.accent)),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.title),
          const SizedBox(height: 8),
          Text(message, style: AppType.body),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: title, titleKey: titleKey),
          const Spacer(),
          const Text('여행을 만들거나 고르면 이 화면을 쓸 수 있습니다.', style: AppType.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton(label: '여행 홈으로', onPressed: () => TripScope.of(context).selectTab(0)),
          const Spacer(),
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
    final noteColor = selected ? Colors.white : AppColors.secondary;
    return Material(
      color: selected ? AppColors.accent : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.headline.copyWith(color: foreground)),
              if (note != null) Text(note!, style: AppType.footnote.copyWith(color: noteColor)),
            ],
          ),
        ),
      ),
    );
  }
}
