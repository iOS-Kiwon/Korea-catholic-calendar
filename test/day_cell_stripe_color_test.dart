// 그리드 셀 상단의 3px 띠는 **그날의 전례색만** 나타낸다(범례: 연중=녹, 축일·성인=백,
// 사도·순교=홍, 사순·대림=자).
//
// 회귀 이력: 커밋 74863f9에서 띠 색을 `accent`(전례색) → `titleAccent`(라벨 글자색)로
// 바꿨다. `titleAccent`는 셀 글자가 전례명이 아니라 공휴일 이름일 때 공휴일 빨강
// `#C62828`으로 강제되는데, 이 값은 전례색 홍색과 **완전히 같다**. 그래서 2026-09-25
// 한가위(백색)의 띠가 빨강으로 칠해져 사도·순교일처럼 보였고, 추석연휴(녹색)도 같았다.
import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/app/theme/liturgical_colors.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

const _holidayRed = Color(0xFFC62828);

void main() {
  final engine = LiturgicalCalendar();

  /// 2026-09-25 한가위: 전례색 백색, rank는 feria(공식 데이터에 rank가 없어 폴백).
  final whiteHolidayDay = engine
      .day(DateTime(2026, 9, 25))
      .copyWith(color: LiturgicalColor.white);

  /// 2026-09-21 성 마태오 사도 복음사가 축일: 전례색 홍색.
  final redFeastDay = engine
      .day(DateTime(2026, 9, 21))
      .copyWith(color: LiturgicalColor.red);

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ko'),
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 150, height: 93, child: child),
      ),
    ),
  );

  /// 셀 상단 띠에 실제로 칠해진 색. `Container(height: 3, color: ...)` 하나뿐이므로
  /// `color`가 지정된 Container로 특정한다(날짜 원·일정 점은 decoration을 쓴다).
  Color? stripeColor(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(DayCell),
      matching: find.byWidgetPredicate((w) => w is Container && w.color != null),
    );
    return tester.widget<Container>(finder).color;
  }

  testWidgets('공휴일 이름이 셀 라벨이어도 띠는 그날의 전례색이다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DayCell(
          day: whiteHolidayDay,
          inCurrentMonth: true,
          isToday: false,
          isSelected: false,
          isKoreanHoliday: true,
          isKoreanHolidayTitle: true,
          shortTitle: '추석',
          onTap: () {},
        ),
      ),
    );

    expect(stripeColor(tester), LiturgicalColors.light.white);
    // 공휴일 빨강은 전례색 홍색과 값이 같아, 이 단정이 곧 "사도·순교로 오독되지 않는다".
    expect(stripeColor(tester), isNot(_holidayRed));
  });

  testWidgets('공휴일 이름 글자색은 빨강을 유지한다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DayCell(
          day: whiteHolidayDay,
          inCurrentMonth: true,
          isToday: false,
          isSelected: false,
          isKoreanHoliday: true,
          isKoreanHolidayTitle: true,
          shortTitle: '추석',
          onTap: () {},
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('추석')).style?.color, _holidayRed);
  });

  testWidgets('전례색이 홍색인 축일의 띠는 홍색이다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DayCell(
          day: redFeastDay,
          inCurrentMonth: true,
          isToday: false,
          isSelected: false,
          shortTitle: '성 마태오',
          onTap: () {},
        ),
      ),
    );

    expect(stripeColor(tester), LiturgicalColors.light.red);
  });
}
