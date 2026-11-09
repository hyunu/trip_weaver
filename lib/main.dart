import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shell/adaptive_shell.dart';
import 'shell/scope.dart';
import 'state/trip_controller.dart';
import 'state/trip_store.dart';
import 'theme/app_theme.dart';

class TripWeaveApp extends StatefulWidget {
  const TripWeaveApp({super.key, this.now, this.controller});

  final DateTime? now;
  final TripController? controller;

  @override
  State<TripWeaveApp> createState() => _TripWeaveAppState();
}

class _TripWeaveAppState extends State<TripWeaveApp> {
  TripController? controller;
  late final bool owned;

  @override
  void initState() {
    super.initState();
    owned = widget.controller == null;
    if (widget.controller != null) {
      controller = widget.controller;
    } else {
      _openStoredTrips();
    }
  }

  Future<void> _openStoredTrips() async {
    FileTripStore? store;
    try {
      store = await FileTripStore.open();
    } on Object {
      store = null;
    }
    final next = TripController(now: widget.now, store: store);
    await next.restore();
    if (!mounted) {
      next.dispose();
      return;
    }
    setState(() => controller = next);
  }

  @override
  void dispose() {
    if (owned) controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller;
    if (ready == null) {
      return const MaterialApp(home: SizedBox.shrink());
    }
    return TripScope(
      controller: ready,
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
