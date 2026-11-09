import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shell/adaptive_shell.dart';
import 'shell/scope.dart';
import 'state/trip_controller.dart';
import 'theme/app_theme.dart';

class TripWeaveApp extends StatefulWidget {
  const TripWeaveApp({super.key, this.now, this.controller});

  final DateTime? now;
  final TripController? controller;

  @override
  State<TripWeaveApp> createState() => _TripWeaveAppState();
}

class _TripWeaveAppState extends State<TripWeaveApp> {
  late final TripController controller;
  late final bool owned;

  @override
  void initState() {
    super.initState();
    owned = widget.controller == null;
    controller = widget.controller ?? TripController(now: widget.now);
  }

  @override
  void dispose() {
    if (owned) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TripScope(
      controller: controller,
      child: MaterialApp(
        title: 'TripWeave',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        scrollBehavior: const _AppScrollBehavior(),
        home: const AdaptiveShell(),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics();
}

void main() {
  runApp(const TripWeaveApp(now: null));
}
