// 위젯에서 날짜를 눌러 앱으로 들어왔을 때, **새 달력 화면을 열지 않고** 지금 보고
// 있는 메인 화면에서 그 날짜가 선택되어야 한다.
//
// 예전에는 `:day`가 `/:year/:month`의 자식 라우트라 페이지가 하나 더 쌓여서 새 화면이
// 열린 것처럼 보였다. 지금은 형제 라우트 + NoTransitionPage라, 같은 달 안에서도
// 애니메이션 없이 선택 날짜가 바뀐다.
import 'package:catholic_calendar/app/router.dart';
import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/features/calendar/application/calendar_providers.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/calendar_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:catholic_calendar/features/widgets/widget_deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 화면에 그려진 날짜 칸 중 `isSelected`인 날(들).
  List<int> selectedDays(WidgetTester tester) => [
    for (final e in find.byType(DayNumber).evaluate())
      if ((e.widget as DayNumber).isSelected) (e.widget as DayNumber).date.day,
  ];

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liturgicalCalendarProvider.overrideWith(
            (ref) => CalendarService(engine: LiturgicalCalendar()),
          ),
          remoteCalendarSourceProvider.overrideWithValue(
            const RemoteCalendarSource(enabled: false),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('ko'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('메인 달력 좌우 제스처는 애니메이션 없이 월을 바꾼다', (tester) async {
    final router = await pump(tester);
    final initial = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;

    await tester.drag(find.byType(CalendarPage), const Offset(-120, 0));
    await tester.pump();

    expect(find.byType(CalendarPage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CalendarPage>(find.byType(CalendarPage)).month,
      initial.next,
    );
    expect(router.location, '/${initial.next.year}/${initial.next.month.toString().padLeft(2, '0')}');
  });

  testWidgets('같은 달 날짜 링크는 화면을 쌓지 않고 그 자리에서 선택만 바꾼다', (tester) async {
    final router = await pump(tester);

    // 시작: 현재 달(`initialLocation`), 선택 날짜 없음 → 달력 1개
    expect(find.byType(CalendarPage), findsOneWidget);
    final month = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;

    final target = resolveWidgetLink(
      Uri.parse(
        'catholiccalendar://day/'
        '${month.year}-${month.month.toString().padLeft(2, '0')}-15',
      ),
    )!;
    router.go(target.location);
    await tester.pumpAndSettle();

    // 핵심: 달력 페이지가 **하나**여야 한다(새 화면이 열리지 않음).
    expect(find.byType(CalendarPage), findsOneWidget, reason: '새 달력 화면이 쌓였다');
    expect(selectedDays(tester), [15]);
  });

  testWidgets('다른 달 날짜 링크도 달력 화면 하나만 유지한다', (tester) async {
    final router = await pump(tester);
    final month = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;
    final other = month.next.next;

    router.go(
      resolveWidgetLink(
        Uri.parse(
          'catholiccalendar://day/'
          '${other.year}-${other.month.toString().padLeft(2, '0')}-07',
        ),
      )!.location,
    );
    await tester.pump();
    expect(
      find.byType(CalendarPage),
      findsOneWidget,
      reason: '다른 달의 위젯 날짜 진입에 전환 애니메이션이 생겼다',
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPage), findsOneWidget);
    expect(tester.widget<CalendarPage>(find.byType(CalendarPage)).month, other);
    expect(selectedDays(tester), [7]);
  });

  testWidgets('같은 달에서 날짜만 바꿔 눌러도 그 자리에서 선택이 옮겨간다', (tester) async {
    final router = await pump(tester);
    final month = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    router.go(
      resolveWidgetLink(
        Uri.parse('catholiccalendar://day/$prefix-15'),
      )!.location,
    );
    await tester.pumpAndSettle();
    expect(selectedDays(tester), [15]);

    router.go(
      resolveWidgetLink(
        Uri.parse('catholiccalendar://day/$prefix-22'),
      )!.location,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(selectedDays(tester), [22], reason: '선택이 옮겨가지 않았다');
  });

  testWidgets('위젯 링크를 반복해서 눌러도 라우트 스택이 자라지 않는다', (tester) async {
    final router = await pump(tester);

    // 같은 달 · 다른 달 · 연도 경계를 섞어 여러 번 이동한다.
    for (final loc in [
      '/2026/08/15',
      '/2026/08/22',
      '/2026/07/10',
      '/2026/09/01',
      '/2026/12/25',
      '/2027/01/01',
      '/2026/08/21',
    ]) {
      router.go(loc);
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPage), findsOneWidget, reason: '$loc 에서 쌓였다');
      expect(
        router.routerDelegate.currentConfiguration.matches.length,
        1,
        reason: '$loc 에서 라우트 스택이 자랐다',
      );
      // 뒤로 갈 화면이 없어야 한다. 남아 있으면 달력이 겹쳐 쌓인 것이다.
      expect(router.canPop(), isFalse, reason: '$loc 에서 뒤로 갈 화면이 남았다');
    }
  });

  testWidgets('같은 달 안에서는 화면 전환 애니메이션조차 없다', (tester) async {
    // 위젯 날짜 라우트는 NoTransitionPage라 전환 중에도 달력이 하나뿐이어야 한다
    // (= push처럼 보이지 않는다).
    final router = await pump(tester);
    final month = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;
    final prefix = '${month.year}/${month.month.toString().padLeft(2, '0')}';

    router.go('/$prefix/15');
    await tester.pump();
    expect(find.byType(CalendarPage), findsOneWidget);
    // 전환 애니메이션이 있다면 이 시점에 나가는 페이지와 들어오는 페이지가 함께 있다.
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.byType(CalendarPage),
      findsOneWidget,
      reason: '같은 달인데 페이지 전환이 일어났다',
    );
    await tester.pumpAndSettle();
    expect(selectedDays(tester), [15]);
  });

  testWidgets('달만 지정한 링크(범위 밖 안내의 앱으로 이동하기)는 그 달을 열고 선택은 오늘', (tester) async {
    final router = await pump(tester);
    final month = tester.widget<CalendarPage>(find.byType(CalendarPage)).month;
    final other = month.previous.previous;

    router.go(
      resolveWidgetLink(
        Uri.parse(
          'catholiccalendar://month/'
          '${other.year}-${other.month.toString().padLeft(2, '0')}',
        ),
      )!.location,
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPage), findsOneWidget);
    final page = tester.widget<CalendarPage>(find.byType(CalendarPage));
    expect(page.month, other);
    expect(page.initialSelected, isNull);
    // 그 달에 오늘이 없으면 1일이 포커스된다(`_focusDate`).
    expect(selectedDays(tester), [1]);
  });
}
