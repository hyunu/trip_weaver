import 'dart:async';

import 'package:trip_weave/state/trip_controller.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TripController.debugFixedNow = sampleNow;
  await testMain();
}
