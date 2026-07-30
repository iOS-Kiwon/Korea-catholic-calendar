// 와이드 달력 셀(DayCell)이 전례일 표시 필터(shortTitle == null)를 그대로 따르는지 검증.
// (compact 셀은 이미 shortTitle로 게이팅하고 있었으나, 와이드 셀은 day.title로 폴백하며
// notable(=rank != feria) 여부로만 게이팅해 필터가 무시되는 버그가 있었다.)
import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  // 2026-08-15 성모 승천 대축일: notable(=rank != feria)한 날.
  final notableDay = LiturgicalCalendar().day(DateTime(2026, 8, 15));

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(width: 120, height: 100, child: child),
    ),
  );

  testWidgets('shortTitle이 null이면 notable한 날이어도 전례일 제목을 숨긴다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DayCell(
          day: notableDay,
          inCurrentMonth: true,
          isToday: false,
          isSelected: false,
          onTap: () {},
          shortTitle: null,
        ),
      ),
    );

    // 필터에 의해 숨겨진 상태(shortTitle: null)이므로 day.title 폴백이 노출되면 안 된다.
    expect(find.textContaining('승천'), findsNothing);
    // 날짜 숫자는 항상 표시된다.
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('shortTitle이 있으면 해당 라벨을 표시한다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DayCell(
          day: notableDay,
          inCurrentMonth: true,
          isToday: false,
          isSelected: false,
          onTap: () {},
          shortTitle: '테스트라벨',
        ),
      ),
    );

    expect(find.text('테스트라벨'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });
}
