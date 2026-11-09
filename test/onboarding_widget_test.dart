import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/state/trip_controller.dart';
import 'package:trip_weave/logic/geocoder.dart';

void main() {
  testWidgets('온보딩에서 샘플 둘러보기를 누르면 홈으로 전환된다', (tester) async {
  TripController.debugFixedNow = DateTime(2026, 11, 8, 10, 40);
    final controller = TripController(
      now: TripController.debugFixedNow,
      geocoder: OfflineSampleGeocoder(),
      preloadSamples: false,
    );
    controller.onboardingComplete = false;
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-welcome')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-browse-samples')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-choice')), findsNothing);
    expect(find.byKey(const Key('capture-root')), findsOneWidget);
    expect(controller.sampleTrips, isNotEmpty);
    TripController.debugFixedNow = null;
  });

  testWidgets('온보딩에서 여행 만들기를 누르면 작성 화면이 열린다', (tester) async {
    TripController.debugFixedNow = DateTime(2026, 11, 8, 10, 40);
    final controller = TripController(
      now: TripController.debugFixedNow,
      geocoder: OfflineSampleGeocoder(),
      preloadSamples: false,
    );
    controller.onboardingComplete = false;
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('form-heading')), findsOneWidget);
    TripController.debugFixedNow = null;
  });
}
