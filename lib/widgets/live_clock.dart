import 'dart:async';

import 'package:flutter/material.dart';

import '../state/trip_controller.dart';

/// Keeps a live [TripController] clock fresh while the app is visible.
class LiveClockScope extends StatefulWidget {
  const LiveClockScope({super.key, required this.controller, required this.child});

  final TripController controller;
  final Widget child;

  @override
  State<LiveClockScope> createState() => _LiveClockScopeState();
}

class _LiveClockScopeState extends State<LiveClockScope> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armTimer();
    widget.controller.refreshClock();
  }

  @override
  void didUpdateWidget(covariant LiveClockScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _armTimer();
      widget.controller.refreshClock();
    }
  }

  void _armTimer() {
    _timer?.cancel();
    if (widget.controller.fixedClock) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => widget.controller.refreshClock());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refreshClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
