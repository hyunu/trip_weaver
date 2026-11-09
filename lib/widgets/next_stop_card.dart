import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../logic/map_directions.dart';
import '../map/geo.dart';
import '../model/models.dart';
import '../shell/scope.dart';
import '../theme/app_theme.dart';
import 'chrome.dart';
import 'schedule_block.dart';

class NextStopCard extends StatelessWidget {
  const NextStopCard({super.key, required this.item, required this.place, required this.onOpenDetail});

  final PlanItem item;
  final Place? place;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    final point = place == null ? null : placeGeo(place!);
    final canNavigate = directionsUri(point: point, place: place) != null;
    final local = place?.localName?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScheduleBlock(key: const Key('underway-next'), item: item, emphasize: true, onTap: onOpenDetail),
        if (place != null) ...[
          const SizedBox(height: AppSpace.xs),
          PlaceLocalCaption(
            key: const Key('underway-next-local'),
            place: place!,
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            _ActionChip(
              key: const Key('underway-directions'),
              label: '길찾기',
              icon: CupertinoIcons.location_fill,
              onPressed: canNavigate ? () => openDirections(point: point, place: place) : null,
            ),
            _ActionChip(
              key: const Key('underway-local-sheet'),
              label: '현지어로 보여 주기',
              icon: CupertinoIcons.textformat,
              onPressed: place == null ? null : () => _showLocalSheet(context, place!),
            ),
            _ActionChip(
              key: const Key('underway-arrived'),
              label: '도착',
              icon: CupertinoIcons.checkmark_circle,
              onPressed: () => controller.markVisitDone(item.id),
            ),
            _ActionChip(
              key: const Key('underway-skip'),
              label: '건너뛰기',
              icon: CupertinoIcons.forward_end,
              onPressed: () => controller.skipVisit(item.id),
            ),
          ],
        ),
      ],
    );
  }

  void _showLocalSheet(BuildContext context, Place place) {
    final local = place.localName?.trim();
    final title = local == null || local.isEmpty ? '현지어 이름 미확인' : local;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.xs, AppSpace.page, AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('기사·안내에 보여 줄 이름', style: AppType.footnoteStrong),
                const SizedBox(height: AppSpace.sm),
                SelectableText(title, key: const Key('underway-local-sheet-text'), style: AppType.largeTitle),
                const SizedBox(height: AppSpace.md),
                Text(place.name, style: AppType.headline),
                const SizedBox(height: AppSpace.xs),
                Text(addressLine(place), style: AppType.body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? AppColors.accent : AppColors.tertiary,
        backgroundColor: AppColors.card,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: const BorderSide(color: AppColors.line),
        ),
        textStyle: AppType.footnoteStrong,
      ),
      icon: Icon(icon, size: 16, color: enabled ? AppColors.accent : AppColors.tertiary),
      label: Text(label),
    );
  }
}
