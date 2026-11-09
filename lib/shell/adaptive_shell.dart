import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../screens/city_edit_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/home_screen.dart';
import '../screens/itinerary_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/trip_detail_screen.dart';
import '../screens/trip_form_screen.dart';
import '../screens/underway_screen.dart';
import '../state/trip_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome.dart';
import '../widgets/place_panel.dart';
import 'scope.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = ShellMetrics(constraints.biggest);
        return AdaptiveScope(
          tablet: metrics.tablet,
          wide: metrics.wide,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final frame = !metrics.tablet ? _PhoneFrame(controller: controller) : _TabletFrame(controller: controller, wide: metrics.wide);
              return RepaintBoundary(key: const Key('capture-root'), child: frame);
            },
          ),
        );
      },
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.controller});

  final TripController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: Column(
        children: [
          Expanded(
            child: SafeArea(bottom: false, child: _phonePage(controller)),
          ),
          _TabBar(index: controller.tabIndex, onTap: controller.selectTab),
        ],
      ),
    );
  }

  Widget _phonePage(TripController controller) {
    switch (controller.tabIndex) {
      case 0:
        if (controller.creating) return TripFormScreen(onClose: controller.closeCreate);
        if (controller.homePushed && controller.current != null) return TripDetailScreen(onClose: controller.closeHome);
        return const HomeScreen(tablet: false);
      case 1:
        if (controller.current == null) return const NeedTrip(title: '탐색', titleKey: Key('screen-title-explore'));
        if (controller.editingCity) return CityEditScreen(onClose: controller.closeCityEdit);
        final place = controller.placeById(controller.selectedPlaceId);
        if (controller.explorePushed && place != null) return PlacePanel(place: place, onClose: controller.closeExplore);
        return const ExploreScreen(tablet: false);
      case 2:
        if (controller.current == null) return const NeedTrip(title: '일정', titleKey: Key('screen-title-itinerary'));
        if (controller.itineraryPushed && controller.selectedItem() != null) return ItemFacts(onClose: controller.closeItinerary);
        return const ItineraryScreen(tablet: false, wide: false);
      case 3:
        return const UnderwayScreen(tablet: false);
      case 4:
        return const JournalScreen(tablet: false);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TabletFrame extends StatelessWidget {
  const _TabletFrame({required this.controller, required this.wide});

  final TripController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: Row(
          children: [
            _Rail(index: controller.tabIndex, onTap: controller.selectTab),
            const VerticalDivider(width: 1),
            Expanded(child: _tabletBody(controller)),
          ],
        ),
      ),
    );
  }

  Widget _tabletBody(TripController controller) {
    switch (controller.tabIndex) {
      case 0:
        return Row(
          children: [
            const SizedBox(width: 360, child: HomeScreen(tablet: true)),
            const VerticalDivider(width: 1),
            Expanded(
              child: controller.creating
                  ? TripFormScreen(onClose: controller.closeCreate)
                  : controller.current == null
                      ? const EmptyPane(title: '여행', message: '여행을 고르세요.')
                      : const TripDetailScreen(),
            ),
          ],
        );
      case 1:
        if (controller.current == null) return const NeedTrip(title: '탐색', titleKey: Key('screen-title-explore'));
        final place = controller.placeById(controller.selectedPlaceId);
        return Row(
          children: [
            const SizedBox(width: 400, child: ExploreScreen(tablet: true)),
            const VerticalDivider(width: 1),
            Expanded(child: _exploreDetail(controller, place)),
          ],
        );
      case 2:
        return ItineraryScreen(tablet: true, wide: wide);
      case 3:
        return const UnderwayScreen(tablet: true);
      case 4:
        return const JournalScreen(tablet: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _exploreDetail(TripController controller, place) {
    if (controller.editingCity) return CityEditScreen(onClose: controller.closeCityEdit);
    if (place == null) return const EmptyPane(title: '장소', message: '장소를 고르세요.');
    if (!wide) return PlacePanel(place: place);
    return Row(
      children: [
        Expanded(child: PlacePanel(place: place, pane: FactPane.facts)),
        const VerticalDivider(width: 1),
        SizedBox(width: 320, child: PlacePanel(place: place, pane: FactPane.sources)),
      ],
    );
  }
}

class _Destination {
  const _Destination(this.label, this.shortLabel, this.icon, this.keyName);

  final String label;
  final String shortLabel;
  final IconData icon;
  final String keyName;
}

const _destinations = [
  _Destination('여행 홈', '홈', CupertinoIcons.house_fill, 'home'),
  _Destination('여행 탐색', '탐색', CupertinoIcons.compass, 'explore'),
  _Destination('여행 일정', '일정', CupertinoIcons.calendar, 'itinerary'),
  _Destination('여행 중', '여행 중', CupertinoIcons.location_solid, 'underway'),
  _Destination('여행 기록', '기록', CupertinoIcons.book, 'journal'),
];

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // The system home indicator is a short pill at the screen edge.
    // The full safe-area inset leaves a blank band under the labels.
    final clearance = safeBottom > 0 ? 16.0 : 0.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: clearance),
        // Labels are capped so five tabs keep fitting one row; the full
        // destination name is in each tab's semantics label.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      label: _destinations[i].label,
                      excludeSemantics: true,
                      child: InkWell(
                        key: Key('tab-${_destinations[i].keyName}'),
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(_destinations[i].icon, size: 22, color: i == index ? AppColors.accent : AppColors.secondary),
                            const SizedBox(height: 2),
                            Text(
                              _destinations[i].shortLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(
                                height: 1.1,
                                color: i == index ? AppColors.accent : AppColors.secondary,
                                fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: ColoredBox(
          color: const Color(0xFFF7F7F8),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _destinations[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('rail-${_destinations[i].keyName}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(i),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: i == index ? AppColors.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Icon(_destinations[i].icon, size: 22, color: i == index ? AppColors.accent : AppColors.secondary),
                            const SizedBox(height: 2),
                            Text(
                              _destinations[i].shortLabel,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: i == index ? AppColors.accent : AppColors.secondary, fontWeight: i == index ? FontWeight.w600 : FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
