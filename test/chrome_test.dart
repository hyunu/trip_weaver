import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/model/models.dart';
import 'package:trip_weave/theme/app_theme.dart';
import 'package:trip_weave/widgets/chrome.dart';
import 'package:trip_weave/widgets/schedule_block.dart';

void main() {
  testWidgets('배너, 빈 상태, 버튼 단계가 한 세트로 보인다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const StatusBanners(sample: true, offline: true),
              const SampleBanner(visible: false),
              const EmptyPane(title: '장소', message: '장소를 고르세요.'),
              AppButton(label: '보조', filled: false, onPressed: () => taps++),
              const AppButton(label: '끔', onPressed: null),
              AppButton(label: '선택됨', filled: false, selected: true, onPressed: () {}),
              AppButton(label: '삭제', filled: false, destructive: true, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.text('샘플 데이터입니다. 실제 장소 정보가 아닙니다.'), findsOneWidget);
    expect(find.text('오프라인. 저장된 데이터만 표시합니다.'), findsOneWidget);
    expect(find.text('장소를 고르세요.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('sample-banner')), matching: find.byType(IconButton)), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: MapTileNotice()),
      ),
    );
    expect(find.text('지도 타일을 불러오지 못했습니다. 연결을 확인하세요.'), findsOneWidget);
    expect(find.byKey(const Key('map-tile')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              AppButton(label: '보조', filled: false, onPressed: () => taps++),
              const AppButton(label: '끔', onPressed: null),
              AppButton(label: '선택됨', filled: false, selected: true, onPressed: () {}),
              AppButton(label: '삭제', filled: false, destructive: true, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    final secondary = tester.widget<TextButton>(find.widgetWithText(TextButton, '보조'));
    expect(secondary.style!.backgroundColor!.resolve({}), AppColors.card);
    await tester.tap(find.text('보조'));
    expect(taps, 1);

    final disabled = tester.widget<TextButton>(find.widgetWithText(TextButton, '끔'));
    expect(disabled.onPressed, isNull);

    final selected = tester.widget<TextButton>(find.widgetWithText(TextButton, '선택됨'));
    expect(selected.style!.backgroundColor!.resolve({}), AppColors.accentSoft);

    final danger = tester.widget<TextButton>(find.widgetWithText(TextButton, '삭제'));
    expect(danger.style!.foregroundColor!.resolve({}), AppColors.danger);
  });

  testWidgets('일정 블록은 제안과 충돌을 칩으로 보여 준다', (tester) async {
    final item = PlanItem(
      id: 'block',
      kind: ItemKind.stay,
      title: '전망대',
      categoryLabel: '관광지',
      unconfirmedFields: const ['운영시간'],
      hoursConflict: true,
      locked: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleBlock(item: item, proposal: true, emphasize: true),
        ),
      ),
    );
    expect(find.text('제안'), findsOneWidget);
    expect(find.text('미확인 값'), findsOneWidget);
    expect(find.text('충돌'), findsOneWidget);
    expect(find.text('고정'), findsOneWidget);
    expect(tester.widget<Text>(find.text('전망대')).style!.fontSize, 20);
    expect(tester.getTopLeft(find.text('체류')).dy, lessThan(tester.getTopLeft(find.text('미확인 값')).dy));
  });
}
