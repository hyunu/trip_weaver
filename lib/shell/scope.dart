import 'package:flutter/widgets.dart';

import '../state/trip_controller.dart';

class TripScope extends InheritedNotifier<TripController> {
  const TripScope({super.key, required TripController controller, required super.child}) : super(notifier: controller);

  static TripController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TripScope>();
    assert(scope != null, 'TripScope가 없습니다.');
    return scope!.notifier!;
  }
}

class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({super.key, required this.tablet, required this.wide, required super.child});

  final bool tablet;
  final bool wide;

  static AdaptiveScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdaptiveScope>();
    assert(scope != null, 'AdaptiveScope가 없습니다.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AdaptiveScope oldWidget) => tablet != oldWidget.tablet || wide != oldWidget.wide;
}

class ShellMetrics {
  ShellMetrics(Size size)
    : tablet = size.shortestSide >= 600,
      wide = size.shortestSide >= 600 && size.longestSide >= 1100;

  final bool tablet;
  final bool wide;
}
