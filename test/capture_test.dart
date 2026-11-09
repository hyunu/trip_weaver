import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/map/osm_tiles.dart';
import 'package:trip_weave/state/trip_controller.dart';

final _media = Platform.environment['CAPTURE_DIR'] ?? 'build/captures';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('다섯 탭 화면을 저장한다', (tester) async {
    debugPrint('capture: start');
    await tester.runAsync(_loadFonts);
    await tester.runAsync(warmSampleMap);
    debugPrint('capture: fonts');

    await _setView(tester, const Size(390, 844));
    var controller = TripController();
    await tester.pumpWidget(TripWeaveApp(key: const ValueKey('phone'), controller: controller));
    await tester.pumpAndSettle();
    await _save(tester, 'phone-home');

    await tester.tap(find.byKey(const Key('tab-explore')));
    await tester.pumpAndSettle();
    await _save(tester, 'phone-explore');

    await _tapCard(tester, find.byKey(const Key('place-card-gallery')));
    await _save(tester, 'phone-explore-place');

    await tester.tap(find.byKey(const Key('tab-itinerary')));
    await tester.pumpAndSettle();
    await _save(tester, 'phone-itinerary');

    await _reveal(tester, find.byKey(const Key('item-d1108-meal')), find.byKey(const Key('itinerary-scroll')));
    await _save(tester, 'phone-itinerary-later');

    await tester.tap(find.byKey(const Key('tab-underway')));
    await tester.pumpAndSettle();
    await _save(tester, 'phone-underway');

    await tester.tap(find.byKey(const Key('tab-journal')));
    await tester.pumpAndSettle();
    await _save(tester, 'phone-journal');

    await _setView(tester, const Size(1024, 1366));
    controller = TripController();
    await tester.pumpWidget(TripWeaveApp(key: const ValueKey('ipad'), controller: controller));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-home');

    await tester.tap(find.byKey(const Key('rail-explore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-card-gallery')));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-explore');

    await tester.tap(find.byKey(const Key('rail-itinerary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-d1108-gallery')));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-itinerary');

    await tester.tap(find.byKey(const Key('rail-underway')));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-underway');

    await tester.tap(find.byKey(const Key('rail-journal')));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-journal');

    await _setView(tester, const Size(1194, 834));
    controller = TripController();
    await tester.pumpWidget(TripWeaveApp(key: const ValueKey('landscape'), controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rail-explore')));
    await tester.pumpAndSettle();
    await _tapCard(tester, find.byKey(const Key('place-card-gallery')));
    await _save(tester, 'ipad-landscape-explore');

    await tester.tap(find.byKey(const Key('rail-itinerary')));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('item-d1108-gallery')), find.byKey(const Key('itinerary-scroll')));
    await tester.tap(find.byKey(const Key('item-d1108-gallery')));
    await tester.pumpAndSettle();
    await _save(tester, 'ipad-landscape-itinerary');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Pretendard');
  for (final file in ['Pretendard-Regular.otf', 'Pretendard-Medium.otf', 'Pretendard-SemiBold.otf', 'Pretendard-Bold.otf']) {
    loader.addFont(rootBundle.load('fonts/$file'));
  }
  await loader.load();
  final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
  await icons.load();
}

Future<void> _save(WidgetTester tester, String name) async {
  debugPrint('capture: settle $name');
  await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
  debugPrint('capture: raster $name');
  final boundary = tester.renderObject(find.byKey(const Key('capture-root'))) as RenderRepaintBoundary;
  final image = boundary.toImageSync(pixelRatio: 2);
  debugPrint('capture: encode $name ${image.width}x${image.height}');
  final data = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)).timeout(const Duration(seconds: 15));
  final file = File('$_media/$name.png');
  await tester.runAsync(() => file.parent.create(recursive: true));
  await tester.runAsync(() => file.writeAsBytes(data!.buffer.asUint8List(), flush: true));
  image.dispose();
  debugPrint('capture: wrote $name');
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder list) async {
  final scrollables = find.descendant(of: list, matching: find.byType(Scrollable));
  for (var attempt = 0; attempt < 12; attempt++) {
    if (tester.any(target)) {
      final top = tester.getTopLeft(target);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (top.dy >= 8 && top.dy < height - 80) return;
    }
    final states = tester.stateList<ScrollableState>(scrollables);
    if (states.isEmpty) return;
    final position = states.first.position;
    final next = position.pixels + 240;
    if (next > position.maxScrollExtent && tester.any(target)) return;
    position.jumpTo(next.clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapCard(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder, find.byKey(const Key('explore-scroll')));
  final top = tester.getTopLeft(finder);
  await tester.tapAt(top + const Offset(24, 16));
  await tester.pumpAndSettle();
}

Future<void> _setView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final phone = size.shortestSide < 600;
  final padding = FakeViewPadding(left: 0, top: phone ? 54 : 24, right: 0, bottom: phone ? 34 : 20);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}
