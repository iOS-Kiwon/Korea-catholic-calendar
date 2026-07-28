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
import 'package:catholic_calendar/features/calendar/presentation/widgets/month_grid.dart';
import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/application/recurrence_expander.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/recurrence.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:catholic_calendar/features/events/presentation/category_manager_page.dart'
    show CategoryPickerPage;
import 'package:catholic_calendar/features/events/presentation/event_editor_sheet.dart';
import 'package:catholic_calendar/features/saints/presentation/saint_feast_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  }) async {}
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
  Future<String?> loadSnapshotJson({
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async => null;
  @override
  Future<bool> saveSnapshotJson(
    String snapshotJson, {
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async => true;
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
    // Sundays are "notable" and show their (abbreviated) name in the wide grid.
    // 기본 필터(주일에 대축일만)에서 주일 표기는 "주일"을 뗀 축약형으로 표시된다.
    expect(find.text('연중 제15'), findsWidgets); // 2026-07-12
  });

  testWidgets('compact month grid hides liturgical color dots', (tester) async {
    final service = CalendarService(engine: LiturgicalCalendar());

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 390,
            height: 360,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 7),
              today: DateTime(2026, 7, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final liturgicalDots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (widget) =>
              widget.constraints?.minWidth == 6 &&
              widget.constraints?.maxWidth == 6 &&
              widget.constraints?.minHeight == 6 &&
              widget.constraints?.maxHeight == 6,
        );
    expect(liturgicalDots, isEmpty);
  });

  testWidgets('compact month grid shows transferred solemnity short label', (
    tester,
  ) async {
    final service = CalendarService(engine: LiturgicalCalendar());

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 390,
            height: 360,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 5),
              today: DateTime(2026, 5, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('주님 승천'), findsOneWidget);
    expect(service.day(DateTime(2026, 5, 17)).celebration.id, 'ascension');
    expect(
      service.day(DateTime(2026, 5, 14)).celebration.id,
      isNot('ascension'),
    );
  });

  testWidgets('day detail shows the 전례력 and 일정 sections', (tester) async {
    // 2026-12-25 — Christmas.
    final day = LiturgicalCalendar().day(DateTime(2026, 12, 25));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('전례력'), findsOneWidget);
    // The liturgical title appears in the 전례력 section.
    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('일정'), findsOneWidget);
  });

  testWidgets('liturgical feast detail shows saint feast add button', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
          ),
        );
    expect(day.celebration.rank, Rank.feast);

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '축일 추가'));
    await tester.pumpAndSettle();

    expect(find.text('새 축일'), findsOneWidget);
    expect(find.text('성인을 선택하세요'), findsOneWidget);
  });

  testWidgets('day detail shows saint information link when available', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(saintInfoUrl: 'https://example.com/saint/james');

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '성인 정보 보기'), findsOneWidget);
  });

  testWidgets('non-feast detail hides saint feast add button', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    expect(day.celebration.rank, isNot(Rank.feast));
    expect(day.celebration.rank, isNot(Rank.feastOfTheLord));
    expect(day.celebration.rank, isNot(Rank.solemnity));

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '축일 추가'), findsNothing);
  });

  testWidgets('the add-event speed dial opens the event editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844); // phone (narrow) layout
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    // Tap the speed-dial main button to expand the mini actions.
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();

    expect(find.text('일정 추가'), findsOneWidget);

    // Tap '일정 추가' to open the editor.
    await tester.tap(find.text('일정 추가'));
    await tester.pumpAndSettle();

    expect(find.text('새 일정'), findsOneWidget);
    // Title is now chosen on the category screen, not typed here.
    expect(find.text('카테고리를 선택하세요'), findsOneWidget);
  });

  testWidgets('event editor shows start/end times when all-day is off', (
    tester,
  ) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('시작'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
    final allDayButtonCount = find.byType(TextButton).evaluate().length;

    await tester.tap(find.widgetWithText(SwitchListTile, '종일'));
    await tester.pumpAndSettle();

    final timedButtonCount = find.byType(TextButton).evaluate().length;
    expect(timedButtonCount, allDayButtonCount + 2);
  });

  testWidgets('event memo wraps while return key stays done', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    final memo = _memoTextField(tester);
    expect(memo.minLines, 1);
    expect(memo.maxLines, isNull);
    expect(memo.keyboardType, TextInputType.text);
    expect(memo.textInputAction, TextInputAction.done);
    expect(memo.inputFormatters, contains(isA<FilteringTextInputFormatter>()));
  });

  testWidgets('open speed dial scrim blocks month navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone (narrow) layout
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsOneWidget);

    final fabBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('speed_dial_main')))
        .dy;
    final infoTop = tester.getTopLeft(find.byType(DayInfoBar)).dy;
    expect(fabBottom, lessThan(infoTop));

    await tester.tap(find.byTooltip('다음 달'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('2026년 7월'), findsOneWidget);
    expect(find.text('일정 추가'), findsNothing);
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

    expect(find.text('일정'), findsOneWidget);
    expect(find.text('성경 공부'), findsOneWidget);
    expect(find.text('19:30'), findsOneWidget);
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

    expect(find.text('성경 공부'), findsOneWidget);
    final summary = tester.widget<Text>(find.text('19:30 루카복음 긴 메모'));
    expect(summary.maxLines, 1);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(find.text('전례'), findsOneWidget);
    expect(find.text(day.title), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar labels liturgical feast as 축일', (tester) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
          ),
        );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('축일'), findsOneWidget);
    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.text('전례'), findsNothing);
  });

  testWidgets('bottom info bar labels fetched feast data as 축일', (
    tester,
  ) async {
    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {'date': '2026-07-25', 'color': 'red', 'title': '성 야고보 사도 축일'},
      ]),
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(
            day: service.day(DateTime(2026, 7, 25)),
            onTapDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('축일'), findsOneWidget);
    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.text('전례'), findsNothing);
  });

  testWidgets('bottom info bar labels saint alternatives as 축일', (
    tester,
  ) async {
    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-08-25',
          'color': 'green',
          'title': '연중 제21주간 화요일',
          'alternatives': [
            {'name': '성 루도비코', 'color': 'white'},
            {'name': '성 요셉 데 갈라산즈 사제', 'color': 'white'},
          ],
        },
      ]),
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(
            day: service.day(DateTime(2026, 8, 25)),
            onTapDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.text('축일'), findsNWidgets(2));
    expect(find.text('연중 제21주간 화요일'), findsOneWidget);
    expect(find.text('성 루도비코'), findsOneWidget);
    expect(find.text('성 요셉 데 갈라산즈 사제'), findsOneWidget);
  });

  testWidgets('bottom info bar labels solemnity as 전례', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 12, 25));
    expect(day.celebration.rank, Rank.solemnity);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar labels All Souls Day as 전례', (tester) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 11, 2))
        .copyWith(title: '죽은 모든 이를 기억하는 위령의 날');
    expect(day.celebration.id, 'all_souls');
    expect(day.celebration.rank, Rank.feast);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.text('죽은 모든 이를 기억하는 위령의 날'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar does not label non-saint rank feast as 축일', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 16))
        .copyWith(
          title: '전례 전용 기념 축일',
          celebration: const Celebration(
            id: 'liturgical_only_feast',
            name: '전례 전용 기념 축일',
            rank: Rank.feast,
            color: LiturgicalColor.white,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
          ),
        );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.text('전례 전용 기념 축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar uses displayType over rank/title heuristics', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
            displayType: LiturgicalDisplayType.liturgy,
          ),
        );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('day detail uses displayType for 축일 추가 visibility', (
    tester,
  ) async {
    final liturgyRankFeast = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
            displayType: LiturgicalDisplayType.liturgy,
          ),
        );

    await tester.pumpWidget(
      _wrap(Scaffold(body: DayDetailView(day: liturgyRankFeast))),
    );
    await tester.pumpAndSettle();

    expect(find.text('전례'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsNothing);

    final saintFeast = liturgyRankFeast.copyWith(
      celebration: liturgyRankFeast.celebration.copyWith(
        displayType: LiturgicalDisplayType.saintFeast,
      ),
    );
    await tester.pumpWidget(
      _wrap(Scaffold(body: DayDetailView(day: saintFeast))),
    );
    await tester.pumpAndSettle();

    expect(find.text('축일'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsOneWidget);
  });

  testWidgets('adding an event by picking a category persists and shows it', (
    tester,
  ) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    // No events yet.
    expect(find.text('등록된 일정이 없습니다.'), findsOneWidget);

    // Open the editor from the "일정" section.
    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    // Open the category screen, tap a seeded category → auto-selected + back.
    await tester.tap(find.text('카테고리를 선택하세요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전례'));
    await tester.pumpAndSettle();
    expect(find.text('전례'), findsOneWidget);

    // Save the event.
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    // Back on the detail view, the new event is listed under its category name.
    expect(find.textContaining('전례'), findsAtLeastNWidgets(1));
    expect(find.text('등록된 일정이 없습니다.'), findsNothing);
  });

  testWidgets('deleting an edited event asks for confirmation', (tester) async {
    final event = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'c1',
      categoryName: '성경 공부',
      categoryColor: 0xFF2E7D32,
      notify: true,
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showEventEditor(
              context,
              date: DateTime(2026, 7, 16),
              existing: event,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('정말로 삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '삭제'), findsOneWidget);
  });

  testWidgets('deleting an edited saint feast asks for confirmation', (
    tester,
  ) async {
    final feast = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'saint_feast',
      categoryName: '축일',
      categoryColor: kSaintFeastEventColor,
      notify: true,
      type: CalendarEventType.saintFeast,
      saintId: 1,
      saintName: '성 마르코',
      saintUrl: 'https://example.com',
      recurrence: RecurrenceType.yearlyDate,
    );

    await tester.pumpWidget(
      _wrap(SaintFeastEditorPage(date: DateTime(2026, 7, 16), existing: feast)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('정말로 삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '삭제'), findsOneWidget);
  });

  testWidgets('saint feast memo wraps while return key stays done', (
    tester,
  ) async {
    final feast = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'saint_feast',
      categoryName: '축일',
      categoryColor: kSaintFeastEventColor,
      notify: true,
      type: CalendarEventType.saintFeast,
      saintId: 1,
      saintName: '성 마르코',
      saintUrl: 'https://example.com',
      recurrence: RecurrenceType.yearlyDate,
    );

    await tester.pumpWidget(
      _wrap(SaintFeastEditorPage(date: DateTime(2026, 7, 16), existing: feast)),
    );
    await tester.pumpAndSettle();

    final memo = _memoTextField(tester);
    expect(memo.minLines, 1);
    expect(memo.maxLines, isNull);
    expect(memo.keyboardType, TextInputType.text);
    expect(memo.textInputAction, TextInputAction.done);
    expect(memo.inputFormatters, contains(isA<FilteringTextInputFormatter>()));
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

    await tester.enterText(
      find.byType(TextField).first,
      '12345678901234567890',
    );
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

  testWidgets('backup notice shows once, when the first add completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    Future<void> addEventViaEditor() async {
      await tester.tap(find.widgetWithText(TextButton, '추가')); // 상세의 일정 추가
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리를 선택하세요')); // 카테고리 화면 열기
      await tester.pumpAndSettle();
      await tester.tap(find.text('전례')); // 선택 → 편집 화면으로 복귀
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '추가')); // 저장
      await tester.pumpAndSettle();
    }

    // 첫 추가 완료 시점에 백업 안내 노출.
    await addEventViaEditor();
    expect(find.text('내 일정 백업'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 두 번째 추가부터는 다시 뜨지 않는다.
    await addEventViaEditor();
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

TextField _memoTextField(WidgetTester tester) {
  return tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '메모 (선택)',
    ),
  );
}
