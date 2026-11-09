import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/state/trip_controller.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TripController.debugFixedNow = sampleNow;
  await warmSampleMap();
  await testMain();
}
