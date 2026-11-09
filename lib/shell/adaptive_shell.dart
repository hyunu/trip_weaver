import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
              final frame = !metrics.tablet
                  ? _PhoneFrame(controller: controller)
                  : _TabletFrame(controller: controller, wide: metrics.wide);
              return RepaintBoundary(
                key: const Key('capture-root'),
                child: frame,
              );
            },
          ),
        );
      },
    );
  }
}

/// 각 탭마다 중첩 [Navigator]를 두어 상세 화면을 실제 라우트로 쌓는다.
/// 시스템 뒤로가기·엣지 스와이프는 상세를 먼저 닫고 플래그를 내린다.
class _PhoneFrame extends StatefulWidget {
  const _PhoneFrame({required this.controller});

  final TripController controller;

  @override
  State<_PhoneFrame> createState() => _PhoneFrameState();
}

class _PhoneFrameState extends State<_PhoneFrame> {
  final _navigators = List.generate(
    _destinations.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  TripController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final tab = controller.tabIndex;
    final pages = _phonePages(tab);
    return PopScope(
      canPop: tab == 0 && pages.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (pages.length > 1) {
          _navigators[tab].currentState?.maybePop();
        } else if (tab != 0) {
          controller.selectTab(0);
        }
      },
      child: Material(
        color: AppColors.canvas,
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Navigator(
                  key: _navigators[tab],
                  pages: pages,
                  onDidRemovePage: _removed,
                ),
              ),
            ),
            _TabBar(index: tab, onTap: controller.selectTab),
          ],
        ),
      ),
    );
  }

  List<Page<void>> _phonePages(int tab) {
    switch (tab) {
      case 0:
        return [
          _page(_PhonePage.home, const HomeScreen(tablet: false)),
          if (controller.creating)
            _page(
              _PhonePage.tripForm,
              TripFormScreen(onClose: controller.closeCreate),
            )
          else if (controller.homePushed && controller.current != null)
            _page(
              _PhonePage.tripDetail,
              TripDetailScreen(onClose: controller.closeHome),
            ),
        ];
      case 1:
        if (controller.current == null) {
          return [
            _page(
              _PhonePage.explore,
              const NeedTrip(
                title: '탐색',
                titleKey: Key('screen-title-explore'),
              ),
            ),
          ];
        }
        final place = controller.placeById(controller.selectedPlaceId);
        return [
          _page(_PhonePage.explore, const ExploreScreen(tablet: false)),
          if (controller.editingCity)
            _page(
              _PhonePage.cityEdit,
              CityEditScreen(onClose: controller.closeCityEdit),
            )
          else if (controller.explorePushed && place != null)
            _page(
              _PhonePage.place,
              PlacePanel(place: place, onClose: controller.closeExplore),
            ),
        ];
      case 2:
        if (controller.current == null) {
          return [
            _page(
              _PhonePage.itinerary,
              const NeedTrip(
                title: '일정',
                titleKey: Key('screen-title-itinerary'),
              ),
            ),
          ];
        }
        return [
          _page(
            _PhonePage.itinerary,
            const ItineraryScreen(tablet: false, wide: false),
          ),
          if (controller.itineraryPushed && controller.selectedItem() != null)
            _page(
              _PhonePage.item,
              ItemFacts(onClose: controller.closeItinerary),
            ),
        ];
      case 3:
        return [
          _page(_PhonePage.underway, const UnderwayScreen(tablet: false)),
        ];
      case 4:
        return [_page(_PhonePage.journal, const JournalScreen(tablet: false))];
      default:
        return [_page(_PhonePage.home, const SizedBox.shrink())];
    }
  }

  Page<void> _page(_PhonePage kind, Widget child) {
    return MaterialPage<void>(
      key: ValueKey(kind),
      name: kind.name,
      child: Material(color: AppColors.canvas, child: child),
    );
  }

  void _removed(Page<Object?> page) {
    final kind = (page.key as ValueKey<_PhonePage>?)?.value;
    final VoidCallback? close = switch (kind) {
      _PhonePage.tripForm when controller.creating => controller.closeCreate,
      _PhonePage.tripDetail when controller.homePushed => controller.closeHome,
      _PhonePage.cityEdit when controller.editingCity =>
        controller.closeCityEdit,
      _PhonePage.place when controller.explorePushed => controller.closeExplore,
      _PhonePage.item when controller.itineraryPushed =>
        controller.closeItinerary,
      _ => null,
    };
    if (close == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => close());
    } else {
      close();
    }
  }
}

enum _PhonePage {
  home,
  tripForm,
  tripDetail,
  explore,
  cityEdit,
  place,
  itinerary,
  item,
  underway,
  journal,
}

class _TabletFrame extends StatelessWidget {
  const _TabletFrame({required this.controller, required this.wide});

  final TripController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final editingCity = controller.tabIndex == 1 &&
        controller.editingCity &&
        controller.current != null;
    return PopScope(
      canPop: !editingCity,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && editingCity) controller.closeCityEdit();
      },
      child: Material(
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
        if (controller.current == null)
          return const NeedTrip(
            title: '탐색',
            titleKey: Key('screen-title-explore'),
          );
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
    if (controller.editingCity)
      return CityEditScreen(onClose: controller.closeCityEdit);
    if (place == null)
      return const EmptyPane(title: '장소', message: '장소를 고르세요.');
    if (!wide) return PlacePanel(place: place);
    return Row(
      children: [
        Expanded(
          child: PlacePanel(place: place, pane: FactPane.facts),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: PlacePanel(place: place, pane: FactPane.sources),
        ),
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
                            Icon(_destinations[i].icon,
                                size: 22,
                                color: i == index
                                    ? AppColors.accent
                                    : AppColors.secondary),
                            const SizedBox(height: 2),
                            Text(
                              _destinations[i].shortLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(
                                height: 1.1,
                                color: i == index
                                    ? AppColors.accent
                                    : AppColors.secondary,
                                fontWeight: i == index
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                        decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.accentSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Icon(_destinations[i].icon,
                                size: 22,
                                color: i == index
                                    ? AppColors.accent
                                    : AppColors.secondary),
                            const SizedBox(height: 2),
                            Text(
                              _destinations[i].shortLabel,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(
                                  color: i == index
                                      ? AppColors.accent
                                      : AppColors.secondary,
                                  fontWeight: i == index
                                      ? FontWeight.w600
                                      : FontWeight.w500),
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
