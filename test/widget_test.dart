import 'dart:convert';

import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/calendar/application/calendar_providers.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/calendar_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_detail_view.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:catholic_calendar/features/events/presentation/category_manager_page.dart'
    show CategoryPickerPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A no-op notification service so tests never touch platform channels.
class _FakeNotifications implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events) async {}
}

Widget _wrap(Widget child) => ProviderScope(
  // Inject the engine-only service (no CBCK snapshot) and disable the remote
  // gateway so tests never hit the network → falls back to the computed engine.
  // Notifications are stubbed to avoid platform channels.
  overrides: [
    liturgicalCalendarProvider.overrideWith(
      (ref) => CalendarService(engine: LiturgicalCalendar()),
    ),
    remoteCalendarSourceProvider.overrideWithValue(
      const RemoteCalendarSource(enabled: false),
    ),
    notificationServiceProvider.overrideWithValue(_FakeNotifications()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUp(() {
    // Fresh, empty on-device event store unless a test seeds it below.
    SharedPreferences.setMockInitialValues({});
  });

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
    await tester.pumpAndSettle();

    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('백색'), findsOneWidget);
    expect(find.text('의무 축일'), findsOneWidget);
    // 2026-12-25 falls in the 2026–27 liturgical year (Advent began Nov 29) = 나해(B).
    expect(find.textContaining('나해'), findsOneWidget);
  });

  testWidgets('the add-event FAB opens the editor sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone (narrow) layout
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('새 일정'), findsOneWidget);
    // Title is now chosen on the category screen, not typed here.
    expect(find.text('카테고리를 선택하세요'), findsOneWidget);
  });

  testWidgets('day detail lists stored personal events', (tester) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'time': '19:30',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('내 일정'), findsOneWidget);
    expect(find.text('성경 공부'), findsOneWidget);
  });

  testWidgets('adding an event by picking a category persists and shows it', (
    tester,
  ) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    // No events yet.
    expect(find.text('등록된 일정이 없습니다.'), findsOneWidget);

    // Open the editor from the "내 일정" section.
    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    // Open the category screen, tap a seeded category → auto-selected + back.
    await tester.tap(find.text('카테고리를 선택하세요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전례'));
    await tester.pumpAndSettle();

    // Save the event.
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    // Back on the detail view, the new event is listed under its category name.
    expect(find.text('전례'), findsOneWidget);
    expect(find.text('등록된 일정이 없습니다.'), findsNothing);
  });

  testWidgets('category screen lists seeded categories and adds a new one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    expect(find.text('본당 행사'), findsOneWidget);
    expect(find.text('교리'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, '카테고리 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '레지오');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('레지오'), findsOneWidget);
  });

  testWidgets('category screen edit mode deletes an unused category on save', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    // Enter edit mode via the settings button.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '저장'), findsOneWidget);

    // Delete '기도' (unused) from the draft, then save.
    final row = find.ancestor(
      of: find.text('기도'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('기도'), findsNothing);
    expect(find.text('본당 행사'), findsOneWidget); // 나머지는 유지
  });
}
