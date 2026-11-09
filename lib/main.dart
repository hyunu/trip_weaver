import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shell/adaptive_shell.dart';
import 'shell/scope.dart';
import 'logic/geocoder.dart';
import 'state/trip_controller.dart';
import 'state/trip_store.dart';
import 'theme/app_theme.dart';
import 'widgets/live_clock.dart';

class TripWeaveApp extends StatefulWidget {
  const TripWeaveApp({super.key, this.now, this.controller});

  final DateTime? now;
  final TripController? controller;

  @override
  State<TripWeaveApp> createState() => _TripWeaveAppState();
}

class _TripWeaveAppState extends State<TripWeaveApp> with WidgetsBindingObserver {
  TripController? controller;
  late final bool owned;
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _heardSaveSnack;
  String? _heardRestore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    owned = widget.controller == null;
    if (widget.controller != null) {
      controller = widget.controller;
      widget.controller!.addListener(_onController);
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
    final next = TripController(now: widget.now, store: store, geocoder: CompositeCityGeocoder());
    await next.restore();
    if (!mounted) {
      next.dispose();
      return;
    }
    next.addListener(_onController);
    setState(() => controller = next);
    _onController();
  }

  void _onController() {
    final ready = controller;
    if (ready == null) return;
    final messenger = _messengerKey.currentState;
    final restore = ready.restoreNotice;
    if (restore != null && restore != _heardRestore && messenger != null) {
      _heardRestore = restore;
      messenger.showSnackBar(
        SnackBar(
          content: Text(restore.split('\n').first),
          action: SnackBarAction(label: '확인', onPressed: ready.clearRestoreNotice),
          duration: const Duration(seconds: 8),
        ),
      );
      ready.clearRestoreNotice();
    }
    final saveSnack = ready.lastSaveSnack;
    if (saveSnack != null && saveSnack != _heardSaveSnack && messenger != null) {
      _heardSaveSnack = saveSnack;
      messenger.showSnackBar(
        SnackBar(
          content: Text(saveSnack),
          action: SnackBarAction(label: '다시 시도', onPressed: ready.retrySave),
        ),
      );
      ready.clearSaveSnack();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller?.refreshClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.removeListener(_onController);
    if (owned) controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller;
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
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
      home: ready == null
          ? const _BootSplash()
          : TripScope(
              controller: ready,
              child: LiveClockScope(controller: ready, child: const AdaptiveShell()),
            ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 16),
            Text('여행 불러오는 중…', style: AppType.body),
          ],
        ),
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
  runApp(const TripWeaveApp());
}
