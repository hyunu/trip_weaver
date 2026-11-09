import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/data/sample_catalog.dart';
import 'package:trip_weave/logic/geocoder.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  test('상하이 사용자 여행도 일정 추가 검색에서 샘플 장소가 보인다', () {
    TripController.debugFixedNow = DateTime(2026, 11, 8, 10, 40);
    final catalog = buildSampleCatalog();
    final controller = TripController(
      now: TripController.debugFixedNow,
      catalog: catalog,
      geocoder: OfflineSampleGeocoder(),
      preloadSamples: false,
    );
    controller.trips = [
      Trip(
        id: 'user-sh',
        title: '상하이 test',
        countryCode: 'CN',
        countryName: '중국',
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 3),
        status: TripStatus.draft,
        purpose: 'test',
        tasteTags: const [],
        companionCount: 1,
        cities: [
          City(
            id: 'c1',
            name: '상하이',
            countryCode: 'CN',
            start: DateTime(2026, 12, 1),
            end: DateTime(2026, 12, 3),
            sortOrder: 0,
            coordinateConfirmed: true,
            coordinateLabel: '31.23, 121.47',
          ),
        ],
      ),
    ];
    controller.currentTripId = 'user-sh';
    controller.selectedDate = DateTime(2026, 12, 1);
    controller.onboardingComplete = true;

    expect(controller.placesForSelectedDay(query: '외탄'), isNotEmpty);
    expect(controller.placesForSelectedDay(query: ''), hasLength(5));

    TripController.debugFixedNow = null;
  });
}
