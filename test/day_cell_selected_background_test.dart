// 와이드 셀(아이패드·맥·웹)에서 선택한 날은 셀 배경을 한 톤 어둡게 칠한다.
//
// 왜: 선택 표시가 날짜 숫자 뒤의 연회색 원(#D6D6D6) 하나뿐이라, 큰 화면에서 셀이
// 커지면 원이 셀 면적에 비해 너무 작아 어디를 골랐는지 눈에 들어오지 않았다.
// 폰(CompactDayCell)은 셀이 작아 원만으로 충분하므로 기존 동작을 그대로 둔다.
import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  final theme = AppTheme.light();
  final pageColor = theme.scaffoldBackgroundColor;
  final day = LiturgicalCalendar().day(DateTime(2026, 9, 22)); // 연중 평일

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ko'),
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 150, height: 93, child: child),
      ),
    ),
  );

  Widget wideCell({required bool isToday, required bool isSelected}) => DayCell(
    day: day,
    inCurrentMonth: true,
    isToday: isToday,
    isSelected: isSelected,
    onTap: () {},
  );

  /// 셀 전체 배경. 사각 [BoxDecoration]을 가진 Container는 셀 껍데기 하나뿐이다
  /// (날짜 원·일정 점은 원형 decoration).
  Color? cellFill(WidgetTester tester, Type cellType) {
    final finder = find.descendant(
      of: find.byType(cellType),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.rectangle,
      ),
    );
    if (finder.evaluate().isEmpty) return null;
    return (tester.widget<Container>(finder).decoration! as BoxDecoration).color;
  }

  testWidgets('와이드 셀: 선택하면 셀 배경이 페이지 배경보다 어두워진다', (tester) async {
    await tester.pumpWidget(wrap(wideCell(isToday: false, isSelected: true)));

    final fill = cellFill(tester, DayCell);
    expect(fill, isNotNull);
    expect(fill, isNot(pageColor));
    expect(
      fill!.computeLuminance(),
      lessThan(pageColor.computeLuminance()),
      reason: '선택 셀은 기본 배경보다 어두워야 눈에 띈다',
    );
  });

  testWidgets('와이드 셀: 오늘을 선택해도 셀 배경이 어두워진다', (tester) async {
    await tester.pumpWidget(wrap(wideCell(isToday: true, isSelected: true)));

    final fill = cellFill(tester, DayCell);
    expect(fill, isNotNull);
    expect(
      fill!.computeLuminance(),
      lessThan(pageColor.computeLuminance()),
    );
    // 오늘 표시(검정 원)는 그대로 남는다.
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('와이드 셀: 선택하지 않은 날은 페이지 배경 그대로다', (tester) async {
    await tester.pumpWidget(wrap(wideCell(isToday: false, isSelected: false)));

    expect(cellFill(tester, DayCell), pageColor);
  });

  testWidgets('폰 셀: 선택해도 셀 배경을 칠하지 않는다(기존 동작 유지)', (tester) async {
    await tester.pumpWidget(
      wrap(
        CompactDayCell(
          day: day,
          inCurrentMonth: true,
          isToday: false,
          isSelected: true,
          onTap: () {},
        ),
      ),
    );

    expect(cellFill(tester, CompactDayCell), isNull);
  });
}
