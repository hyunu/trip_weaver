import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_weave/main.dart';
import 'package:trip_weave/model/journal.dart';
import 'package:trip_weave/state/trip_controller.dart';

void main() {
  test('하루 이야기는 여행과 날짜마다 남고 빈 글은 지운다', () {
    final book = JournalBook();
    final day = DateTime(2026, 11, 8, 10, 40);
    expect(book.save('trip-river', day, '   '), isFalse);
    expect(book.text('trip-river', day), isNull);
    expect(book.save('trip-river', day, '  외탄을 걸었다  '), isTrue);
    expect(book.text('trip-river', DateTime(2026, 11, 8)), '외탄을 걸었다');
    expect(book.save('trip-river', day, '외탄을 걸었다'), isFalse);
    expect(book.save('trip-river', DateTime(2026, 11, 9), '시장'), isTrue);
    expect(book.text('trip-south', day), isNull);
    expect(book.save('trip-river', DateTime(2026, 11, 9), ''), isTrue);
    expect(book.has('trip-river', DateTime(2026, 11, 9)), isFalse);
    expect(book.text('trip-river', day), '외탄을 걸었다');
    expect(journalDayKey(day), '2026-11-08');
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('하루 이야기를 저장하고 날짜를 바꿔도 남는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    const padding = FakeViewPadding(left: 0, top: 54, right: 0, bottom: 34);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(tester.view.reset);

    final controller = TripController();
    await tester.pumpWidget(TripWeaveApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-journal')));
    await tester.pumpAndSettle();

    expect(find.text('사진과 여행 기록은 사진 단계에서 사용할 수 있습니다.'), findsOneWidget);
    expect(find.text('작성된 이야기가 없습니다.'), findsOneWidget);
    expect(find.text('사진 찍기'), findsNothing);

    final field = find.byKey(const Key('journal-story'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '외탄을 걸었다');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-journal')));
    await tester.tap(find.byKey(const Key('save-journal')));
    await tester.pumpAndSettle();

    expect(controller.journalText(), '외탄을 걸었다');
    expect(find.text('이 기기에만 저장된 이야기'), findsOneWidget);
    expect(find.text('기록 있음'), findsWidgets);

    await tester.ensureVisible(find.text('11.9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11.9'));
    await tester.pumpAndSettle();
    expect(find.text('작성된 이야기가 없습니다.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('journal-story'))).controller!.text, isEmpty);

    await tester.ensureVisible(find.text('11.8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11.8'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('journal-story'))).controller!.text, '외탄을 걸었다');

    await tester.enterText(find.byKey(const Key('journal-story')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-journal')));
    await tester.pumpAndSettle();
    expect(controller.journalText(), isNull);
    expect(find.text('작성된 이야기가 없습니다.'), findsOneWidget);
    expect(find.text('기록 있음'), findsNothing);
  });
}
