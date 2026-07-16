import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/calendar/application/calendar_providers.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/calendar_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

Widget _wrap(Widget child) => ProviderScope(
  // Inject the engine-only service (no CBCK snapshot) and disable the remote
  // gateway so tests never hit the network → falls back to the computed engine.
  overrides: [
    liturgicalCalendarProvider.overrideWith(
      (ref) => CalendarService(engine: LiturgicalCalendar()),
    ),
    remoteCalendarSourceProvider.overrideWithValue(
      const RemoteCalendarSource(enabled: false),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('month header and notable day names render', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle(); // resolve async month service

    expect(find.text('2026년 7월'), findsOneWidget); // colored header
    // Sundays are "notable" and show their name in the wide grid.
    expect(find.text('연중 제15주일'), findsWidgets); // 2026-07-12
  });

  testWidgets('day detail shows season, color and reading cycle', (
    tester,
  ) async {
    // 2026-12-25 — Christmas, white, holy day of obligation.
    final day = LiturgicalCalendar().day(DateTime(2026, 12, 25));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pump();

    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('백색'), findsOneWidget);
    expect(find.text('의무 축일'), findsOneWidget);
    // 2026-12-25 falls in the 2026–27 liturgical year (Advent began Nov 29) = 나해(B).
    expect(find.textContaining('나해'), findsOneWidget);
  });
}
