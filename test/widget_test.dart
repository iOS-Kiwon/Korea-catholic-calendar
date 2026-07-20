import 'dart:convert';

import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/calendar/application/calendar_providers.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/calendar_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/day_detail_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_detail_view.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_info_bar.dart';
import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
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
  _FakeNotifications({this.enabled = true, this.onOpenSettings});

  final bool enabled;
  final VoidCallback? onOpenSettings;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<void> openNotificationSettings() async => onOpenSettings?.call();

  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events) async {}
}

/// A backup store that never touches platform channels; reports cloud backup
/// as available so the first-run notice renders a simple 확인 dialog.
class _FakeBackupStore extends PersonalCloudBackupStore {
  const _FakeBackupStore();
  @override
  Future<CloudBackupAvailability> checkAvailability() async =>
      CloudBackupAvailability.available;
  @override
  Future<bool> promptSetup() async => false;
  @override
  Future<String?> loadSnapshotJson() async => null;
  @override
  Future<bool> saveSnapshotJson(String snapshotJson) async => true;
}

Widget _wrap(
  Widget child, {
  NotificationService? notificationService,
}) => ProviderScope(
  // Inject the engine-only service (no CBCK snapshot) and disable the remote
  // gateway so tests never hit the network → falls back to the computed engine.
  // Notifications and cloud backup are stubbed to avoid platform channels.
  overrides: [
    liturgicalCalendarProvider.overrideWith(
      (ref) => CalendarService(engine: LiturgicalCalendar()),
    ),
    remoteCalendarSourceProvider.overrideWithValue(
      const RemoteCalendarSource(enabled: false),
    ),
    notificationServiceProvider.overrideWithValue(
      notificationService ?? _FakeNotifications(),
    ),
    categoryLogServiceProvider.overrideWithValue(
      const NoopCategoryLogService(),
    ),
    personalCloudBackupStoreProvider.overrideWithValue(
      const _FakeBackupStore(),
    ),
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

  testWidgets('the add-event FAB pushes the editor screen', (tester) async {
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

  testWidgets('disabled system notifications prompt only when turning on', (
    tester,
  ) async {
    var openedSettings = false;
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(body: DayDetailView(day: day)),
        notificationService: _FakeNotifications(
          enabled: false,
          onOpenSettings: () => openedSettings = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    const message = '시스템 알림이 꺼져있어 알림을 보낼수 없습니다. 알림을 설정하시겠습니까?';
    expect(find.text(message), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, '알림'));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.text('아니오'), findsOneWidget);
    expect(find.text('예'), findsOneWidget);

    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();

    expect(openedSettings, isTrue);
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

  testWidgets('bottom info bar summarizes event time category and memo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'memo': '루카복음 긴 메모',
            'time': '19:30',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final summary = tester.widget<Text>(
      find.text('19:30 · 성경 공부 · 루카복음 긴 메모'),
    );
    expect(summary.maxLines, 1);
    expect(summary.overflow, TextOverflow.ellipsis);
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
    expect(find.text('전례'), findsAtLeastNWidgets(1));
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

  testWidgets('category names are limited to 15 characters', (tester) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, '카테고리 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '12345678901234567890');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('123456789012345'), findsOneWidget);
    expect(find.text('1234567890123456'), findsNothing);
  });

  testWidgets('tapping the bottom info area pushes the day detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    // The bottom detail area is a tappable InkWell inside the info bar.
    final detailTap = find.descendant(
      of: find.byType(DayInfoBar),
      matching: find.byType(InkWell),
    );
    await tester.tap(detailTap.first);
    await tester.pumpAndSettle();

    // Opens as a pushed full-screen page (not a bottom sheet).
    expect(find.byType(DayDetailPage), findsOneWidget);
  });

  testWidgets('adding the first event shows the backup notice once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarPage)),
    );
    const first = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'c',
      categoryName: '전례',
      categoryColor: 0xFF2E7D32,
    );
    await container.read(eventStoreProvider.notifier).add(first);
    await tester.pumpAndSettle();

    expect(find.text('내 일정 백업'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // A second add must not re-show the (once-only) notice.
    await container.read(eventStoreProvider.notifier).add(
      const CalendarEvent(
        id: '2',
        date: '2026-07-17',
        categoryId: 'c',
        categoryName: '전례',
        categoryColor: 0xFF2E7D32,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('내 일정 백업'), findsNothing);
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
