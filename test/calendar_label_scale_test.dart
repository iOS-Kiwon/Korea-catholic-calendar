// OS 글꼴 확대 / 굵은 글씨 / 줄간격 접근성 설정에서 달력 grid 셀의 전례명이
// 세로로 잘리지 않는지 검증.
//
// 잘림의 메커니즘: `Expanded`가 라벨 `Text`에 tight 높이를 강제하는데,
// `TextOverflow.ellipsis`는 `maxLines` 초과에만 `…`를 넣고 박스 높이 초과는
// 조용히 잘라낸다(rendering/paragraph.dart:949). 예외를 던지지 않으므로
// `expectNoVerticalTextClip`으로 명시적으로 단정해야 잡힌다.
import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_clip.dart';

/// 폰 레이아웃의 실제 셀 크기: 행 높이 70, 폭 (390 - 16) / 7.
const _compactCellWidth = 53.4;
const _compactRowHeight = 70.0;

/// 와이드 레이아웃의 실제 셀 크기: 행 높이 93.
const _wideCellWidth = 150.0;
const _wideRowHeight = 93.0;

/// 축약명이 없어 전체 전례명이 그대로 들어오는 경우를 대표하는 라벨.
/// `liturgical_display_filter.dart:68`의 `day.title` 폴백 경로가 이렇게 동작한다.
const _longLabel = '성 마리아 막달레나 기념';

void main() {
  final day = LiturgicalCalendar().day(DateTime(2026, 8, 15));

  Widget wrapCell(Widget child, {required double width, required double height}) =>
      MaterialApp(
        locale: const Locale('ko'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );

  Widget compactCell({String label = _longLabel, int titleMaxLines = 3}) =>
      CompactDayCell(
        day: day,
        inCurrentMonth: true,
        isToday: false,
        isSelected: false,
        shortTitle: label,
        titleMaxLines: titleMaxLines,
        onTap: () {},
      );

  Widget wideCell({String label = _longLabel}) => DayCell(
    day: day,
    inCurrentMonth: true,
    isToday: false,
    isSelected: false,
    shortTitle: label,
    onTap: () {},
  );

  /// 라벨을 그리는 문단의 `maxLines`. 라벨이 숨겨졌으면 0.
  int labelLines(WidgetTester tester, String label) {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) return 0;
    return tester.widget<Text>(finder).maxLines ?? 0;
  }

  group('폰 셀(행 70) - 배율/굵게 조합에서 전례명이 세로로 잘리지 않는다', () {
    for (final scale in const [1.0, 1.07, 1.15, 1.3, 1.5, 2.0, 3.0]) {
      for (final bold in const [false, true]) {
        testWidgets('배율 $scale, 굵게 $bold', (tester) async {
          setSystemTextSettings(
            tester,
            textScaleFactor: scale,
            boldText: bold,
          );

          await tester.pumpWidget(
            wrapCell(
              compactCell(),
              width: _compactCellWidth,
              height: _compactRowHeight,
            ),
          );

          expect(tester.takeException(), isNull);
          expectNoVerticalTextClip(tester, ignore: isDateNumber);
        });
      }
    }
  });

  group('와이드 셀(행 93) - 배율/굵게 조합에서 전례명이 세로로 잘리지 않는다', () {
    for (final scale in const [1.0, 1.02, 1.15, 1.3, 1.5, 2.0, 3.0]) {
      for (final bold in const [false, true]) {
        testWidgets('배율 $scale, 굵게 $bold', (tester) async {
          setSystemTextSettings(
            tester,
            textScaleFactor: scale,
            boldText: bold,
          );

          await tester.pumpWidget(
            wrapCell(
              wideCell(),
              width: _wideCellWidth,
              height: _wideRowHeight,
            ),
          );

          expect(tester.takeException(), isNull);
          expectNoVerticalTextClip(tester, ignore: isDateNumber);
        });
      }
    }
  });

  group('플랫폼 줄간격 오버라이드 - 글꼴 크기를 키우지 않아도 줄높이가 커진다', () {
    // `Text`가 `MediaQuery.maybeLineHeightScaleFactorOverrideOf`를 자동 적용하고
    // (text.dart:728) `style.merge`로 `TextStyle.height`를 **교체**하므로
    // (text.dart:1535) 배율 1.0에서도 라벨이 잘릴 수 있다.
    for (final lineHeight in const [1.3, 1.6, 2.0]) {
      testWidgets('폰 셀, 줄간격 오버라이드 $lineHeight', (tester) async {
        setSystemTextSettings(
          tester,
          lineHeightScaleFactorOverride: lineHeight,
        );

        await tester.pumpWidget(
          wrapCell(
            compactCell(),
            width: _compactCellWidth,
            height: _compactRowHeight,
          ),
        );

        expect(tester.takeException(), isNull);
        expectNoVerticalTextClip(tester, ignore: isDateNumber);
      });

      testWidgets('와이드 셀, 줄간격 오버라이드 $lineHeight', (tester) async {
        setSystemTextSettings(
          tester,
          lineHeightScaleFactorOverride: lineHeight,
        );

        await tester.pumpWidget(
          wrapCell(wideCell(), width: _wideCellWidth, height: _wideRowHeight),
        );

        expect(tester.takeException(), isNull);
        expectNoVerticalTextClip(tester, ignore: isDateNumber);
      });
    }
  });

  testWidgets('작은 글꼴을 더 키우는 비선형 스케일러에서도 잘리지 않는다', (tester) async {
    // Android 14+ 비선형 스케일링. `fontSize * textScaleFactor`로 계산하는 코드는
    // 이 케이스에서 반드시 틀린다.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const _NonLinearTextScaler()),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: _compactCellWidth,
                  height: _compactRowHeight,
                  child: compactCell(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expectNoVerticalTextClip(tester, ignore: isDateNumber);
  });

  testWidgets('배율이 오르면 줄 수가 3 → 2 → 1 → 숨김으로 강등된다', (tester) async {
    Future<int> linesAt(double scale) async {
      setSystemTextSettings(tester, textScaleFactor: scale);
      await tester.pumpWidget(
        wrapCell(
          compactCell(),
          width: _compactCellWidth,
          height: _compactRowHeight,
        ),
      );
      expectNoVerticalTextClip(tester, ignore: isDateNumber);
      return labelLines(tester, _longLabel);
    }

    // 배율 1.0에서는 지금과 동일하게 3줄이어야 한다(픽셀 무변화 보증).
    expect(await linesAt(1.0), 3);
    // 라벨 박스 32px에 3줄이 안 들어가는 순간부터 강등된다.
    expect(await linesAt(1.15), 2);
    expect(await linesAt(2.0), lessThanOrEqualTo(2));
    // 라벨 전용 상한(1.5) 때문에 그리드에서는 한 줄도 못 넣는 구간에 도달하지 않는다.
    expect(await linesAt(3.0), greaterThanOrEqualTo(1));
  });

  testWidgets('배율 1.0 기준선 - 라벨 기하가 수정 전과 픽셀 단위로 같다', (tester) async {
    // 수정 전 코드에서 실측한 값이다. `strutStyle`이 줄 높이를 강제하고
    // `leadingDistribution: even`이 M3 geometry와 일치하므로 baseline이 유지된다.
    // 이 값이 깨지면 배율 1.0 사용자에게 보이는 화면이 바뀐 것이다.
    setSystemTextSettings(tester);

    await tester.pumpWidget(
      wrapCell(
        compactCell(),
        width: _compactCellWidth,
        height: _compactRowHeight,
      ),
    );

    final finder = find.descendant(
      of: find.text(_longLabel),
      matching: find.byType(RichText),
    );
    final label = tester.renderObject<RenderParagraph>(finder);

    expect(label.size, const Size(51.4, 32.0));
    expect(label.textSize, const Size(51.4, 30.0));
    expect(label.maxLines, 3);
    expect(label.preferredLineHeight, 10.0);
    expect(tester.getTopLeft(finder), const Offset(374.3, 303.0));
  });

  testWidgets('라벨은 상한을 받지만 같은 셀의 날짜 숫자는 전체 배율을 받는다', (tester) async {
    setSystemTextSettings(tester, textScaleFactor: 3.0, boldText: true);

    await tester.pumpWidget(
      wrapCell(
        compactCell(),
        width: _compactCellWidth,
        height: _compactRowHeight,
      ),
    );

    final label = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text(_longLabel),
        matching: find.byType(RichText),
      ),
    );
    final number = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text('15'), matching: find.byType(RichText)),
    );

    // 라벨: 배율 상한 1.5 → 10 * 1.5 = 15
    expect(label.textScaler.scale(10), closeTo(15, 0.01));
    // 라벨: 굵은 글씨 무효화 → w600 유지 (Text가 merge하는 w700이 아님)
    expect(
      (label.text as TextSpan).style?.fontWeight,
      FontWeight.w600,
      reason: 'grid 라벨에서는 boldText를 무효화한다',
    );
    // 날짜 숫자: 상한 없음 → 18 * 3.0 = 54, 굵게 적용 유지
    expect(number.textScaler.scale(18), closeTo(54, 0.01));
    expect((number.text as TextSpan).style?.fontWeight, FontWeight.bold);
  });

  group('MonthGrid 통합', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget wrapGrid({required double height, required bool compact}) =>
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ko'),
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                width: compact ? 390 : 1200,
                height: height,
                child: MonthGrid(
                  calendar: CalendarService(engine: LiturgicalCalendar()),
                  month: const YearMonth(2026, 5),
                  today: DateTime(2026, 5, 1),
                  selectedDate: null,
                  onSelectDay: (_) {},
                  compact: compact,
                  fixedRowHeight: compact ? _compactRowHeight : _wideRowHeight,
                ),
              ),
            ),
          ),
        );

    for (final scale in const [1.0, 1.15, 1.5, 2.0]) {
      testWidgets('폰 그리드 6줄, 배율 $scale', (tester) async {
        setSystemTextSettings(tester, textScaleFactor: scale, boldText: true);
        await tester.pumpWidget(wrapGrid(height: 420, compact: true));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectNoVerticalTextClip(
          tester,
          within: find.byType(MonthGrid),
          ignore: isDateNumber,
        );
      });

      testWidgets('와이드 그리드 6줄, 배율 $scale', (tester) async {
        setSystemTextSettings(tester, textScaleFactor: scale, boldText: true);
        await tester.pumpWidget(wrapGrid(height: 558, compact: false));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectNoVerticalTextClip(
          tester,
          within: find.byType(MonthGrid),
          ignore: isDateNumber,
        );
      });
    }
  });
}

/// 작은 글꼴을 더 많이 키우는 비선형 스케일러.
/// `textScaleFactor`와 `scale()`을 의도적으로 불일치시켜, 곱셈으로 추정하는
/// 코드가 있으면 틀리게 만든다.
class _NonLinearTextScaler extends TextScaler {
  const _NonLinearTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 12 ? fontSize * 1.9 : fontSize * 1.1;

  @override
  double get textScaleFactor => 1.1;
}
